import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start NTT Test")

    # Tạo xung clock chu kỳ 10us
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Khởi tạo tín hiệu đầu vào
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Giữ Reset trong 5 chu kỳ clock
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Reset complete, running NTT simulation...")

    # Chạy mô phỏng 100 chu kỳ clock
    await ClockCycles(dut.clk, 100)
