import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import struct
import math

def float_to_hex(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    return struct.unpack('>f', struct.pack('>I', h))[0]

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def apply_and_wait(dut, a, b):
    # Apply inputs
    dut.a.value = float_to_hex(a)
    dut.b.value = float_to_hex(b)
    dut.valid_in.value = 1

    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    # Wait for valid_out signal
    for _ in range(10):  # max 10 cycles wait
        await RisingEdge(dut.clk)
        if dut.valid_out.value.integer == 1:
            break

    actual = hex_to_float(int(dut.result.value))
    return actual

@cocotb.test()
async def test_fpu_mul_normal(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    tests = [
        (3.5, 1.25, 4.375),
        (2.0, 2.0, 4.0),
        (0.5, 0.5, 0.25),
        (1.1, 2.2, 2.42),
        (1.0, 0.0001, 0.0001),
        (100.0, 0.01, 1.0),
        (33.33, 1.0, 33.330001)
    ]
    for a, b, expected in tests:
        actual = await apply_and_wait(dut, a, b)
        assert abs(actual - expected) < 1e-5, f"FAIL: {a} * {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} * {b} = {actual}")

@cocotb.test()
async def test_fpu_mul_with_signs(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    tests = [
        (-2.0, 2.0, -4.0),
        (-1.0, -1.0, 1.0),
        (1.5, -2.0, -3.0),
        (-3.0, -3.0, 9.0),
        (0.0, -10.0, 0.0),
        (-0.0, 0.0, 0.0),
    ]
    for a, b, expected in tests:
        actual = await apply_and_wait(dut, a, b)
        assert abs(actual - expected) < 1e-5, f"FAIL: {a} * {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} * {b} = {actual}")

@cocotb.test()
async def test_fpu_mul_edge_cases(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    nan = float('nan')
    inf = float('inf')
    tests = [
        (inf, 1.0, inf),
        (1.0, inf, inf),
        (-1.0, inf, -inf),
        (inf, -1.0, -inf),
        (inf, inf, inf),
        (-inf, -inf, inf),
        (-inf, inf, -inf),
        (nan, 1.0, nan),
        (1.0, nan, nan),
        (0.0, inf, nan),
        (inf, 0.0, nan),
        (0.0, 0.0, 0.0)
    ]
    for a, b, expected in tests:
        actual = await apply_and_wait(dut, a, b)
        if math.isnan(expected):
            assert math.isnan(actual), f"FAIL: {a} * {b} = {actual}, expected NaN"
        elif math.isinf(expected):
            assert math.isinf(actual) and (math.copysign(1, actual) == math.copysign(1, expected)), \
                f"FAIL: {a} * {b} = {actual}, expected {expected}"
        else:
            assert abs(actual - expected) < 1e-5, f"FAIL: {a} * {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} * {b} = {actual}")
