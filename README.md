# RISC-V 32-bit Pipelined Processor

## RISC-V Core Overview

RISC-V is an open-source, royalty-free instruction set architecture (ISA) based on established reduced instruction set computing (RISC) principles. Developed at UC Berkeley, RISC-V provides a completely unencumbered foundation for processor design without licensing fees or patent restrictions. The RV32I (32-bit Integer) base instruction set provides a minimal but complete set of instructions for a functional processor.

### Design Philosophy

RISC-V emphasizes:
- **Simplicity**: A clean, unencumbered ISA with minimal instruction count
- **Modularity**: Base integer (I) instruction set with optional extensions (M, F, D, C, etc.)
- **Openness**: Completely open standard with no licensing fees or patent restrictions
- **Extensibility**: Allows custom extensions while maintaining compatibility

### Key Characteristics

- **32-bit Integer Architecture**: RV32I operates on 32-bit words with a 32-register file (x0-x31)
- **Load-Store Architecture**: All data manipulation happens in registers; memory is accessed only through LW/SW instructions
- **Uniform Instruction Format**: All instructions are 32 bits with consistent field layouts (R, I, S, B, U, J types)
- **Simple ALU Operations**: Supports basic arithmetic, logical, and comparison operations
- **Efficient Encoding**: Compact instruction format maximizes code density

### RISC-V vs Traditional RISC

Unlike older RISC architectures:
- RISC-V uses a completely royalty-free model
- Instructions are fewer but more orthogonal (flexible combinations)
- Better suited for embedded systems and custom silicon
- Strong community support and extensive toolchain availability

## Processor Architecture

This project implements a **5-stage pipelined processor** with the following design:

### Pipeline Stages:
1. **IF (Instruction Fetch)** - Fetches instructions from memory
2. **ID (Instruction Decode)** - Decodes instruction and reads registers with early branch resolution
3. **EX (Execution)** - Executes ALU operations with combinational result computation
4. **MEM (Memory)** - Performs load/store operations
5. **WB (Write Back)** - Writes results back to register file

### Key Features:
- **Data Forwarding**: Handles data dependencies through combinational ALU bypass and multi-level forwarding paths
- **Branch Handling**: Early branch resolution in ID stage reduces branch penalty from 3 cycles to 1 cycle
- **Hazard Detection**: Stall mechanism for load-use hazards
- **32-bit Architecture**: Full 32-bit data paths and register file

## Implemented Instructions

### R-Type Instructions (Register-Register Operations)
- **ADD** - Addition
- **SUB** - Subtraction
- **AND** - Bitwise AND
- **OR** - Bitwise OR
- **SLT** - Set Less Than

### I-Type Instructions (Immediate Operations)
- **ADDI** - Add Immediate
- **ANDI** - AND Immediate
- **ORI** - OR Immediate
- **SLTI** - Set Less Than Immediate
- **LW** - Load Word

### S-Type Instructions (Store)
- **SW** - Store Word

### B-Type Instructions (Branch)
- **BEQ** - Branch Equal
- **BNE** - Branch Not Equal

## Future Improvements

1. **Extended Instruction Support**: Additional instruction types (shifts, multiplies, more branch conditions)
2. **Structural Approach**: Separation of instruction and data memory with proper cache hierarchy
3. **Rigor Testing**: Comprehensive test suites beyond pre-written test cases, including edge cases and stress testing
4. **Performance Optimization**: Reduced clock cycles per instruction and improved branch prediction
5. **Exception Handling**: Proper interrupt and exception support

## Testing

Current testing validates correct execution of R-type, I-type, and some S/B-type instructions with data forwarding and branch resolution. Test programs verify register file updates and correct ALU computations.

## Files

- `RISCV32.v` - Core processor implementation
- `test_program1.v` - Test suite for RV32I instructions
- `riscv.vcd` - Waveform dump for debugging

---

**Status**: Functional 5-stage pipeline with RV32I instruction support and proper data hazard handling.
