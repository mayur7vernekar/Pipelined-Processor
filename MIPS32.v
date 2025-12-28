module MIPS32_processor(
    input clk,
    input rst_n  // Added active-low reset input
);

    reg [31:0] REG [0:31];
    reg [31:0] MEM [0:1023];
    reg [31:0] PC;

    // Pipeline Registers
    reg [31:0] IF_ID_IR, IF_ID_PC;
    reg [31:0] ID_EX_A, ID_EX_B, ID_EX_IMM, ID_EX_PC;
    reg [31:0] EX_MEM_ALUOut, EX_MEM_B;
    reg [31:0] MEM_WB_LMD, MEM_WB_ALUOut;
    
    // Control Signals
    reg [5:0]  ID_EX_opcode, EX_MEM_opcode, MEM_WB_opcode;
    reg [4:0]  ID_EX_RD, EX_MEM_RD, MEM_WB_RD;
    reg        ID_EX_RegDst, ID_EX_ALUSrc, ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite;
    reg        EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
    reg        MEM_WB_RegWrite, MEM_WB_MemRead, MEM_WB_MemWrite;

    // Parameters
    parameter ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011;
    parameter SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111;
    parameter LW = 6'b001000, SW = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100;
    parameter BEQ = 6'b001101, BNE = 6'b001110;

    reg HALTED;
    reg TAKEN_BRANCH;
    integer i; // Loop variable for resetting registers

    // ==========================================
    // IF Stage: Instruction Fetch
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC <= 32'b0;
            IF_ID_IR <= 32'b0;
            IF_ID_PC <= 32'b0;
            HALTED <= 0;
        end else if (!HALTED) begin
            IF_ID_IR <= MEM[PC];
            PC <= PC + 1;
            IF_ID_PC <= PC;
        end
    end

    // ==========================================
    // ID Stage: Instruction Decode
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_PC <= 0;
            ID_EX_opcode <= 0;
            ID_EX_A <= 0;
            ID_EX_B <= 0;
            ID_EX_IMM <= 0;
            ID_EX_RD <= 0;
        end else if (!HALTED) begin
            ID_EX_PC <= IF_ID_PC;
            ID_EX_opcode <= IF_ID_IR[31:26];
            
            // Forwarding Logic A
            if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[25:21]))
                ID_EX_A <= EX_MEM_ALUOut;
            else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[25:21]))
                ID_EX_A <= MEM_WB_ALUOut;
            else
                ID_EX_A <= REG[IF_ID_IR[25:21]];
            
            // Forwarding Logic B
            if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[20:16]))
                ID_EX_B <= EX_MEM_ALUOut;
            else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[20:16]))
                ID_EX_B <= MEM_WB_ALUOut;
            else
                ID_EX_B <= REG[IF_ID_IR[20:16]];
            
            ID_EX_IMM <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
            
            case (IF_ID_IR[31:26])
                ADDI, SUBI, SLTI, LW: ID_EX_RD <= IF_ID_IR[20:16];
                default: ID_EX_RD <= IF_ID_IR[15:11];
            endcase
        end
    end

    // ==========================================
    // EX Stage: Execution
    // ==========================================
    always @(posedge clk or negedge rst_n) begin   
        if (!rst_n) begin
            EX_MEM_RD <= 0;
            EX_MEM_B <= 0;
            EX_MEM_opcode <= 0;
            EX_MEM_RegWrite <= 0;
            EX_MEM_MemRead <= 0;
            EX_MEM_MemWrite <= 0;
            EX_MEM_ALUOut <= 0;
        end else if (!HALTED) begin
            EX_MEM_RD <= ID_EX_RD;
            EX_MEM_B <= ID_EX_B;
            EX_MEM_opcode <= ID_EX_opcode;
            
            EX_MEM_RegWrite <= 0;
            EX_MEM_MemRead <= 0;
            EX_MEM_MemWrite <= 0;

            case (ID_EX_opcode)
                ADD: begin EX_MEM_ALUOut <= ID_EX_A + ID_EX_B; EX_MEM_RegWrite <= 1; end
                SUB: begin EX_MEM_ALUOut <= ID_EX_A - ID_EX_B; EX_MEM_RegWrite <= 1; end
                AND: begin EX_MEM_ALUOut <= ID_EX_A & ID_EX_B; EX_MEM_RegWrite <= 1; end
                OR:  begin EX_MEM_ALUOut <= ID_EX_A | ID_EX_B; EX_MEM_RegWrite <= 1; end
                SLT: begin EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_B)) ? 32'd1 : 32'd0; EX_MEM_RegWrite <= 1; end
                MUL: begin EX_MEM_ALUOut <= ID_EX_A * ID_EX_B; EX_MEM_RegWrite <= 1; end
                ADDI: begin EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM; EX_MEM_RegWrite <= 1; end
                SUBI: begin EX_MEM_ALUOut <= ID_EX_A - ID_EX_IMM; EX_MEM_RegWrite <= 1; end
                SLTI: begin EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_IMM)) ? 32'd1 : 32'd0; EX_MEM_RegWrite <= 1; end
                LW:  begin EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM; EX_MEM_MemRead <= 1; EX_MEM_RegWrite <= 1; end
                SW:  begin EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM; EX_MEM_MemWrite <= 1; end
                default: EX_MEM_ALUOut <= 0;
            endcase
        end 
    end

    // ==========================================
    // MEM Stage: Memory Access
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_opcode <= 0;
            MEM_WB_RD <= 0;
            MEM_WB_ALUOut <= 0;
            MEM_WB_RegWrite <= 0;
            MEM_WB_MemRead <= 0;
            MEM_WB_MemWrite <= 0;
            MEM_WB_LMD <= 0;
        end else if (!HALTED) begin
            MEM_WB_opcode <= EX_MEM_opcode;
            MEM_WB_RD <= EX_MEM_RD;
            MEM_WB_ALUOut <= EX_MEM_ALUOut;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemRead <= EX_MEM_MemRead;
            MEM_WB_MemWrite <= EX_MEM_MemWrite;
            
            case (EX_MEM_opcode)
                LW: begin
                    if (EX_MEM_MemRead)
                        MEM_WB_LMD <= MEM[EX_MEM_ALUOut];
                end
                SW: begin
                    if (EX_MEM_MemWrite)
                        MEM[EX_MEM_ALUOut] <= EX_MEM_B;
                end
                default: MEM_WB_LMD <= 0;
            endcase
        end
    end

    // ==========================================
    // WB Stage: Write Back
    // ==========================================
    always @(posedge clk or negedge rst_n) begin   
        if (!rst_n) begin
            // Reset Registers to known state (Optional but good for simulation)
            for (i=0; i<32; i=i+1) REG[i] <= 0;
        end else begin
            case (MEM_WB_opcode)
                ADD, SUB, AND, OR, SLT, MUL, ADDI, SUBI, SLTI: begin
                    if (MEM_WB_RegWrite && MEM_WB_RD != 0)        
                        REG[MEM_WB_RD] <= MEM_WB_ALUOut;
                end
                LW: begin
                    if (MEM_WB_RegWrite && MEM_WB_RD != 0)
                        REG[MEM_WB_RD] <= MEM_WB_LMD;
                end
                HLT: begin
                    HALTED <= 1;
                end
            endcase
            // Enforce R0 = 0
            REG[0] <= 0;
        end
    end

endmodule
