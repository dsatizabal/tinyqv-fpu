import cocotb
from cocotb.triggers import Timer
import struct
import math

def float_to_hex(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    return struct.unpack('>f', struct.pack('>I', h))[0]

@cocotb.test()
async def test_fpu_add_normal(dut):
    tests = [
        (3.5, 1.25, 4.75),
        (1.0, 2.0, 3.0),
        (0.5, 0.25, 0.75),
        (100.0, 200.0, 300.0),
        (0.0, 0.0, 0.0)
    ]
    for a, b, expected in tests:
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(b)
        await Timer(10, units='ns')
        actual = hex_to_float(int(dut.result.value))
        assert abs(actual - expected) < 1e-5, f"FAIL: {a} + {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} + {b} = {actual}")

@cocotb.test()
async def test_fpu_add_with_signs(dut):
    tests = [
        (-1.0, -2.0, -3.0),
        (5.0, -2.0, 3.0),
        (-3.5, 1.25, -2.25),
        (1.5, -1.5, 0.0),
        (-1.5, 1.5, 0.0)
    ]
    for a, b, expected in tests:
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(b)
        await Timer(10, units='ns')
        actual = hex_to_float(int(dut.result.value))
        assert abs(actual - expected) < 1e-5, f"FAIL: {a} + {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} + {b} = {actual}")

@cocotb.test()
async def test_fpu_subtraction(dut):
    tests = [
        (5.0, 2.0, 3.0),
        (2.0, 5.0, -3.0),
        (-1.0, -1.0, 0.0),
        (-2.5, -1.0, -1.5),
        (3.5, 3.5, 0.0)
    ]
    for a, b, expected in tests:
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(-b)  # emulate subtraction as a + (-b)
        await Timer(10, units='ns')
        actual = hex_to_float(int(dut.result.value))
        assert abs(actual - expected) < 1e-5, f"FAIL: {a} - {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} - {b} = {actual}")

@cocotb.test()
async def test_fpu_edge_cases(dut):
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
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(b)
        await Timer(10, units='ns')
        actual = hex_to_float(int(dut.result.value))

        if math.isnan(expected):
            assert math.isnan(actual), f"FAIL: {a} + {b} = {actual}, expected NaN"
        elif math.isinf(expected):
            assert math.isinf(actual) and (math.copysign(1, actual) == math.copysign(1, expected)), \
                f"FAIL: {a} + {b} = {actual}, expected {expected}"
        else:
            assert abs(actual - expected) < 1e-5, f"FAIL: {a} + {b} = {actual}, expected {expected}"

        dut._log.info(f"PASS: {a} + {b} = {actual}")
