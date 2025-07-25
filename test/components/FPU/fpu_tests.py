import cocotb
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.clock import Clock
import struct

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
async def test_add_and_mul(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.data_write_n.value = 0b11
    dut.data_read_n.value = 0b11
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define tests
    tests = [
        (3.5, 1.25, 4.75, 4.375),
        (1.0, 2.0, 3.0, 2.0),
        (0.5, 0.25, 0.75, 0.125),
        (10.0, 5.0, 15.0, 50.0),
        (1000.0, 0.01, 1000.009948, 10.0), # Sum gets affected by precision, check later
        (0.0, 0.0, 0.0, 0.0),
        (15.0, 0.0, 15.0, 0.0),
        (77.82, 1.0, 78.82, 77.82),
    ]

    for a, b, expected_sum, expected_mul in tests:
        a_hex = float_to_hex(a)
        b_hex = float_to_hex(b)

        # === ADD TEST ===
        await write(dut, 0x00, a_hex)
        await write(dut, 0x04, b_hex)
        await write(dut, 0x08, 0x01)  # control = ADD

        # Wait until busy = 0
        while True:
            busy = await read(dut, 0x10)
            if busy == 0:
                break
            await Timer(10, units="ns")

        result = await read(dut, 0x0C)
        actual = hex_to_float(result)
        diff = abs(actual - expected_sum)
        assert diff < 1e-6, f"ADD FAIL: {a} + {b} = {actual}, expected {expected_sum}"
        dut._log.info(f"PASS ADD: {a} + {b} = {actual}")

        # === MUL TEST ===
        await write(dut, 0x00, a_hex)
        await write(dut, 0x04, b_hex)
        await write(dut, 0x08, 0x02)  # control = MUL

        while True:
            busy = await read(dut, 0x10)
            if busy == 0:
                break
            await Timer(10, units="ns")

        result = await read(dut, 0x0C)
        actual = hex_to_float(result)
        diff = abs(actual - expected_mul)
        assert diff < 1e-6, f"MUL FAIL: {a} * {b} = {actual}, expected {expected_mul}"
        dut._log.info(f"PASS MUL: {a} * {b} = {actual}")
