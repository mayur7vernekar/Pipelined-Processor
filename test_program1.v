`include "RISCV32.v"

module test1_riscv32;

    // Signal declarations
    reg clk;
    reg rst_n;
    integer k;

    // Instantiate the RISC-V RV32I processor module
    RISCV32 riscv (clk, rst_n);

    // Clock generation block
    initial begin
        clk = 0;
        // Generate a single-phase clock. Each #5 delay is half a clock period.
        // `repeat(200)` will generate 100 full clock cycles.
        repeat (200) begin
            #5 clk = ~clk;
        end
    end

    // Test stimulus and processor initialization block
    initial begin
        // Initialize reset signal
        rst_n = 0;
        #10 rst_n = 1;
        
        // Initialize general-purpose registers
        for (k=0; k<32; k=k+1) begin
            riscv.REG[k] = k;
        end

        // Load the machine code into memory (RV32I format)
        // ADDI x1, x0, 10     → x1 = 10
        riscv.MEM[0] = 32'h00a00093;  // ADDI x1, x0, 10
        
        // ADDI x2, x0, 20     → x2 = 20
        riscv.MEM[1] = 32'h01400113;  // ADDI x2, x0, 20
        
        // ADDI x3, x0, 25     → x3 = 25
        riscv.MEM[2] = 32'h01900193;  // ADDI x3, x0, 25
        
        // ADD x4, x1, x2      → x4 = x1 + x2 = 30
        riscv.MEM[3] = 32'h00208233;  // ADD x4, x1, x2
        
        // ADD x5, x4, x3      → x5 = x4 + x3 = 55
        riscv.MEM[4] = 32'h003202b3;  // ADD x5, x4, x3
        
        // OR x6, x4, x5       → x6 = x4 | x5 = 63
        riscv.MEM[5] = 32'h00526333;  // OR x6, x4, x5
        
        // ADDI x7, x0, 0      → x7 = 0
        riscv.MEM[6] = 32'h00000393;  // ADDI x7, x0, 0
        
        // AND x7, x4, x5      → x7 = x4 & x5 = 22
        riscv.MEM[7] = 32'h005273b3;  // AND x7, x4, x5
        
        // Simple BEQ test: branch taken (x1 == x1 is true)
        // ADDI x8, x0, 100
        riscv.MEM[8] = 32'h06400413;  // ADDI x8, x0, 100
        
        // BEQ x1, x1, 4 (offset=4, skip 1 instruction)
        riscv.MEM[9] = 32'h00020263;  // BEQ x1, x1, 4
        
        // ADDI x9, x0, 99 (SHOULD BE SKIPPED)
        riscv.MEM[10] = 32'h06300493;  // ADDI x9, x0, 99
        
        // ADDI x9, x0, 50 (BRANCH TARGET)
        riscv.MEM[11] = 32'h03200493;  // ADDI x9, x0, 50
        
        // BEQ test: branch NOT taken (x1 != x2)
        // BEQ x1, x2, 4 (offset=4, condition is false - NO BRANCH)
        riscv.MEM[12] = 32'h00208263;  // BEQ x1, x2, 4
        
        // ADDI x10, x0, 123 (SHOULD EXECUTE - branch not taken)
        riscv.MEM[13] = 32'h07b00513;  // ADDI x10, x0, 123
        
        // ADDI x11, x0, 55 (sequential)
        riscv.MEM[14] = 32'h03700593;  // ADDI x11, x0, 55
        
        // ADDI x12, x0, 99 (for next test section)
        riscv.MEM[15] = 32'h06300613;  // ADDI x12, x0, 99

        // Initialize processor state flags
        riscv.HALTED = 0;
        riscv.PC = 0;
        riscv.TAKEN_BRANCH = 0;

        // Wait for the program to execute
        #1000;

        // Display the values of the first 14 registers (x0-x13)
        for (k=0; k<14; k=k+1) begin
            $display ("x%1d (R%1d) - %2d", k, k, riscv.REG[k]);
        end
        
        // Display expected vs actual results
        $display ("\n=== Arithmetic & Logic Test Results ===");
        $display ("x1 should be 10, got: %d", riscv.REG[1]);
        $display ("x2 should be 20, got: %d", riscv.REG[2]);
        $display ("x3 should be 25, got: %d", riscv.REG[3]);
        $display ("x4 should be 30, got: %d", riscv.REG[4]);
        $display ("x5 should be 55, got: %d", riscv.REG[5]);
        $display ("x6 should be 63, got: %d", riscv.REG[6]);  // 30 | 55 = 63
        $display ("x7 should be 22, got: %d", riscv.REG[7]);  // 30 & 55 = 22
        
        $display ("\n=== Branch Instruction Test Results ===");
        $display ("x8 should be 100, got: %d (ADDI x8=100 before BEQ)", riscv.REG[8]);
        $display ("x9 should be 50, got: %d (BEQ x1==x1 taken, branch target executed)", riscv.REG[9]);
        $display ("x10 should be 123, got: %d (BEQ x1!=x2 NOT taken, instruction executed)", riscv.REG[10]);
        $display ("x11 should be 55, got: %d (Sequential ADDI after false branch)", riscv.REG[11]);
        $display ("x12 should be 99, got: %d (Next sequential instruction)", riscv.REG[12]);
    end

    // Simulation control and waveform dumping
    initial begin
        // Set up waveform dumping to a VCD file
        $dumpfile("riscv.vcd");
        $dumpvars(0, test1_riscv32);

        // End the simulation after a delay
        #1050 $finish;
    end

endmodule


