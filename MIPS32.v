module MIPS32_processor(input clk);

reg [31:0] REG [0:31]; // 32 registers of 32 bits each
reg [31:0] MEM [0:1023]; // Memory of 1024 words (32 bits each)
reg [31:0] PC; // Program Counter

reg [31:0] IF_ID_IR, IF_ID_PC; // IF_ID pipeline registers
reg [31:0] ID_EX_A, ID_EX_B, ID_EX_IMM, ID_EX_PC; // ID_EX pipeline registers
reg [31:0] EX_MEM_ALUOut, EX_MEM_B; // EX_MEM pipeline registers
reg [31:0] MEM_WB_LMD, MEM_WB_ALUOut; // MEM_WB pipeline registers
reg [5:0]  ID_EX_opcode,EX_MEM_opcode,MEM_WB_opcode; // opcode fields
reg [4:0]  ID_EX_RD, EX_MEM_RD, MEM_WB_RD;
reg  ID_EX_RegDst, ID_EX_ALUSrc, ID_EX_MemtoReg, ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite;
reg  EX_MEM_MemtoReg, EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
reg  MEM_WB_MemtoReg, MEM_WB_RegWrite;

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
  IF_ID_IR <= MEM[PC]; // Fetch instruction
  PC <= PC + 1;// Increment PC
  IF_ID_PC <= PC;
  end
end

always @ (posedge clk)
begin
    if(HALTED == 0)
    begin
    ID_EX_PC <= IF_ID_PC;
    ID_EX_opcode <= IF_ID_IR[31:26];
    ID_EX_A <= REG[IF_ID_IR[25:21]]; // rs
    ID_EX_B <= REG[IF_ID_IR[20:16]]; // rt
    ID_EX_IMM <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]}; // sign-extend immediate
    ID_EX_RD <= IF_ID_IR[15:11]; // rd
    end
end

always @ (posedge clk)
begin   
    if(HALTED == 0)
    begin
    EX_MEM_RD <= ID_EX_RD;
    EX_MEM_B <= ID_EX_B;
    EX_MEM_opcode <= ID_EX_opcode;

    case (ID_EX_OPCODE)
        ADD: EX_MEM_ALUOut <= ID_EX_A + ID_EX_B;
        SUB: EX_MEM_ALUOut <= ID_EX_A - ID_EX_B;
        AND: EX_MEM_ALUOut <= ID_EX_A & ID_EX_B;
        OR:  EX_MEM_ALUOut <= ID_EX_A | ID_EX_B;
        SLT: EX_MEM_ALUOut <= (ID_EX_A < ID_EX_B) ? 1 : 0;
        MUL: EX_MEM_ALUOut <= ID_EX_A * ID_EX_B;
        ADDI: EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
        SUBI: EX_MEM_ALUOut <= ID_EX_A - ID_EX_IMM;
        SLTI: EX_MEM_ALUOut <= (ID_EX_A < ID_EX_IMM) ? 1 : 0;
        default: EX_MEM_ALUOut <= 0; // NOP for unrecognized opcode
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
    case (EX_MEM_opcode)
        LW: begin
            MEM_WB_LMD <= MEM[EX_MEM_ALUOut]; // Load from memory
        end
        SW: begin
            MEM[EX_MEM_ALUOut] <= EX_MEM_B; // Store to memory
        end
        default: begin
            MEM_WB_LMD <= 0; // NOP for non-load instructions
        end
    endcase
end
end

always @ (posedge clk)
begin   
case (MEM_WB_opcode)
    ADD, SUB, AND, OR, SLT, MUL, ADDI, SUBI, SLTI: begin
        REG[MEM_WB_RD] <= MEM_WB_ALUOut; // Write back ALU result
    end
    LW: begin
        REG[MEM_WB_RD] <= MEM_WB_LMD; // Write back loaded data
    end
    HLT: begin
        HALTED <= 1; // Halt the processor
    end
    default: begin
        // NOP for unrecognized opcode
    end
endcase
end
endmodule
        