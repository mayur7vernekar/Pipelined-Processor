module MIPS32_processor(input clk);

reg [31:0] REG [0:31];
reg [31:0] MEM [0:1023];
reg [31:0] PC;

reg [31:0] IF_ID_IR, IF_ID_PC;
reg [31:0] ID_EX_A, ID_EX_B, ID_EX_IMM, ID_EX_PC;
reg [31:0] EX_MEM_ALUOut, EX_MEM_B;
reg [31:0] MEM_WB_LMD, MEM_WB_ALUOut;
reg [5:0]  ID_EX_opcode,EX_MEM_opcode,MEM_WB_opcode;
reg [4:0]  ID_EX_RD, EX_MEM_RD, MEM_WB_RD;
reg  ID_EX_RegDst, ID_EX_ALUSrc, ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite;
reg  EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
reg  MEM_WB_RegWrite, MEM_WB_MemRead, MEM_WB_MemWrite;

parameter ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011;
parameter SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111;
parameter LW = 6'b001000, SW = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100;
parameter BEQ = 6'b001101, BNE = 6'b001110;

reg HALTED;
reg TAKEN_BRANCH;

always @ (posedge clk)
begin
  if(HALTED == 0)
  begin
  IF_ID_IR <= MEM[PC];
  PC <= PC + 1;
  IF_ID_PC <= PC;
  end
end

always @ (posedge clk)
begin
    if(HALTED == 0)
    begin
    ID_EX_PC <= IF_ID_PC;
    ID_EX_opcode <= IF_ID_IR[31:26];
    
    // **ADDED: Forwarding logic for operand A**
    if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[25:21]))
        ID_EX_A <= EX_MEM_ALUOut;  // Forward from EX/MEM stage
    else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[25:21]))
        ID_EX_A <= MEM_WB_ALUOut;  // Forward from MEM/WB stage
    else
        ID_EX_A <= REG[IF_ID_IR[25:21]];
    
    // **ADDED: Forwarding logic for operand B**
    if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[20:16]))
        ID_EX_B <= EX_MEM_ALUOut;  // Forward from EX/MEM stage
    else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[20:16]))
        ID_EX_B <= MEM_WB_ALUOut;  // Forward from MEM/WB stage
    else
        ID_EX_B <= REG[IF_ID_IR[20:16]];
    
    ID_EX_IMM <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
    
    case (IF_ID_IR[31:26])
        ADDI, SUBI, SLTI, LW: ID_EX_RD <= IF_ID_IR[20:16];
        default: ID_EX_RD <= IF_ID_IR[15:11];
    endcase
    end
end

always @ (posedge clk)
begin   
    if(HALTED == 0)
    begin
    EX_MEM_RD <= ID_EX_RD;
    EX_MEM_B <= ID_EX_B;
    EX_MEM_opcode <= ID_EX_opcode;
    
    // **CHANGE 2: Initialize control signals to 0**
    EX_MEM_RegWrite <= 0;
    EX_MEM_MemRead <= 0;
    EX_MEM_MemWrite <= 0;

    case (ID_EX_opcode)
    ADD: begin
        EX_MEM_ALUOut <= ID_EX_A + ID_EX_B;
        EX_MEM_RegWrite <= 1;
    end
    SUB: begin
        EX_MEM_ALUOut <= ID_EX_A - ID_EX_B;
        EX_MEM_RegWrite <= 1;
    end
    AND: begin
        EX_MEM_ALUOut <= ID_EX_A & ID_EX_B;
        EX_MEM_RegWrite <= 1;
    end
    OR: begin
        EX_MEM_ALUOut <= ID_EX_A | ID_EX_B;
        EX_MEM_RegWrite <= 1;
    end
    SLT: begin
        EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_B)) ? 32'd1 : 32'd0;
        EX_MEM_RegWrite <= 1;
    end
    MUL: begin
        EX_MEM_ALUOut <= ID_EX_A * ID_EX_B;
        EX_MEM_RegWrite <= 1;
    end
    ADDI: begin
        EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
        EX_MEM_RegWrite <= 1;
    end
    SUBI: begin
        EX_MEM_ALUOut <= ID_EX_A - ID_EX_IMM;
        EX_MEM_RegWrite <= 1;
    end
    SLTI: begin
        EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_IMM)) ? 32'd1 : 32'd0;
        EX_MEM_RegWrite <= 1;
    end
    LW: begin
     EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
     EX_MEM_MemRead <= 1;
     EX_MEM_RegWrite <= 1;
    end
    SW: begin
        EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
        EX_MEM_MemWrite <= 1;
    end
    default: EX_MEM_ALUOut <= 0;
    endcase
    end 
end

always @ (posedge clk)
begin
if(HALTED == 0)
begin
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
        default: begin
            MEM_WB_LMD <= 0;
        end
    endcase
end
end

always @ (posedge clk)
begin   
case (MEM_WB_opcode)
    ADD, SUB, AND, OR, SLT, MUL, ADDI, SUBI, SLTI: begin
        // **CHANGE 3: Don't write to R0**
        if (MEM_WB_RegWrite && MEM_WB_RD != 0)        
        REG[MEM_WB_RD] <= MEM_WB_ALUOut;
    end
    LW: begin
        // **CHANGE 3: Don't write to R0**
        if (MEM_WB_RegWrite && MEM_WB_RD != 0)
        REG[MEM_WB_RD] <= MEM_WB_LMD;
    end
    HLT: begin
        HALTED <= 1;
    end
    default: begin
    end
endcase

// **CHANGE 4: Enforce R0 = 0**
REG[0] <= 0;
end
endmodule
