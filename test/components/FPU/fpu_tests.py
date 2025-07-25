
import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct
import math

def float_to_hex(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    return struct.unpack('>f', struct.pack('>I', h))[0]

async def write(dut, addr, data):
    dut.address.value = addr
    dut.data_in.value = data
    dut.data_write_n.value = 0b10
    await RisingEdge(dut.clk)
    dut.data_write_n.value = 0b11
    await RisingEdge(dut.clk)

async def read(dut, addr):
    dut.address.value = addr
    dut.data_read_n.value = 0b10
    await RisingEdge(dut.clk)
    dut.data_read_n.value = 0b11
    await RisingEdge(dut.clk)
    return int(dut.data_out.value)

@cocotb.test()
async def test_add_mul_sub_edge(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.data_write_n.value = 0b11
    dut.data_read_n.value = 0b11
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    tests = [
        (3.5, 1.25), (-2.0, 5.0), (0.0, 0.0),
        (float('inf'), 1.0), (float('-inf'), float('inf')),
        (float('nan'), 1.0), (1.0, float('nan')),
        (1.0, 0.0), (0.0, 1.0), (33.33, 1.0)
    ]

    for a, b in tests:
        a_hex = float_to_hex(a)
        b_hex = float_to_hex(b)

        async def perform_op(ctrl, op_str):
            await write(dut, 0x00, a_hex)
            await write(dut, 0x04, b_hex)
            await write(dut, 0x08, ctrl)

            while True:
                busy = await read(dut, 0x10)
                if busy == 0:
                    break
                await Timer(10, units="ns")

            result = await read(dut, 0x0C)
            actual = hex_to_float(result)
            expected = {
                0x01: a + b,
                0x02: a * b,
                0x03: a - b
            }[ctrl]

            if math.isnan(expected):
                assert math.isnan(actual), f"{op_str} FAIL: {a} ? {b} = {actual}, expected NaN"
            elif math.isinf(expected):
                assert math.isinf(actual) and (actual == expected), f"{op_str} FAIL: {a} ? {b} = {actual}, expected {expected}"
            else:
                assert abs(actual - expected) < 1e-5, f"{op_str} FAIL: {a} ? {b} = {actual}, expected {expected}"
            dut._log.info(f"PASS {op_str}: {a} ? {b} = {actual}")

        await perform_op(0x01, "ADD")
        await perform_op(0x02, "MUL")
        await perform_op(0x03, "SUB")
