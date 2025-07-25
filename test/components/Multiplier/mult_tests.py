import cocotb
from cocotb.triggers import Timer
import struct

def float_to_hex(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    return struct.unpack('>f', struct.pack('>I', h))[0]

@cocotb.test()
async def test_fpu_mul_simple(dut):
    tests = [
        (3.5, 1.25, 4.375),
        (2.0, 2.0, 4.0),
        (0.5, 0.5, 0.25),
        (10.0, 0.0, 0.0),
        (1.1, 2.2, 2.42)
    ]

    for a, b, expected in tests:
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(b)
        await Timer(10, units='ns')

        actual = hex_to_float(int(dut.result.value))
        diff = abs(actual - expected)

        assert diff < 1e-6, f"FAIL: {a} * {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} * {b} = {actual}")
