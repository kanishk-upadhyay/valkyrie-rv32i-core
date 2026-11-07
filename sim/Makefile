# =============================================================================
# Makefile for Valkyrie-RV32I Processor Core
# Project: Valkyrie-RV32I Core
# Organization: DG Signals / Indian Army Internship Programme (AICTE)
# =============================================================================

IVAR     = iverilog
VVP      = vvp
PYTHON   = python3

ROOT_DIR = ..
RTL_DIR  = $(ROOT_DIR)/rtl
TB_DIR   = $(ROOT_DIR)/tb
SIM_DIR  = $(ROOT_DIR)/sim
TESTS_DIR= $(TB_DIR)/tests

RTL_SRCS = $(wildcard $(RTL_DIR)/units/*.v) \
           $(wildcard $(RTL_DIR)/core/*.v) \
           $(wildcard $(RTL_DIR)/bus/*.v)
TB_SRCS  = $(TB_DIR)/tb_core.v

TARGET   = sim_core
VCD_FILE = valkyrie_sim.vcd

.PHONY: all compile test test-all waves clean help

all: test-all

compile: $(TARGET)

$(TARGET): $(RTL_SRCS) $(TB_SRCS)
	@echo "==> Compiling Valkyrie-RV32I Core with $(IVAR)..."
	$(IVAR) -g2012 -o $(TARGET) $(RTL_SRCS) $(TB_SRCS)
	@echo "==> Compilation successful: $(TARGET)"

test-all: compile
	@echo "==> Executing Automated Regression Test Suite..."
	$(PYTHON) $(TB_DIR)/sim_runner.py

test: compile
	@echo "==> Running default test (Full Suite)..."
	$(VVP) $(TARGET) +HEX=$(TESTS_DIR)/test_full_suite.hex

test-%: compile
	@echo "==> Running specific test: $*..."
	$(VVP) $(TARGET) +HEX=$(TESTS_DIR)/$*.hex

waves: compile
	@echo "==> Generating VCD waveform dump..."
	$(VVP) $(TARGET) +HEX=$(TESTS_DIR)/test_full_suite.hex +VCD=$(VCD_FILE)
	@bash view_waves.sh $(VCD_FILE)

clean:
	@echo "==> Cleaning simulation artifacts..."
	rm -f $(TARGET) *.vcd *.vvp
	@echo "==> Clean complete."

help:
	@echo "Valkyrie-RV32I Makefile targets:"
	@echo "  make compile    - Compile RTL and testbench into $(TARGET)"
	@echo "  make test-all   - Run complete automated regression test suite"
	@echo "  make test       - Run default integration test"
	@echo "  make test-<name>- Run specific test (e.g., make test-test_arithmetic)"
	@echo "  make waves      - Generate and launch waveform viewer (GTKWave)"
	@echo "  make clean      - Remove build binaries and VCD waveforms"
