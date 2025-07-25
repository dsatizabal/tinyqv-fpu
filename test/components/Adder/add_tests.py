import cocotb
from cocotb.triggers import Timer
import struct

def float_to_hex(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    return struct.unpack('>f', struct.pack('>I', h))[0]

@cocotb.test()
async def test_fpu_add_simple(dut):
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
        diff = abs(actual - expected)

        assert diff < 1e-6, f"FAIL: {a} + {b} = {actual}, expected {expected}"
        dut._log.info(f"PASS: {a} + {b} = {actual}")
