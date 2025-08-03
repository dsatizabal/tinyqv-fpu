import cocotb
from cocotb.triggers import Timer
import struct
import math
import numpy as np

# === Helpers ===

def float_to_half_bin(f):
    return struct.unpack('>H', struct.pack('>e', f))[0]

def half_bin_to_float(h):
    return struct.unpack('>e', struct.pack('>H', h & 0xFFFF))[0]

# === Driver ===

async def apply_and_wait(dut, a_float, b_float):
    a_bin = float_to_half_bin(a_float)
    b_bin = float_to_half_bin(b_float)

    dut.a.value = a_bin
    dut.b.value = b_bin
    dut.req_in.value = 1

    await Timer(10, units='ns')

    while dut.ack_out.value != 1:
        await Timer(10, units='ns')

    raw_result = int(dut.result.value)
    result_float = half_bin_to_float(raw_result)

    dut.req_in.value = 0
    await Timer(100, units='ns')

    return result_float

# === Tests ===

@cocotb.test()
async def test_async_fpu_add_normal(dut):
    dut.req_in.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(100, units='ns')

    tests = [
        (0.0, 0.0),
        (1.0, 1.0),
        (0.01, 0.01),
        (100.0, 0.01),
        (3.5, 1.25),
        (1.0, 2.0),
        (0.5, 0.25),
        (100.0, 200.0)
    ]
    for a, b in tests:
        actual = await apply_and_wait(dut, a, b)
        expected = float(np.float16(a) + np.float16(b))
        assert abs(actual - expected) < 1e-2, f"FAIL: {a} + {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} + {b} = {actual}")

@cocotb.test()
async def test_async_fpu_add_with_signs(dut):
    dut.req_in.value = 0
    await Timer(100, units='ns')

    tests = [
        (-1.0, -2.0),
        (5.0, -2.0),
        (-3.5, 1.25),
        (1.5, -1.5),
        (-1.5, 1.5),
        (100.00, 0.01),
        (100.0, -100.0),
        (-100.0, 100.0)
    ]
    for a, b in tests:
        actual = await apply_and_wait(dut, a, b)
        expected = float(np.float16(a) + np.float16(b))
        assert abs(actual - expected) < 1e-2, f"FAIL: {a} + {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} + {b} = {actual}")

@cocotb.test()
async def test_async_fpu_add_subtraction(dut):
    dut.req_in.value = 0
    await Timer(100, units='ns')

    tests = [
        (5.0, 2.0),
        (2.0, 5.0),
        (-1.0, -1.0),
        (-2.5, -1.0),
        (3.5, 3.5),
        (100, 0.01),
    ]
    for a, b in tests:
        actual = await apply_and_wait(dut, a, -b)
        expected = float(np.float16(a) - np.float16(b))
        assert abs(actual - expected) < 1e-2, f"FAIL: {a} - {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} - {b} = {actual}")

@cocotb.test()
async def test_async_fpu_add_edge_cases(dut):
    dut.req_in.value = 0
    await Timer(100, units='ns')

    nan = float('nan')
    inf = float('inf')
    tests = [
        (inf, inf, inf),
        (-inf, -inf, -inf),
        (inf, -inf, nan),
        (nan, 1.0, nan),
        (1.0, nan, nan),
        (0.0, -0.0, 0.0),
        (inf, 1.0, inf),
        (-1.0, inf, inf),
        (-inf, 1.0, -inf),
        (0.0, inf, inf),
        (0.0, nan, nan)
    ]
    for a, b, expected in tests:
        actual = await apply_and_wait(dut, a, b)

        if math.isnan(expected):
            assert math.isnan(actual), f"FAIL: {a} + {b} = {actual}, expected NaN"
        elif math.isinf(expected):
            assert math.isinf(actual) and (math.copysign(1, actual) == math.copysign(1, expected)), \
                f"FAIL: {a} + {b} = {actual}, expected {expected}"
        else:
            assert abs(actual - expected) < 1e-2, f"FAIL: {a} + {b} = {actual}, expected {expected}"

        dut._log.info(f"PASS: {a} + {b} = {actual}")
