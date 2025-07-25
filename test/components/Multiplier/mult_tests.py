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
        (1.1, 2.2, 2.42),
        (0.0, 0.0, 0.0),
        (0.0, 104.0991, 0.0),
        (0.0002, 0.0, 0.0),
        (1.0, 0.0001, 0.0001),
        (100.0, 0.01, 1.0),
        (12345678.9, 0.00000001, 0.123456789),
        (3.4028235e+38, 1.0, 3.4028234663852886e+38),  # max float
        (1.17549435e-38, 1.0, 1.17549435e-38),  # min positive float
        (33.33, 1.0, 33.330001),
    ]

    for a, b, expected in tests:
        dut.a.value = float_to_hex(a)
        dut.b.value = float_to_hex(b)
        await Timer(10, units='ns')

        actual = hex_to_float(int(dut.result.value))
        diff = abs(actual - expected)

        assert diff < 1e-6, f"FAIL: {a} * {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} * {b} = {actual}")
