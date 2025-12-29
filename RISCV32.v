module RISCV32(
    input clk,
    input rst_n  // Active-low reset input
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
    reg [6:0]  ID_EX_opcode, EX_MEM_opcode, MEM_WB_opcode;
    reg [4:0]  ID_EX_RD, EX_MEM_RD, MEM_WB_RD;
    reg        ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite;
    reg        EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
    reg        MEM_WB_RegWrite, MEM_WB_MemRead, MEM_WB_MemWrite;

    // RISC-V RV32I Opcodes (7 bits)
    parameter ADD_OP    = 7'b0110011;  // ADD/SUB
    parameter ADDI_OP   = 7'b0010011;  // ADD Immediate
    parameter AND_OP    = 7'b0110011;  // AND
    parameter ANDI_OP   = 7'b0010011;  // AND Immediate
    parameter OR_OP     = 7'b0110011;  // OR
    parameter ORI_OP    = 7'b0010011;  // OR Immediate
    parameter SLT_OP    = 7'b0110011;  // Set Less Than
    parameter SLTI_OP   = 7'b0010011;  // Set Less Than Immediate
    parameter LW_OP     = 7'b0000011;  // Load Word
    parameter SW_OP     = 7'b0100011;  // Store Word
    parameter BEQ_OP    = 7'b1100011;  // Branch Equal
    parameter BNE_OP    = 7'b1100011;  // Branch Not Equal
    
    // Function codes (funct3)
    parameter ADDI_FUNC = 3'b000;
    parameter ADD_FUNC  = 3'b000;
    parameter SUB_FUNC  = 3'b000;
    parameter AND_FUNC  = 3'b111;
    parameter OR_FUNC   = 3'b110;
    parameter SLT_FUNC  = 3'b010;
    parameter LW_FUNC   = 3'b010;
    parameter SW_FUNC   = 3'b010;
    parameter BEQ_FUNC  = 3'b000;
    parameter BNE_FUNC  = 3'b001;

    reg HALTED;
    reg TAKEN_BRANCH;
    reg [31:0] BRANCH_PC;  // Computed branch PC for early branch resolution
    integer i; // Loop variable for resetting registers
    
    // Hazard Detection Unit
    wire STALL;  // Stall signal to freeze pipeline
    
    // Branch signals for early branch resolution in ID stage
    wire BRANCH_DETECTED;
    wire [31:0] IMMEDIATE_ID;  // Immediate value computed in ID stage

    // ==========================================
    // RV32I Immediate Generator (4 Types)
    // ==========================================
    // Generates immediates for I-Type, S-Type, B-Type, and J-Type instructions
    // Input: IF_ID_IR (32-bit instruction)
    // Output: IMMEDIATE_ID (32-bit sign-extended immediate)
    reg [31:0] immediate_value;
    assign IMMEDIATE_ID = immediate_value;
    
    always @(*) begin
        case (IF_ID_IR[6:0])
            // I-Type: ADDI, SLTI, LW
            // Immediate = sign_extend(Instr[31:20])
            7'b0010011,     // ADDI, SLTI, ANDI, ORI
            7'b0000011: begin  // LW
                immediate_value = {{20{IF_ID_IR[31]}}, IF_ID_IR[31:20]};
            end
            
            // S-Type: SW
            // Immediate = sign_extend({Instr[31:25], Instr[11:7]})
            7'b0100011: begin  // SW
                immediate_value = {{20{IF_ID_IR[31]}}, IF_ID_IR[31:25], IF_ID_IR[11:7]};
            end
            
            // B-Type: BEQ, BNE
            // Immediate = sign_extend({Instr[31], Instr[7], Instr[30:25], Instr[11:8]}) << 1
            7'b1100011: begin  // BEQ, BNE
                immediate_value = {{20{IF_ID_IR[31]}}, IF_ID_IR[7], IF_ID_IR[30:25], IF_ID_IR[11:8], 1'b0};
            end
            
            // J-Type: JAL
            // Immediate = sign_extend({Instr[31], Instr[19:12], Instr[20], Instr[30:21]}) << 1
            7'b1101111: begin  // JAL
                immediate_value = {{12{IF_ID_IR[31]}}, IF_ID_IR[19:12], IF_ID_IR[20], IF_ID_IR[30:21], 1'b0};
            end
            
            default: immediate_value = 32'b0;
        endcase
    end

    // ==========================================
    // Hazard Detection Unit (HDU) - Updated for RV32I
    // ==========================================
    // Detect Load-Use Hazards:
    // If instruction in EX stage is a Load (EX_MEM_MemRead=1) and
    // its destination register (EX_MEM_RD) matches a source register
    // in ID stage (IF_ID_IR[19:15] for rs1 or IF_ID_IR[24:20] for rs2),
    // then stall the pipeline
    assign STALL = (EX_MEM_MemRead && EX_MEM_RD != 0) &&
                   (EX_MEM_RD == IF_ID_IR[19:15] || EX_MEM_RD == IF_ID_IR[24:20]);

    // ==========================================
    // Early Branch Resolution (ID Stage)
    // ==========================================
    // Detect branch instructions and compare operands in parallel
    wire [31:0] RS1_ID, RS2_ID;
    assign RS1_ID = REG[IF_ID_IR[19:15]];
    assign RS2_ID = REG[IF_ID_IR[24:20]];
    
    wire branch_equal = (RS1_ID == RS2_ID);
    wire is_beq = (IF_ID_IR[6:0] == BEQ_OP) && (IF_ID_IR[14:12] == BEQ_FUNC);
    wire is_bne = (IF_ID_IR[6:0] == BNE_OP) && (IF_ID_IR[14:12] == BNE_FUNC);
    
    // Branch is taken if:
    // (BEQ and values equal) or (BNE and values not equal)
    assign BRANCH_DETECTED = (is_beq && branch_equal) || (is_bne && !branch_equal);

    // ==========================================
    // IF Stage: Instruction Fetch
    // ==========================================
    // Updated for early branch resolution:
    // If branch is detected in ID stage (1 cycle early), update PC immediately
    // Provides significant performance improvement vs delayed branch in EX stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC <= 32'b0;
            IF_ID_IR <= 32'b0;
            IF_ID_PC <= 32'b0;
            HALTED <= 0;
            TAKEN_BRANCH <= 0;
        end else if (!HALTED && !STALL) begin
            // Normal operation: increment PC and fetch instruction
            IF_ID_IR <= MEM[PC];
            IF_ID_PC <= PC;
            
            // Early branch resolution reduces penalty from 3 cycles to 1 cycle
            if (BRANCH_DETECTED) begin
                PC <= IF_ID_PC + IMMEDIATE_ID;  // Update PC with branch target
                TAKEN_BRANCH <= 1;
            end else begin
                PC <= PC + 1;
                TAKEN_BRANCH <= 0;
            end
        end else if (!HALTED && STALL) begin
            // Stall: Freeze PC and IF/ID register, keep current values
            // No update occurs - pipeline stage is frozen
        end
    end

    // ==========================================
    // ID Stage: Instruction Decode (RV32I)
    // ==========================================
    // Stall Mechanism: When hazard detected, flush ID/EX control signals to zero (insert bubble)
    // Branch Flush: When branch taken, flush IF stage instruction with 1-cycle penalty
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_PC <= 0;
            ID_EX_opcode <= 0;
            ID_EX_A <= 0;
            ID_EX_B <= 0;
            ID_EX_IMM <= 0;
            ID_EX_RD <= 0;
        end else if (!HALTED && TAKEN_BRANCH) begin
            // Branch was taken: Flush the instruction in IF stage (1-cycle penalty)
            // This replaces the 3-cycle penalty from delayed branch resolution in EX stage
            ID_EX_PC <= 0;
            ID_EX_opcode <= 0;
            ID_EX_A <= 0;
            ID_EX_B <= 0;
            ID_EX_IMM <= 0;
            ID_EX_RD <= 0;
        end else if (!HALTED && STALL) begin
            // Stall detected: Insert a bubble by flushing all ID/EX signals to zero
            ID_EX_PC <= 0;
            ID_EX_opcode <= 0;
            ID_EX_A <= 0;
            ID_EX_B <= 0;
            ID_EX_IMM <= 0;
            ID_EX_RD <= 0;
        end else if (!HALTED && !STALL) begin
            // Normal operation: Decode instruction and pass to next stage
            ID_EX_PC <= IF_ID_PC;
            
            // RV32I Opcode is at Instr[6:0] (7 bits)
            ID_EX_opcode <= IF_ID_IR[6:0];
            
            // RV32I Register fields:
            // rs1 (source register 1): Instr[19:15]
            // rs2 (source register 2): Instr[24:20]
            
            // Forwarding Logic A (rs1)
            if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[19:15]))
                ID_EX_A <= EX_MEM_ALUOut;
            else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[19:15]))
                ID_EX_A <= MEM_WB_ALUOut;
            else
                ID_EX_A <= REG[IF_ID_IR[19:15]];
            
            // Forwarding Logic B (rs2)
            if ((EX_MEM_RegWrite) && (EX_MEM_RD != 0) && (EX_MEM_RD == IF_ID_IR[24:20]))
                ID_EX_B <= EX_MEM_ALUOut;
            else if ((MEM_WB_RegWrite) && (MEM_WB_RD != 0) && (MEM_WB_RD == IF_ID_IR[24:20]))
                ID_EX_B <= MEM_WB_ALUOut;
            else
                ID_EX_B <= REG[IF_ID_IR[24:20]];
            
            // Immediate value from RV32I generator
            ID_EX_IMM <= IMMEDIATE_ID;
            
            // RV32I Destination Register Rd: Instr[11:7]
            ID_EX_RD <= IF_ID_IR[11:7];
        end
    end

    // ==========================================
    // EX Stage: Execution (RV32I)
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
                // R-Type Instructions (ADD, SUB, AND, OR, SLT)
                ADD_OP: begin
                    case (ID_EX_IMM[14:12])  // Use funct3 from immediate placeholder for R-type
                        3'b000: begin  // ADD or SUB (distinguished by funct7[5])
                            if (ID_EX_IMM[30] == 1'b0)
                                EX_MEM_ALUOut <= ID_EX_A + ID_EX_B;  // ADD
                            else
                                EX_MEM_ALUOut <= ID_EX_A - ID_EX_B;  // SUB
                        end
                        3'b111: EX_MEM_ALUOut <= ID_EX_A & ID_EX_B;   // AND
                        3'b110: EX_MEM_ALUOut <= ID_EX_A | ID_EX_B;   // OR
                        3'b010: EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_B)) ? 32'd1 : 32'd0;  // SLT
                    endcase
                    EX_MEM_RegWrite <= 1;
                end
                
                // I-Type Instructions (ADDI, SLTI, LW)
                ADDI_OP: begin
                    case (ID_EX_IMM[14:12])  // funct3
                        3'b000: EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;  // ADDI
                        3'b111: EX_MEM_ALUOut <= ID_EX_A & ID_EX_IMM;  // ANDI
                        3'b110: EX_MEM_ALUOut <= ID_EX_A | ID_EX_IMM;  // ORI
                        3'b010: EX_MEM_ALUOut <= ((ID_EX_A) < (ID_EX_IMM)) ? 32'd1 : 32'd0;  // SLTI
                    endcase
                    EX_MEM_RegWrite <= 1;
                end
                
                LW_OP: begin
                    // Load Word: Calculate address = rs1 + immediate
                    EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
                    EX_MEM_MemRead <= 1;
                    EX_MEM_RegWrite <= 1;
                end
                
                SW_OP: begin
                    // Store Word: Calculate address = rs1 + immediate
                    EX_MEM_ALUOut <= ID_EX_A + ID_EX_IMM;
                    EX_MEM_MemWrite <= 1;
                end
                
                // Branch instructions (BEQ, BNE) - Already resolved in ID stage
                // No action needed in EX stage
                BEQ_OP, BNE_OP: begin
                    // Branches already handled in ID stage
                    EX_MEM_ALUOut <= 0;
                end
                
                default: EX_MEM_ALUOut <= 0;
            endcase
        end 
    end

    // ==========================================
    // MEM Stage: Memory Access (RV32I)
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
                LW_OP: begin
                    if (EX_MEM_MemRead)
                        MEM_WB_LMD <= MEM[EX_MEM_ALUOut];
                end
                SW_OP: begin
                    if (EX_MEM_MemWrite)
                        MEM[EX_MEM_ALUOut] <= EX_MEM_B;
                end
                default: MEM_WB_LMD <= 0;
            endcase
        end
    end

    // ==========================================
    // WB Stage: Write Back (RV32I)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin   
        if (!rst_n) begin
            // Reset Registers to known state
            for (i=0; i<32; i=i+1) REG[i] <= 0;
        end else begin
            // Write back results to register file
            if (MEM_WB_RegWrite && MEM_WB_RD != 0) begin
                case (MEM_WB_opcode)
                    // Load Word (write memory data)
                    LW_OP: begin
                        REG[MEM_WB_RD] <= MEM_WB_LMD;
                    end
                    
                    // All other register-write opcodes (write ALU result)
                    default: begin
                        REG[MEM_WB_RD] <= MEM_WB_ALUOut;
                    end
                endcase
            end
            
            // Enforce x0 = 0 (x0 is hardwired to zero in RISC-V)
            REG[0] <= 0;
        end
    end

endmodule
