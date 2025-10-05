`include "MIPS32.v"

module test_mips32;

    reg clk;
    integer k;

    MIPS32_processor mips (clk);

    initial begin
        clk = 0;
        repeat (50) begin
            #5 clk = ~clk;
        end
    end

    initial begin
        for (k = 0; k < 32; k = k + 1) begin
            mips.REG[k] = k;
        end

        mips.MEM[0] = 32'h28010078;   // ADDI R1, R0, 120
        mips.MEM[1] = 32'h0c631800;   // OR R3, R3, R3 (dummy)
        mips.MEM[2] = 32'h20220000;   // LW R2, 0(R1)
        mips.MEM[3] = 32'h0c631800;   // OR R3, R3, R3 (dummy)
        mips.MEM[4] = 32'h0c631800;   // OR R3, R3, R3 (dummy)
        mips.MEM[5] = 32'h0c631800;   // OR R3, R3, R3 (dummy)
        mips.MEM[6] = 32'h2842002d;   // ADDI R2, R2, 45
        mips.MEM[7] = 32'h0c631800;   // OR R3, R3, R3 (dummy)
        mips.MEM[8] = 32'h24220001;   // SW R2, 1(R1)
        mips.MEM[9] = 32'hfc000000;   // HLT

        mips.MEM[120] = 85;

        mips.HALTED = 0;
        mips.PC = 0;
        mips.TAKEN_BRANCH = 0;

        #280;
        
        // Display register values
        $display("Register Contents:");
        for (k = 0; k < 6; k = k + 1) begin
            $display("R%1d - %2d", k, mips.REG[k]);
        end
        
        // Display memory locations
        $display("\nMemory Contents:");
        $display("MEM[120] = %0d", mips.MEM[120]);
        $display("MEM[121] = %0d", mips.MEM[121]);
    end

    initial begin
        $dumpfile("mips.vcd");
        $dumpvars(0, test_mips32);
        #300 $finish;
    end

endmodule




