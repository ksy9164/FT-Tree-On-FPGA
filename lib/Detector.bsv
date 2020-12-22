package Detector;
import FIFO::*;
import Vector::*;

import BramCtl::*;
import FIFOLI::*;
import DividedFIFO::*;

interface DetectorIfc;
    method Action put_hash(Tuple3#(Bit#(1), Bit#(8), Bit#(8)) hash);
    method Action put_word(Tuple2#(Bit#(1), Bit#(128)) word);
    method Action put_table(Bit#(152) word);
    method Action put_sub_table(Bit#(129) word);
    method ActionValue#(Bit#(128)) get_result;
endinterface

(* synthesize *)
module mkDetector#(Bit#(3) module_id)(DetectorIfc);
    Vector#(2, BramCtlIfc#(138, 256, 8)) bram_main <- replicateM(mkBramCtl); // (128 + 8 + 2) x 256 Size BRAM
    Vector#(2, BramCtlIfc#(129, 256, 8)) bram_sub <- replicateM(mkBramCtl); // (128 + 1) x 256 Size BRAM

    Vector#(3, DividedFIFOIfc#(Bit#(1), 30, 3)) linespaceQ <- replicateM(mkDividedFIFO);
    Vector#(3, FIFOLI#(Bit#(1), 3)) wordflagQ <- replicateM(mkFIFOLI);
    Vector#(3, FIFOLI#(Bit#(128), 3)) wordQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFO#(Bit#(256))) hit_compareQ <- replicateM(mkFIFO);
    Vector#(4, FIFO#(Bit#(8))) hashQ <- replicateM(mkSizedFIFO(11));
    FIFO#(Bit#(128)) wordoutQ <- mkSizedFIFO(30);
    FIFO#(Bit#(1)) wordflagoutQ <- mkSizedFIFO(30);
    FIFOLI#(Bit#(128), 5) outputQ <- mkFIFOLI;

    FIFO#(Bit#(1)) detectionQ <- mkFIFO;
    Vector#(2, FIFO#(Bit#(1))) resultQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(2))) compareQ <- replicateM(mkFIFO);

    Vector#(2, Reg#(Bit#(2))) compare_handle <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(2))) sub_flag <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(8))) sub_link <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(256))) current_line_hit <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(1))) current_status <- replicateM(mkReg(1));
    Bit#(256) answer_table = 0;
    case (module_id)
        0: begin
            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[236] = 1;
            answer_table[93] = 1;
            answer_table[113] = 1;
            answer_table[103] = 1;
            answer_table[104] = 1;
            answer_table[62] = 1;
            answer_table[197] = 1;
            answer_table[131] = 1;
            answer_table[134] = 1;
            answer_table[172] = 1;
            answer_table[44] = 1;
            answer_table[51] = 1;
            answer_table[84] = 1;
            answer_table[24] = 1;
            answer_table[196] = 1;
            answer_table[4] = 1;
            answer_table[96] = 1;
            answer_table[199] = 1;
            answer_table[80] = 1;
        end
        1: begin
            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[236] = 1;
            answer_table[93] = 1;
            answer_table[79] = 1;
            answer_table[103] = 1;
            answer_table[160] = 1;
            answer_table[104] = 1;
            answer_table[62] = 1;
            answer_table[197] = 1;
            answer_table[145] = 1;
            answer_table[122] = 1;
            answer_table[148] = 1;
            answer_table[40] = 1;
            answer_table[243] = 1;
            answer_table[182] = 1;
            answer_table[87] = 1;
            answer_table[108] = 1;
            answer_table[25] = 1;
            answer_table[64] = 1;
            answer_table[76] = 1;
        end
        2:begin
            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[236] = 1;
            answer_table[93] = 1;
            answer_table[79] = 1;
            answer_table[103] = 1;
            answer_table[104] = 1;
            answer_table[62] = 1;
            answer_table[197] = 1;
            answer_table[131] = 1;
            answer_table[134] = 1;
            answer_table[145] = 1;
            answer_table[172] = 1;
            answer_table[44] = 1;
            answer_table[51] = 1;
            answer_table[84] = 1;
            answer_table[24] = 1;
            answer_table[196] = 1;
            answer_table[4] = 1;
            answer_table[208] = 1;
            answer_table[186] = 1;
            answer_table[64] = 1;
            answer_table[86] = 1;
        end
        3:begin
            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[236] = 1;
            answer_table[121] = 1;
            answer_table[105] = 1;
            answer_table[203] = 1;
            answer_table[153] = 1;
            answer_table[94] = 1;
            answer_table[158] = 1;
            answer_table[164] = 1;
            answer_table[163] = 1;
            answer_table[119] = 1;
            answer_table[19] = 1;
            answer_table[129] = 1;
        end
        4:begin

            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[93] = 1;
            answer_table[54] = 1;
            answer_table[103] = 1;
            answer_table[147] = 1;
            answer_table[63] = 1;
            answer_table[238] = 1;
            answer_table[152] = 1;
            answer_table[228] = 1;
        end
        5:begin

            answer_table[98] = 1;
            answer_table[135] = 1;
            answer_table[93] = 1;
            answer_table[5] = 1;
            answer_table[194] = 1;
            answer_table[54] = 1;
            answer_table[103] = 1;
            answer_table[160] = 1;
            answer_table[149] = 1;
            answer_table[254] = 1;
            answer_table[15] = 1;
            answer_table[229] = 1;
            answer_table[123] = 1;
            answer_table[109] = 1;
            answer_table[230] = 1;
            answer_table[127] = 1;
            answer_table[202] = 1;
            answer_table[187] = 1;
            answer_table[169] = 1;
            answer_table[85] = 1;
        end
        6:begin
            answer_table[98] = 1;
            answer_table[93] = 1;
            answer_table[114] = 1;
            answer_table[35] = 1;
            answer_table[213] = 1;
            answer_table[200] = 1;
            answer_table[162] = 1;
            answer_table[219] = 1;
            answer_table[49] = 1;
            answer_table[67] = 1;
            answer_table[156] = 1;
            answer_table[151] = 1;
            answer_table[36] = 1;
            answer_table[75] = 1;
            answer_table[22] = 1;
        end
        7:begin
            answer_table[93] = 1;
            answer_table[105] = 1;
            answer_table[143] = 1;
            answer_table[206] = 1;
            answer_table[226] = 1;
            answer_table[52] = 1;
            answer_table[112] = 1;
            answer_table[162] = 1;
            answer_table[6] = 1;
            answer_table[246] = 1;
            answer_table[73] = 1;
            answer_table[216] = 1;
            answer_table[50] = 1;
            answer_table[251] = 1;
            answer_table[30] = 1;
            answer_table[101] = 1;
        end
    endcase

    Reg#(Bit#(2)) output_handle <- mkReg(0);
    Reg#(Bit#(2)) word_remain_handle <- mkReg(0);
    Reg#(Bit#(1)) template_flag <- mkReg(0);
    Reg#(Bit#(8)) bram_main_addr <- mkReg(0);
    Reg#(Bit#(8)) bram_sub_addr <- mkReg(1);

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule readReq;
            hashQ[i].deq;
            Bit#(8) hash = hashQ[i].first;
            bram_main[i].read_req(hash); // BRAM read request
            hashQ[i + 2].enq(hash);
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareValue(compare_handle[i] == 0); // Short word
            wordQ[i].deq;
            wordflagQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(138) d <- bram_main[i].get;
            Bit#(128) table_word = d[137:10];
            Bit#(8) link = d[7:0];
            Bit#(2) flag = d[9:8]; // (Valid, Should/or Not)
            Bit#(1) wordflag = wordflagQ[i].first;

            if (word == table_word) begin // Word matching
                if (wordflag == 1) begin // short word
                    compareQ[i].enq(flag);
                end else begin // long word
                    sub_flag[i] <= flag;
                    sub_link[i] <= link;
                    bram_sub[i].read_req(link);
                    compare_handle[i] <= 1;
                end
            end else if (wordflag == 1)begin // Word unmatching
                compareQ[i].enq(0);
            end else begin // Word enmatching and remains
                compareQ[i].enq(0);
                compare_handle[i] <= 2;
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareLargeValue(compare_handle[i] == 1); // Long word (more than 128bits)
            wordQ[i].deq;
            wordflagQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(129) d <- bram_sub[i].get;
            Bit#(128) table_word = d[128:1];
            Bit#(2) flag = sub_flag[i];
            Bit#(1) end_detect = d[0];
            Bit#(1) wordflag = wordflagQ[i].first;
            if (word == table_word) begin
                if (end_detect == 0) begin
                    if (wordflag == 0) begin // word remains
                        compare_handle[i] <= 2;
                        compareQ[i].enq(0);
                    end else begin
                        compare_handle[i] <= 0;
                        compareQ[i].enq(flag);
                    end
                end else if(wordflag == 0)begin
                    bram_sub[i].read_req(sub_link[i] + 1);
                    sub_link[i] <= sub_link[i] + 1;
                end else begin
                    compare_handle[i] <= 2;
                    compareQ[i].enq(0);
                end
            end else begin
                compareQ[i].enq(0);
                if (wordflag == 0) begin // word remains
                    compare_handle[i] <= 2;
                end else begin
                    compare_handle[i] <= 0;
                end
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule wordRemainFlush(compare_handle[i] == 2); // Flush (more than 128bits)
            wordQ[i].deq;
            wordflagQ[i].deq;
            Bit#(1) wordflag = wordflagQ[i].first;
            if (wordflag == 1) begin
                compare_handle[i] <= 0;
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule detectTemplate;
            hashQ[i + 2].deq;
            compareQ[i].deq;
            linespaceQ[i].deq;
            Bit#(256) current_hit = current_line_hit[i];
            Bit#(8) hash = hashQ[i + 2].first; // For matching template
            Bit#(2) flag = compareQ[i].first; // Valid/Should
            Bit#(1) linespace = linespaceQ[i].first;
            Bit#(1) status = current_status[i];

            if (flag == 3) begin // Valid & Should
                current_hit[hash] = 1;
            end else if (flag == 2) begin // Valid & Should Not
                status = 0;
            end

            if (linespace == 1) begin // Line end
                hit_compareQ[i].enq(current_hit);
                resultQ[i].enq(status);
                status = 1; // reset
                current_hit = 0;
            end
            current_status[i] <= status;
            current_line_hit[i] <= current_hit;
        endrule
    end
    
    rule templateDetection;
        resultQ[0].deq;
        resultQ[1].deq;
        hit_compareQ[0].deq;
        hit_compareQ[1].deq;
        Bit#(256) answer = hit_compareQ[0].first | hit_compareQ[1].first;
        if(answer == answer_table) begin
            detectionQ.enq(resultQ[0].first & resultQ[1].first);
        end else begin
            $display("No !!");
            detectionQ.enq(0);
        end
    endrule

    rule outputCtl(output_handle == 0); // Line end
        detectionQ.deq;
        template_flag <= detectionQ.first;
        output_handle <= 1;
        if (template_flag == 1) begin
            outputQ.enq(10);
        end
    endrule

    rule outputRule(output_handle == 1); // Normal status
        wordflagoutQ.deq;
        wordoutQ.deq;
        linespaceQ[2].deq;

        Bit#(1) linespace = linespaceQ[2].first;
        Bit#(1) wordflag = wordflagoutQ.first;
        if (linespace == 1 && wordflag == 1) begin
            output_handle <= 0;
        end else if (linespace == 1 && wordflag == 0) begin
            output_handle <= 2;
        end else if (wordflag == 0) begin
            output_handle <= 3;
        end

        if (template_flag == 1) begin
            outputQ.enq(wordoutQ.first);
        end
    endrule

    rule wordRemainLineEnd(output_handle == 2); // line end & word remains
        wordoutQ.deq;
        wordflagoutQ.deq;
        Bit#(1) wordflag = wordflagoutQ.first;

        if(wordflag == 0) begin
            output_handle <= 2;
        end else begin
            output_handle <= 1;
            detectionQ.deq;
            template_flag <= detectionQ.first;
        end

        if (template_flag == 1) begin
            outputQ.enq(wordoutQ.first);
        end
    endrule

    rule wordRemain(output_handle == 3); //word remains
        wordoutQ.deq;
        wordflagoutQ.deq;
        Bit#(1) wordflag = wordflagoutQ.first;

        if(wordflag == 0) begin
            output_handle <= 3;
        end else begin
            output_handle <= 1;
        end

        if (template_flag == 1) begin
            outputQ.enq(wordoutQ.first);
        end
    endrule

    rule wordFlagOut;
        wordflagQ[2].deq;
        wordflagoutQ.enq(wordflagQ[2].first);
    endrule

    rule wordOut;
        wordQ[2].deq;
        wordoutQ.enq(wordQ[2].first);
    endrule

    method Action put_hash(Tuple3#(Bit#(1), Bit#(8), Bit#(8)) hash);
        linespaceQ[0].enq(tpl_1(hash));
        linespaceQ[1].enq(tpl_1(hash));
        linespaceQ[2].enq(tpl_1(hash));
        hashQ[0].enq(tpl_2(hash));
        hashQ[1].enq(tpl_3(hash));
    endmethod

    method Action put_table(Bit#(152) word);
        Bit#(138) data = 0;
        data[137:10] = word[151:24];
        case (module_id) // Each different valid bits
            0 : data[9:8] = word[23:22];
            1 : data[9:8] = word[21:20];
            2 : data[9:8] = word[19:18];
            3 : data[9:8] = word[17:16];
            4 : data[9:8] = word[15:14];
            5 : data[9:8] = word[13:12];
            6 : data[9:8] = word[11:10];
            7 : data[9:8] = word[9:8];
        endcase
        data[7:0] = word[7:0];
        bram_main[0].write_req(bram_main_addr ,data);
        bram_main[1].write_req(bram_main_addr ,data);
        bram_main_addr <= bram_main_addr + 1;
    endmethod

    method Action put_sub_table(Bit#(129) word);
        bram_sub[0].write_req(bram_sub_addr, word);
        bram_sub[1].write_req(bram_sub_addr, word);
        bram_sub_addr <= bram_sub_addr + 1;
    endmethod

    method Action put_word(Tuple2#(Bit#(1), Bit#(128)) word);
        wordflagQ[0].enq(tpl_1(word));
        wordflagQ[1].enq(tpl_1(word));
        wordflagQ[2].enq(tpl_1(word));
        wordQ[0].enq(tpl_2(word));
        wordQ[1].enq(tpl_2(word));
        wordQ[2].enq(tpl_2(word));
    endmethod

    method ActionValue#(Bit#(128)) get_result;
        outputQ.deq;
        return (outputQ.first);
    endmethod
endmodule
endpackage
