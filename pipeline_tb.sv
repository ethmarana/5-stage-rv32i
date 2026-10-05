`timescale 1ns/1ps


// builds custom programs by encoding instructions into 32-bit instruction words.
// loads those programs into the CPU's instruction memory.
// a separate reference model executes the same program to calculate the correct results.
// while the CPU runs, each register write and memory store is compared with those results.
// also checks that stalls hold instructions and flushes cancel younger instructions.
// after each program, checks the final register and memory contents.
// prints PASS if everything matches, or stops and reports the mismatch.
module pipeline_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    tpross dut (.clk(clk), .reset(reset));
    always #5 clk = ~clk;

    localparam logic [31:0] NOP = 32'h00000013;
    localparam int MAX_EVENTS = 2048;
    localparam int MAX_CYCLES = 1500;

    logic [31:0] image [0:255];
    logic [31:0] seed_memory [0:255];
    logic [31:0] model_memory [0:255];
    logic [31:0] model_regs [0:31];
    logic [4:0] expected_rd [0:MAX_EVENTS-1];
    logic [31:0] expected_result [0:MAX_EVENTS-1];
    logic [31:0] expected_write_pc [0:MAX_EVENTS-1];
    logic [31:0] expected_address [0:MAX_EVENTS-1];
    logic [31:0] expected_store [0:MAX_EVENTS-1];
    logic [31:0] expected_store_pc [0:MAX_EVENTS-1];

    string test_name;
    int words, end_pc, cycle;
    int writes_expected, stores_expected, stalls_expected, redirects_expected;
    int writes_seen, stores_seen, stalls_seen, redirects_seen;
    int checks = 0;
    int tests_passed = 0;
    int total_writes = 0, total_stores = 0;
    int total_stalls = 0, total_redirects = 0;
    bit trace_enabled;
    logic [31:0] random_state;

    task automatic require(input logic condition, input string message);
        checks++;
        if (condition !== 1'b1) begin
            $error("FAIL [%s] cycle %0d: %s", test_name, cycle, message);
            $display("  PC F=%08h D=%08h E=%08h, valid D/E/M/W=%b%b%b%b",
                dut.pcF, dut.pcD, dut.pcE,
                dut.validD, dut.validE, dut.validM, dut.validW);
            $fatal(1, "Pipeline test failed");
        end
    endtask

    task automatic check32(input logic [31:0] actual,
        input logic [31:0] expected, input string message);
        require(actual === expected,
            $sformatf("%s: expected %08h, got %08h", message, expected, actual));
    endtask

    function automatic logic [31:0] enc_r(input logic [6:0] f7,
        input logic [4:0] rs2, rs1, input logic [2:0] f3,
        input logic [4:0] rd);
        return {f7, rs2, rs1, f3, rd, 7'b0110011};
    endfunction

    function automatic logic [31:0] enc_i(input int immediate,
        input logic [4:0] rs1, input logic [2:0] f3,
        input logic [4:0] rd, input logic [6:0] opcode);
        return {immediate[11:0], rs1, f3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_s(input int immediate,
        input logic [4:0] rs2, rs1);
        return {immediate[11:5], rs2, rs1, 3'b010,
            immediate[4:0], 7'b0100011};
    endfunction

    function automatic logic [31:0] enc_b(input int offset,
        input logic [4:0] rs2, rs1, input logic [2:0] f3);
        return {offset[12], offset[10:5], rs2, rs1, f3,
            offset[4:1], offset[11], 7'b1100011};
    endfunction

    function automatic logic [31:0] enc_u(input logic [19:0] upper,
        input logic [4:0] rd, input logic [6:0] opcode);
        return {upper, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_j(input int offset,
        input logic [4:0] rd);
        return {offset[20], offset[10:1], offset[11], offset[19:12],
            rd, 7'b1101111};
    endfunction

    function automatic bit reads_rs1(input logic [6:0] opcode);
        case (opcode)
            7'h33, 7'h13, 7'h03, 7'h23, 7'h63, 7'h67: return 1'b1;
            default: return 1'b0;
        endcase
    endfunction

    function automatic bit reads_rs2(input logic [6:0] opcode);
        case (opcode)
            7'h33, 7'h23, 7'h63: return 1'b1;
            default: return 1'b0;
        endcase
    endfunction

    task automatic clear_program(input string name);
        test_name = name;
        words = 0;
        cycle = 0;
        for (int i = 0; i < 256; i++) begin
            image[i] = NOP;
            seed_memory[i] = 32'h13579bdf ^ (32'(i) * 32'h01020305);
        end
        seed_memory[32] = 32'd512;
        seed_memory[33] = 32'hdeadbeef;
        seed_memory[34] = 32'h80000001;
        seed_memory[35] = 32'h2468ace0;
        seed_memory[36] = 32'd512;
    endtask

    task automatic emit(input logic [31:0] instruction);
        require(words < 250, "Test program is too large for IM");
        image[words] = instruction;
        words++;
    endtask

    task automatic addi(input logic [4:0] rd, rs1, input int value);
        emit(enc_i(value, rs1, 3'b000, rd, 7'h13));
    endtask

    task automatic lw(input logic [4:0] rd, rs1, input int offset);
        emit(enc_i(offset, rs1, 3'b010, rd, 7'h03));
    endtask

    task automatic sw(input logic [4:0] rs2, rs1, input int offset);
        emit(enc_s(offset, rs2, rs1));
    endtask

    // Executes the program independently of DUT control signals and timing.
    // Records the complete architectural write/store streams and final state.
    task automatic make_reference;
        logic [31:0] pc, next_pc, instruction, a, b, answer, address;
        logic [31:0] immediate;
        logic [6:0] opcode;
        logic [2:0] f3;
        logic [4:0] rs1, rs2, rd;
        bit writes_register, redirect, condition;
        int steps, previous_load_rd;

        writes_expected = 0;
        stores_expected = 0;
        stalls_expected = 0;
        redirects_expected = 0;
        for (int i = 0; i < 32; i++) model_regs[i] = 32'b0;
        for (int i = 0; i < 256; i++) model_memory[i] = seed_memory[i];
        pc = 0;
        steps = 0;
        previous_load_rd = -1;

        while (pc != 32'(end_pc)) begin
            require(pc[1:0] == 0 && pc < 32'(end_pc),
                $sformatf("Reference jumped outside the test: %08h", pc));
            require(steps < MAX_EVENTS, "Reference program did not terminate");
            instruction = image[pc >> 2];
            opcode = instruction[6:0];
            f3 = instruction[14:12];
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];
            rd = instruction[11:7];
            a = model_regs[rs1];
            b = model_regs[rs2];
            next_pc = pc + 4;
            answer = 0;
            writes_register = 0;
            redirect = 0;
            condition = 0;

            if (previous_load_rd > 0 &&
                ((reads_rs1(opcode) && int'(rs1) == previous_load_rd) ||
                 (reads_rs2(opcode) && int'(rs2) == previous_load_rd)))
                stalls_expected++;
            previous_load_rd = -1;

            case (opcode)
                7'h33: begin
                    writes_register = 1;
                    case (f3)
                        3'b000: answer = instruction[30] ? a - b : a + b;
                        3'b001: answer = a << b[4:0];
                        3'b010: answer = 32'($signed(a) < $signed(b));
                        3'b011: answer = 32'(a < b);
                        3'b100: answer = a ^ b;
                        3'b101: begin
                            if (instruction[30]) answer = $signed(a) >>> b[4:0];
                            else answer = a >> b[4:0];
                        end
                        3'b110: answer = a | b;
                        3'b111: answer = a & b;
                        default: require(0, "Unsupported reference ALU operation");
                    endcase
                end
                7'h13: begin
                    writes_register = 1;
                    immediate = {{20{instruction[31]}}, instruction[31:20]};
                    case (f3)
                        3'b000: answer = a + immediate;
                        3'b001: answer = a << instruction[24:20];
                        3'b010: answer = 32'($signed(a) < $signed(immediate));
                        3'b011: answer = 32'(a < immediate);
                        3'b100: answer = a ^ immediate;
                        3'b101: begin
                            if (instruction[30]) answer = $signed(a) >>> instruction[24:20];
                            else answer = a >> instruction[24:20];
                        end
                        3'b110: answer = a | immediate;
                        3'b111: answer = a & immediate;
                        default: require(0, "Unsupported reference immediate operation");
                    endcase
                end
                7'h03: begin
                    require(f3 == 3'b010, "TB only supports LW");
                    immediate = {{20{instruction[31]}}, instruction[31:20]};
                    address = a + immediate;
                    require(address[1:0] == 0 && address < 1024,
                        "Reference load address must be aligned and inside DM");
                    answer = model_memory[address >> 2];
                    writes_register = 1;
                    previous_load_rd = int'(rd);
                end
                7'h23: begin
                    require(f3 == 3'b010, "TB only supports SW");
                    immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                    address = a + immediate;
                    require(address[1:0] == 0 && address < 1024,
                        "Reference store address must be aligned and inside DM");
                    expected_address[stores_expected] = address;
                    expected_store[stores_expected] = b;
                    expected_store_pc[stores_expected] = pc;
                    stores_expected++;
                    model_memory[address >> 2] = b;
                end
                7'h63: begin
                    immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                        instruction[30:25], instruction[11:8], 1'b0};
                    case (f3)
                        3'b000: condition = a == b;
                        3'b001: condition = a != b;
                        3'b100: condition = $signed(a) < $signed(b);
                        3'b101: condition = $signed(a) >= $signed(b);
                        3'b110: condition = a < b;
                        3'b111: condition = a >= b;
                        default: require(0, "Unsupported reference branch");
                    endcase
                    if (condition) begin
                        next_pc = pc + immediate;
                        redirect = 1;
                    end
                end
                7'h6f: begin
                    immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                        instruction[20], instruction[30:21], 1'b0};
                    answer = pc + 4;
                    next_pc = pc + immediate;
                    writes_register = 1;
                    redirect = 1;
                end
                7'h67: begin
                    require(f3 == 0, "Unsupported reference JALR");
                    immediate = {{20{instruction[31]}}, instruction[31:20]};
                    answer = pc + 4;
                    next_pc = (a + immediate) & 32'hfffffffe;
                    writes_register = 1;
                    redirect = 1;
                end
                7'h37: begin
                    writes_register = 1;
                    answer = {instruction[31:12], 12'b0};
                end
                7'h17: begin
                    writes_register = 1;
                    answer = pc + {instruction[31:12], 12'b0};
                end
                default: require(0, $sformatf("Unsupported reference opcode %02h", opcode));
            endcase

            if (writes_register && rd != 0) begin
                expected_rd[writes_expected] = rd;
                expected_result[writes_expected] = answer;
                expected_write_pc[writes_expected] = pc;
                writes_expected++;
                model_regs[rd] = answer;
            end
            model_regs[0] = 0;
            if (redirect) redirects_expected++;
            pc = next_pc;
            steps++;
        end
    endtask

    task automatic load_dut;
        reset = 1'b1;
        @(negedge clk);
        for (int i = 0; i < 256; i++) begin
            dut.iminstance.memory[i] = image[i];
            dut.dminstance.memory[i] = seed_memory[i];
        end
        for (int i = 0; i < 32; i++) dut.rfinstance.regs[i] = 32'b0;
        repeat (2) begin
            @(posedge clk);
            #1;
            check32(dut.pcF, 0, "Reset PC");
            require({dut.validD, dut.validE, dut.validM, dut.validW} === 4'b0000,
                "Reset must empty every pipeline register");
        end
        @(negedge clk);
        reset = 1'b0;
    endtask

    task automatic run_program;
        logic [31:0] old_pcF, old_instrD, old_pcD, old_target;
        logic [31:0] ex_instruction;
        logic [31:0] store_address, store_value, wb_value;
        logic [4:0] wb_rd;
        bit old_validD, old_validE, old_validM;
        bit old_stallF, old_stallD, old_flushD, old_flushE, old_redirect;
        bit write_happens, store_happens, dependency;
        bit finished;
        int drain;

        end_pc = words * 4;
        image[words] = enc_i(2047, 0, 0, 0, 7'h13);
        make_reference();
        load_dut();
        writes_seen = 0;
        stores_seen = 0;
        stalls_seen = 0;
        redirects_seen = 0;
        finished = 0;
        drain = 0;
        cycle = 0;

        while (cycle < MAX_CYCLES && drain < 4) begin
            @(posedge clk);
            cycle++;

            // Sample BEFORE nonblocking assignments: these are the values
            // being written into RF, DM, and pipeline registers on this edge.
            old_pcF = dut.pcF;
            old_instrD = dut.instrD;
            old_pcD = dut.pcD;
            old_target = dut.pctargetE;
            old_validD = dut.validD;
            old_validE = dut.validE;
            old_validM = dut.validM;
            old_stallF = dut.stallF;
            old_stallD = dut.stallD;
            old_flushD = dut.flushD;
            old_flushE = dut.flushE;
            old_redirect = dut.redirectE;
            wb_rd = dut.rdW;
            wb_value = dut.resultW;
            write_happens = dut.rf_write_enable && wb_rd != 0;
            store_happens = dut.dm_write_enable;
            store_address = dut.alu_resultM;
            store_value = dut.storedataM;

            require(dut.rf_write_enable === (dut.validW && dut.regwriteW),
                "RF write enable must be valid-gated");
            require(dut.dm_write_enable === (dut.validM && dut.memwriteM),
                "DM write enable must be valid-gated");
            require(dut.uses_rs1D === (dut.validD && reads_rs1(dut.instrD[6:0])),
                "Decode uses_rs1D is incorrect");
            require(dut.uses_rs2D === (dut.validD && reads_rs2(dut.instrD[6:0])),
                "Decode uses_rs2D is incorrect");

            ex_instruction = NOP;
            dependency = 0;
            if (dut.validE) begin
                require(dut.pcE[1:0] == 0 && dut.pcE < 1024,
                    "EX PC must be an aligned address inside IM");
                ex_instruction = image[dut.pcE >> 2];
                require(dut.isloadE === (ex_instruction[6:0] == 7'h03),
                    "isloadE does not match the instruction in EX");
                if (ex_instruction[6:0] == 7'h03 && ex_instruction[11:7] != 0 && dut.validD)
                    dependency =
                        (reads_rs1(dut.instrD[6:0]) &&
                         dut.instrD[19:15] == ex_instruction[11:7]) ||
                        (reads_rs2(dut.instrD[6:0]) &&
                         dut.instrD[24:20] == ex_instruction[11:7]);
            end
            require(dut.stallF === (dependency && !dut.redirectE), "Incorrect Fetch stall");
            require(dut.stallD === (dependency && !dut.redirectE), "Incorrect Decode stall");
            require(dut.flushD === dut.redirectE, "Incorrect IF/ID flush");
            require(dut.flushE === (dependency || dut.redirectE), "Incorrect ID/EX flush");

            if (old_stallF) stalls_seen++;
            if (old_redirect) redirects_seen++;

            if (write_happens) begin
                require(writes_seen < writes_expected, "Unexpected register write (possibly wrong path)");
                require(wb_rd === expected_rd[writes_seen],
                    $sformatf("Write %0d: expected x%0d, got x%0d; reference PC=%08h",
                        writes_seen, expected_rd[writes_seen], wb_rd,
                        expected_write_pc[writes_seen]));
                check32(wb_value, expected_result[writes_seen],
                    $sformatf("Write %0d to x%0d, reference PC=%08h",
                        writes_seen, wb_rd, expected_write_pc[writes_seen]));
                writes_seen++;
            end
            if (store_happens) begin
                require(stores_seen < stores_expected, "Unexpected store (possibly wrong path)");
                check32(store_address, expected_address[stores_seen],
                    $sformatf("Store %0d address, reference PC=%08h",
                        stores_seen, expected_store_pc[stores_seen]));
                check32(store_value, expected_store[stores_seen],
                    $sformatf("Store %0d data", stores_seen));
                stores_seen++;
            end

            if (trace_enabled)
                $display("[%s] c=%0d F=%08h D=%08h E=%08h stall=%b%b flush=%b%b WB=%b x%0d=%08h SW=%b",
                    test_name, cycle, dut.pcF, dut.pcD, dut.pcE,
                    dut.stallF, dut.stallD, dut.flushD, dut.flushE,
                    write_happens, wb_rd, wb_value, store_happens);

            if (!finished && dut.validE && dut.pcE == 32'(end_pc)) finished = 1;
            if (finished) drain++;

            #1;
            // Now check the effects of the edge, after NBA updates settle.
            if (old_stallF) check32(dut.pcF, old_pcF, "PC must hold during stall");
            else if (old_redirect) check32(dut.pcF, old_target, "PC must take redirect target");
            else check32(dut.pcF, old_pcF + 4, "PC must advance by four");

            if (old_flushD) require(dut.validD === 1'b0, "IF/ID flush did not clear validD");
            else if (old_stallD) begin
                check32(dut.instrD, old_instrD, "IF/ID must retain the waiting instruction");
                check32(dut.pcD, old_pcD, "IF/ID must retain its PC");
                require(dut.validD === old_validD, "IF/ID must retain validD during stall");
            end
            if (old_flushE) require(dut.validE === 1'b0, "ID/EX flush did not insert a bubble");
            else require(dut.validE === old_validD, "ID/EX lost the valid bit");
            require(dut.validM === old_validE, "EX/MEM lost the valid bit");
            require(dut.validW === old_validM, "MEM/WB lost the valid bit");

            if (write_happens) check32(dut.rfinstance.regs[wb_rd], wb_value, "RF did not accept WB");
            if (store_happens) check32(dut.dminstance.memory[store_address >> 2],
                store_value, "DM did not accept the store");
            check32(dut.rfinstance.regs[0], 0, "x0 storage must stay zero");
            if (dut.rs1D == 0) check32(dut.rd1D, 0, "Reading x0 as rs1 must return zero");
            if (dut.rs2D == 0) check32(dut.rd2D, 0, "Reading x0 as rs2 must return zero");
        end

        require(finished && drain == 4, "Timeout: test end was never reached");
        require(writes_seen == writes_expected, "Missing register writes");
        require(stores_seen == stores_expected, "Missing stores");
        require(stalls_seen == stalls_expected,
            $sformatf("Load stalls: expected %0d, got %0d", stalls_expected, stalls_seen));
        require(redirects_seen == redirects_expected,
            $sformatf("Redirects: expected %0d, got %0d", redirects_expected, redirects_seen));
        for (int i = 0; i < 32; i++)
            check32(dut.rfinstance.regs[i], model_regs[i], $sformatf("Final x%0d", i));
        for (int i = 0; i < 256; i++)
            check32(dut.dminstance.memory[i], model_memory[i], $sformatf("Final DM word %0d", i));

        tests_passed++;
        total_writes += writes_seen;
        total_stores += stores_seen;
        total_stalls += stalls_seen;
        total_redirects += redirects_seen;
        $display("PASS %-32s cycles=%0d writes=%0d stores=%0d stalls=%0d redirects=%0d",
            test_name, cycle, writes_seen, stores_seen, stalls_seen, redirects_seen);
    endtask

    task automatic test_alu;
        clear_program("all ALU operations and immediates");
        addi(1, 0, -8);
        addi(2, 0, 3);
        addi(3, 0, 35);
        emit(enc_u(20'h80000, 4, 7'h37));
        emit(enc_u(20'h7ffff, 5, 7'h37));
        emit(enc_i(-1, 5, 3'b110, 5, 7'h13));
        emit(enc_r(0, 2, 1, 0, 6));
        emit(enc_r(7'h20, 2, 1, 0, 7));
        emit(enc_r(0, 3, 2, 1, 8));
        emit(enc_r(0, 2, 1, 2, 9));
        emit(enc_r(0, 2, 1, 3, 10));
        emit(enc_r(0, 2, 1, 4, 11));
        emit(enc_r(0, 3, 1, 5, 12));
        emit(enc_r(7'h20, 3, 1, 5, 13));
        emit(enc_r(0, 2, 1, 6, 14));
        emit(enc_r(0, 2, 1, 7, 15));
        emit(enc_i(-17, 2, 0, 16, 7'h13));
        emit(enc_i(31, 2, 1, 17, 7'h13));
        emit(enc_i(-1, 2, 2, 18, 7'h13));
        emit(enc_i(-1, 2, 3, 19, 7'h13));
        emit(enc_i(-1, 2, 4, 20, 7'h13));
        emit(enc_i(31, 1, 5, 21, 7'h13));
        emit(enc_i(1055, 1, 5, 22, 7'h13));
        emit(enc_i(16, 2, 6, 23, 7'h13));
        emit(enc_i(6, 1, 7, 24, 7'h13));
        addi(25, 5, 1);
        emit(enc_r(0, 4, 4, 0, 26));
        emit(enc_r(0, 1, 4, 2, 27));
        emit(enc_r(0, 4, 1, 2, 28));
        emit(enc_r(0, 4, 1, 3, 29));
        addi(30, 0, -2048);
        addi(31, 30, 2047);
        run_program();
    endtask

    task automatic test_forwarding;
        clear_program("MEM/WB forwarding, priority, bypass");
        addi(1, 0, 10);
        addi(2, 1, 20);
        emit(enc_r(0, 2, 1, 0, 3)); // WB supplies rs1; MEM supplies rs2.
        addi(4, 0, 100);
        addi(4, 4, 1);
        emit(enc_r(0, 4, 4, 0, 5)); // New MEM value must beat old WB value.
        addi(6, 0, 50);
        emit(NOP);
        emit(NOP);
        addi(7, 6, 1); // Producer WB and consumer ID on the same edge.
        addi(8, 0, 70);
        emit(NOP);
        emit(enc_r(0, 8, 8, 0, 9)); // WB forwarding for both EX operands.
        addi(0, 0, 123);
        emit(enc_r(0, 0, 0, 0, 10)); // Never forward a write to x0.
        emit(enc_u(20'habcde, 11, 7'h37));
        addi(12, 11, 5); // LUI forwarding must use immM, not the ALU.
        emit(enc_u(20'h00001, 13, 7'h17));
        addi(14, 13, 4); // AUIPC forwarding must include the instruction PC.
        addi(17, 0, 51);
        emit(NOP);
        emit(NOP);
        emit(enc_r(0, 17, 1, 0, 18)); // WB-to-ID bypass on rs2.
        addi(19, 0, 13);
        addi(20, 0, 17);
        emit(enc_r(0, 19, 20, 0, 21)); // MEM supplies rs1; WB supplies rs2.
        run_program();
    endtask

    task automatic test_loads_stores;
        clear_program("load-use and store-data/address paths");
        addi(10, 0, 128);
        lw(1, 10, 0);
        addi(2, 1, 7);
        lw(3, 10, 4);
        emit(enc_r(0, 3, 2, 0, 4));
        lw(5, 10, 8);
        emit(enc_r(0, 5, 5, 0, 6));
        lw(7, 10, 12);
        sw(7, 10, 32);
        lw(8, 10, 16);
        sw(6, 8, 0);
        lw(0, 10, 0);
        emit(enc_r(0, 0, 0, 0, 9));
        lw(11, 10, 8);
        emit(NOP);
        emit(enc_r(0, 2, 11, 0, 12));
        addi(13, 0, 77);
        sw(13, 10, 36);
        lw(14, 10, 36);
        emit(enc_r(0, 13, 14, 0, 15));
        addi(16, 10, 40);
        sw(15, 16, 0);
        addi(17, 10, 44);
        addi(18, 0, 88);
        sw(18, 17, 0);
        addi(19, 10, 52);
        sw(19, 19, -4);
        addi(20, 0, 1);
        lw(20, 10, 4);
        addi(21, 20, 1); // A younger load must replace the old x20 value.
        run_program();
    endtask

    task automatic test_no_false_stalls;
        clear_program("unused source fields and x0");
        lw(5, 0, 128);
        addi(6, 0, 5); // Immediate bits look like rs2=x5, but rs2 is unused.
        lw(7, 0, 132);
        emit(enc_u(20'((7 << 3) | (7 << 8)), 8, 7'h37));
        lw(9, 0, 136);
        emit(enc_u(20'((9 << 3) | (9 << 8)), 10, 7'h17));
        lw(0, 0, 128);
        addi(11, 0, 1);
        lw(12, 0, 132);
        addi(13, 0, 2);
        run_program();
    endtask

    task automatic branch_case(input logic [2:0] f3,
        input logic [4:0] rs1, rs2);
        emit(enc_b(12, rs2, rs1, f3));
        addi(20, 20, 1);
        sw(20, 0, 0);
        addi(21, 21, 1);
    endtask

    task automatic test_branches;
        clear_program("all branches, wrong paths, backward loop");
        addi(1, 0, -1);
        addi(2, 0, 1);
        branch_case(3'b000, 1, 1);
        branch_case(3'b000, 1, 2);
        branch_case(3'b001, 1, 2);
        branch_case(3'b001, 1, 1);
        branch_case(3'b100, 1, 2);
        branch_case(3'b100, 2, 1);
        branch_case(3'b101, 2, 1);
        branch_case(3'b101, 1, 2);
        branch_case(3'b110, 2, 1);
        branch_case(3'b110, 1, 2);
        branch_case(3'b111, 1, 2);
        branch_case(3'b111, 2, 1);
        branch_case(3'b100, 1, 1); // Equal values must fail BLT/BLTU.
        branch_case(3'b101, 1, 1); // Equal values must satisfy BGE/BGEU.
        branch_case(3'b110, 1, 1);
        branch_case(3'b111, 1, 1);
        lw(3, 0, 128);
        branch_case(3'b000, 3, 3); // Load-to-branch dependency on both operands.
        addi(4, 0, 3);
        addi(4, 4, -1);
        emit(enc_b(-4, 0, 4, 3'b001));
        addi(22, 0, 42);
        run_program();
    endtask

    task automatic test_jumps;
        int slot, target, call_slot, skip_slot, function_slot, exit_slot;
        clear_program("JAL/JALR, link values, returns, bit zero");
        emit(enc_j(12, 1));
        addi(20, 0, 999);
        sw(20, 0, 4);
        addi(2, 1, 7);

        slot = words;
        emit(NOP); // Patched to produce an odd JALR address.
        emit(enc_i(0, 3, 0, 4, 7'h67));
        addi(20, 0, 998);
        sw(20, 0, 4);
        target = words * 4;
        image[slot] = enc_i(target + 1, 0, 0, 3, 7'h13);
        addi(5, 4, 9);

        lw(6, 0, 320);
        emit(enc_i(0, 6, 0, 7, 7'h67));
        addi(20, 0, 997);
        sw(20, 0, 4);
        seed_memory[80] = 32'(words * 4 + 1);
        addi(8, 7, 11);

        slot = words;
        emit(NOP);
        emit(enc_i(4, 9, 0, 9, 7'h67)); // rd==rs1: target uses the old operand.
        addi(20, 0, 996);
        sw(20, 0, 4);
        image[slot] = enc_i(words * 4 - 3, 0, 0, 9, 7'h13);
        addi(15, 9, 1);

        call_slot = words;
        emit(NOP);
        addi(11, 10, 1);
        skip_slot = words;
        emit(NOP);
        addi(20, 0, 995);
        sw(20, 0, 4);
        function_slot = words;
        addi(12, 0, 55);
        emit(enc_i(0, 10, 0, 0, 7'h67));
        addi(20, 0, 994);
        sw(20, 0, 4);
        exit_slot = words;
        addi(13, 0, 66);
        image[call_slot] = enc_j((function_slot - call_slot) * 4, 10);
        image[skip_slot] = enc_j((exit_slot - skip_slot) * 4, 0);

        addi(14, 0, 2);
        addi(14, 14, -1);
        emit(enc_b(8, 0, 14, 3'b000));
        emit(enc_j(-8, 0));
        addi(16, 0, 77);
        run_program();
    endtask

    function automatic logic [31:0] next_random;
        random_state ^= random_state << 13;
        random_state ^= random_state >> 17;
        random_state ^= random_state << 5;
        return random_state;
    endfunction

    task automatic test_random(input logic [31:0] seed);
        logic [31:0] bits;
        logic [4:0] rd, rs1, rs2;
        logic [2:0] f3;
        logic [6:0] f7;
        int offset, immediate;
        clear_program($sformatf("deterministic mixed program %08h", seed));
        random_state = seed;
        for (int i = 0; i < 120; i++) begin
            bits = next_random();
            rd = bits[4:0];
            rs1 = bits[9:5];
            rs2 = bits[14:10];
            f3 = bits[17:15];
            f7 = 0;
            if (bits[18] && (f3 == 0 || f3 == 5)) f7 = 7'h20;
            offset = 384 + int'(bits[23:20]) * 4;
            immediate = int'(bits[31:20]) - 2048;
            case (bits[27:25])
                0: emit(enc_r(f7, rs2, rs1, f3, rd));
                1, 2: begin
                    if (f3 == 1) immediate = int'(bits[24:20]);
                    if (f3 == 5) immediate = int'(bits[24:20]) + (bits[18] ? 1024 : 0);
                    emit(enc_i(immediate, rs1, f3, rd, 7'h13));
                end
                3: emit(enc_u(bits[31:12], rd, 7'h37));
                4: emit(enc_u(bits[31:12], rd, 7'h17));
                5: sw(rs2, 0, offset);
                6: lw(rd, 0, offset);
                7: begin
                    lw(rd, 0, offset);
                    emit(enc_r(0, rd, rd, 0, rs2));
                end
                default: emit(NOP);
            endcase
        end
        run_program();
    endtask

    task automatic test_reset_in_flight;
        logic [31:0] saved_regs [0:31];
        logic [31:0] saved_memory [0:255];
        int waited;
        clear_program("reset with pending RF and DM writes");
        addi(1, 0, 99);
        sw(1, 0, 0);
        addi(2, 0, 88);
        load_dut();
        waited = 0;
        @(negedge clk);
        while (!(dut.rf_write_enable && dut.rdW != 0 && dut.dm_write_enable) && waited < 20) begin
            waited++;
            @(negedge clk);
        end
        require(waited < 20, "Could not reach simultaneous pending WB/store for reset test");
        for (int i = 0; i < 32; i++) saved_regs[i] = dut.rfinstance.regs[i];
        for (int i = 0; i < 256; i++) saved_memory[i] = dut.dminstance.memory[i];
        reset = 1'b1;
        repeat (2) begin
            @(posedge clk);
            #1;
            check32(dut.pcF, 0, "Reset PC with instructions in flight");
            require({dut.validD, dut.validE, dut.validM, dut.validW} === 4'b0000,
                "Reset must invalidate all in-flight instructions");
            for (int i = 0; i < 32; i++)
                check32(dut.rfinstance.regs[i], saved_regs[i], "RF write must be suppressed during reset");
            for (int i = 0; i < 256; i++)
                check32(dut.dminstance.memory[i], saved_memory[i], "Store must be suppressed during reset");
        end
        tests_passed++;
        $display("PASS %-32s", test_name);
    endtask

    initial begin
        trace_enabled = $test$plusargs("trace");
        if ($test$plusargs("waves")) begin
            $dumpfile("pipeline_tb.vcd");
            $dumpvars(0, pipeline_tb);
        end
        // Let the IM's initial $readmemh complete before overriding its array.
        #1;
        test_alu();
        test_forwarding();
        test_loads_stores();
        test_no_false_stalls();
        test_branches();
        test_jumps();
        test_random(32'h12345678);
        test_random(32'hc001d00d);
        test_random(32'hdeadbeef);
        test_random(32'h31415926);
        test_reset_in_flight();
        clear_program("execution after reset");
        addi(1, 0, 123);
        sw(1, 0, 16);
        lw(2, 0, 16);
        addi(3, 2, -1);
        run_program();
        $display("\nALL PASS: %0d tests, %0d checks, %0d register writes, %0d stores, %0d load stalls, %0d redirects",
            tests_passed, checks, total_writes, total_stores, total_stalls, total_redirects);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Global timeout");
    end
endmodule
