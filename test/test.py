import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import struct
import math
from tqv import TinyQV

PERIPHERAL_NUM = 0

def float_to_hex(f):
    return struct.unpack(">I", struct.pack(">f", f))[0]

def hex_to_float(h):
    return struct.unpack(">f", struct.pack(">I", h))[0]

async def wait_until_not_busy(tqv, timeout=100):
    for _ in range(timeout):
        busy = await tqv.read_byte_reg(0x10)
        if busy == 0:
            return
        await ClockCycles(tqv.dut.clk, 1)
    raise TimeoutError("FPU remained busy after timeout")

@cocotb.test()
async def test_fpu_add(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    tests = [
        (1.5, 2.25, 3.75),
        (100.0, 0.01, 100.01),
        (-1.0, 1.0, 0.0),
        (-3.5, -2.5, -6.0)
    ]

    for a, b, expected in tests:
        await tqv.write_word_reg(0x00, float_to_hex(a))  # operand_a
        await tqv.write_word_reg(0x04, float_to_hex(b))  # operand_b
        await tqv.write_word_reg(0x08, 0x01)             # control = 0x01 (ADD)

        await wait_until_not_busy(tqv)

        result = await tqv.read_word_reg(0x0C)
        actual = hex_to_float(result)

        dut._log.info(f"ADD: {a} + {b} = {actual}, expected {expected}")
        assert abs(actual - expected) < 1e-5, f"ADD FAIL: {a} + {b} = {actual}, expected {expected}"

@cocotb.test()
async def test_fpu_sub(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    tests = [
        (5.0, 2.0, 3.0),
        (1.0, 2.0, -1.0),
        (-2.0, -2.0, 0.0),
    ]

    for a, b, expected in tests:
        await tqv.write_word_reg(0x00, float_to_hex(a))
        await tqv.write_word_reg(0x04, float_to_hex(b))
        await tqv.write_word_reg(0x08, 0x03)  # control = 0x03 (SUB)

        await wait_until_not_busy(tqv)

        result = await tqv.read_word_reg(0x0C)
        actual = hex_to_float(result)

        dut._log.info(f"SUB: {a} - {b} = {actual}, expected {expected}")
        assert abs(actual - expected) < 1e-5, f"SUB FAIL: {a} - {b} = {actual}, expected {expected}"

@cocotb.test()
async def test_fpu_mul(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    tests = [
        (2.0, 3.0, 6.0),
        (-1.5, 2.0, -3.0),
        (0.0, 100.0, 0.0),
        (5.5, 0.5, 2.75)
    ]

    for a, b, expected in tests:
        await tqv.write_word_reg(0x00, float_to_hex(a))
        await tqv.write_word_reg(0x04, float_to_hex(b))
        await tqv.write_word_reg(0x08, 0x02)  # control = 0x02 (MUL)

        await wait_until_not_busy(tqv)

        result = await tqv.read_word_reg(0x0C)
        actual = hex_to_float(result)

        dut._log.info(f"MUL: {a} * {b} = {actual}, expected {expected}")
        assert abs(actual - expected) < 1e-5, f"MUL FAIL: {a} * {b} = {actual}, expected {expected}"

@cocotb.test()
async def test_fpu_edge_cases(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    edge_tests = [
        (float('inf'), 1.0, float('inf'), 0x01, "INF + 1.0"),
        (float('-inf'), 1.0, float('-inf'), 0x01, "-INF + 1.0"),
        (float('inf'), float('-inf'), float('nan'), 0x01, "INF + -INF = NaN"),
        (float('nan'), 1.0, float('nan'), 0x01, "NaN + 1.0"),
        (0.0, -0.0, 0.0, 0x01, "+0.0 + -0.0"),
        (1e38, 1e38, 1.9999999e+38, 0x01, "1e38 + 1e38 = 2e38-ish (no overflow)"),
        (1e-45, 1e-45, 2e-45, 0x01, "subnormal add"),
        (1e-45, -1e-45, 0.0, 0x01, "canceling subnormals"),
    ]

    for a, b, expected, control, desc in edge_tests:
        await tqv.write_word_reg(0x00, float_to_hex(a))
        await tqv.write_word_reg(0x04, float_to_hex(b))
        await tqv.write_word_reg(0x08, control)

        await wait_until_not_busy(tqv)

        result = await tqv.read_word_reg(0x0C)
        actual = hex_to_float(result)

        # NaN handling (cannot compare equality directly)
        if math.isnan(expected):
            assert math.isnan(actual), f"EDGE FAIL: {desc} produced {actual}, expected NaN"
        elif math.isinf(expected):
            assert math.isinf(actual) and math.copysign(1.0, actual) == math.copysign(1.0, expected), \
                f"EDGE FAIL: {desc} produced {actual}, expected {expected}"
        elif abs(expected) > 1e37:
            rel_err = abs((actual - expected) / expected)
            assert rel_err < 1e-6, f"EDGE FAIL: {desc} produced {actual}, expected {expected}"
        else:
            assert abs(actual - expected) < 1e-6, f"EDGE FAIL: {desc} produced {actual}, expected {expected}"

        dut._log.info(f"EDGE: {desc} -> got {actual}, expected {expected}")
