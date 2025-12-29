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
        // `repeat(40)` will generate 20 full clock cycles.
        repeat (40) begin
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
        
        // OR x6, x4, x5       → x6 = x4 | x5 = 55
        riscv.MEM[5] = 32'h00526333;  // OR x6, x4, x5
        
        // ADDI x7, x0, 0      → x7 = 0
        riscv.MEM[6] = 32'h00000393;  // ADDI x7, x0, 0
        
        // AND x7, x4, x5      → x7 = x4 & x5 = 22
        riscv.MEM[7] = 32'h005273b3;  // AND x7, x4, x5

        // Initialize processor state flags
        riscv.HALTED = 0;
        riscv.PC = 0;
        riscv.TAKEN_BRANCH = 0;

        // Wait for the program to execute
        #280;

        // Display the values of the first 8 registers (x0-x7)
        for (k=0; k<8; k=k+1) begin
            $display ("x%1d (R%1d) - %2d", k, k, riscv.REG[k]);
        end
        
        // Display expected vs actual results
        $display ("\n=== Test Results ===");
        $display ("x1 should be 10, got: %d", riscv.REG[1]);
        $display ("x2 should be 20, got: %d", riscv.REG[2]);
        $display ("x3 should be 25, got: %d", riscv.REG[3]);
        $display ("x4 should be 30, got: %d", riscv.REG[4]);
        $display ("x5 should be 55, got: %d", riscv.REG[5]);
        $display ("x6 should be 55, got: %d", riscv.REG[6]);
        $display ("x7 should be 22, got: %d", riscv.REG[7]);
    end

    // Simulation control and waveform dumping
    initial begin
        // Set up waveform dumping to a VCD file
        $dumpfile("riscv.vcd");
        $dumpvars(0, test1_riscv32);

        // End the simulation after a delay
        #300 $finish;
    end

endmodule


