`include "RISCV32.v"

module test_riscv32;

    reg clk, rst_n;
    integer k;

    RISCV32 riscv (clk, rst_n);

    initial begin
        clk = 0;
        repeat (50) begin
            #5 clk = ~clk;
        end
    end

    initial begin
        // Initialize reset
        rst_n = 0;
        #10 rst_n = 1;
        
        // Initialize registers
        for (k = 0; k < 32; k = k + 1) begin
            riscv.REG[k] = k;
        end

        // Load RV32I machine code into memory
        // ADDI x1, x0, 120    → x1 = 120 (memory address)
        riscv.MEM[0] = 32'h07800093;   // ADDI x1, x0, 120
        
        // LW x2, 0(x1)        → x2 = MEM[120] = 85
        riscv.MEM[1] = 32'h00012103;   // LW x2, 0(x1)
        
        // ADDI x2, x2, 45     → x2 = 85 + 45 = 130
        riscv.MEM[2] = 32'h02d10113;   // ADDI x2, x2, 45
        
        // SW x2, 0(x1)        → MEM[120] = 130
        riscv.MEM[3] = 32'h00212023;   // SW x2, 0(x1)
        
        // ADDI x3, x0, 200    → x3 = 200 (alternate address)
        riscv.MEM[4] = 32'h0c800193;   // ADDI x3, x0, 200
        
        // LW x4, 0(x3)        → x4 = MEM[200] = 42
        riscv.MEM[5] = 32'h00034203;   // LW x4, 0(x3)
        
        // ADD x5, x2, x4      → x5 = x2 + x4 = 130 + 42 = 172
        riscv.MEM[6] = 32'h004102B3;   // ADD x5, x2, x4
        
        // SW x5, 4(x1)        → MEM[124] = 172
        riscv.MEM[7] = 32'h00512223;   // SW x5, 4(x1)

        // Initialize memory data
        riscv.MEM[120] = 85;
        riscv.MEM[121] = 0;
        riscv.MEM[124] = 0;
        riscv.MEM[200] = 42;

        // Initialize processor state flags
        riscv.HALTED = 0;
        riscv.PC = 0;
        riscv.TAKEN_BRANCH = 0;

        #280;
        
        // Display register values
        $display("=== RISC-V RV32I Test Program 2 - Load/Store & Arithmetic ===");
        $display("\nRegister Contents:");
        $display("x0 (R0)  = %0d", riscv.REG[0]);
        $display("x1 (R1)  = %0d (address 120)", riscv.REG[1]);
        $display("x2 (R2)  = %0d (should be 130)", riscv.REG[2]);
        $display("x3 (R3)  = %0d (address 200)", riscv.REG[3]);
        $display("x4 (R4)  = %0d (should be 42)", riscv.REG[4]);
        $display("x5 (R5)  = %0d (should be 172)", riscv.REG[5]);
        
        // Display memory locations
        $display("\nMemory Contents:");
        $display("MEM[120] = %0d (should be 130 after SW)", riscv.MEM[120]);
        $display("MEM[121] = %0d (original value)", riscv.MEM[121]);
        $display("MEM[124] = %0d (should be 172 after SW)", riscv.MEM[124]);
        $display("MEM[200] = %0d (initial value)", riscv.MEM[200]);
        
        // Test results
        $display("\n=== Test Results ===");
        if (riscv.REG[2] == 130) $display("✓ x2 = 130 (PASS)");
        else $display("✗ x2 = %d (FAIL - expected 130)", riscv.REG[2]);
        
        if (riscv.REG[4] == 42) $display("✓ x4 = 42 (PASS)");
        else $display("✗ x4 = %d (FAIL - expected 42)", riscv.REG[4]);
        
        if (riscv.REG[5] == 172) $display("✓ x5 = 172 (PASS)");
        else $display("✗ x5 = %d (FAIL - expected 172)", riscv.REG[5]);
        
        if (riscv.MEM[120] == 130) $display("✓ MEM[120] = 130 (PASS)");
        else $display("✗ MEM[120] = %d (FAIL - expected 130)", riscv.MEM[120]);
        
        if (riscv.MEM[124] == 172) $display("✓ MEM[124] = 172 (PASS)");
        else $display("✗ MEM[124] = %d (FAIL - expected 172)", riscv.MEM[124]);
    end

    initial begin
        $dumpfile("riscv.vcd");
        $dumpvars(0, test_riscv32);
        #300 $finish;
    end

endmodule




