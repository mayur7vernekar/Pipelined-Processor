`include "MIPS32.v"


module test1_mips32;

    // Signal declarations
    reg clk;
    integer k;

    // Instantiate the MIPS processor module
    MIPS32_processor mips (clk);

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
        // Initialize general-purpose registers
        for (k=0; k<32; k=k+1) begin
            mips.REG[k] = k;
        end

        // Load the machine code into memory
        mips.MEM[0] = 32'h2801000a;  // ADDI R1, R0, 10
        mips.MEM[1] = 32'h28020014;  // ADDI R2, R0, 20
        mips.MEM[2] = 32'h28030019;  // ADDI R3, R0, 25
        mips.MEM[3] = 32'h0ce77800;  // OR R7, R7, R7 (dummy instr.)
        mips.MEM[4] = 32'h0ce77800;  // OR R7, R7, R7 (dummy instr.)
        mips.MEM[5] = 32'h00222000;  // ADD R4, R1, R2
        mips.MEM[6] = 32'h0ce77800;  // OR R7, R7, R7 (dummy instr.)
        mips.MEM[7] = 32'h00832800;  // ADD R5, R4, R3
        mips.MEM[8] = 32'hfc000000;  // HLT

        // Initialize processor state flags (assuming these exist in your module)
        mips.HALTED = 0;
        mips.PC = 0;
        mips.TAKEN_BRANCH = 0;

        // Wait for the program to execute
        #280;

        // Display the values of the first 6 registers
        for (k=0; k<6; k=k+1) begin
            $display ("R%1d - %2d", k, mips.REG[k]);
        end
    end

    // Simulation control and waveform dumping
    initial begin
        // Set up waveform dumping to a VCD file
        $dumpfile("mips.vcd");
        $dumpvars(0, test1_mips32);

        // End the simulation after a delay
        #300 $finish;
    end

endmodule


