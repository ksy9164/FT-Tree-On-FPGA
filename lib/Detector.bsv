package Detector;
import FIFO::*;
import Vector::*;

import BramCtl::*;
import FIFOLI::*;

interface DetectorIfc;
    method Action put_hash(Tuple4#(Bit#(1), Bit#(1), Bit#(8), Bit#(8)) hash);
    method Action put_word(Bit#(128) word);
    method Action put_table(Bit#(144) word);
    method Action put_sub_table(Bit#(129) word);
    method ActionValue#(Bit#(128)) get_result;
endinterface

(* synthesize *)
module mkDetector#(Bit#(2) module_id)(DetectorIfc);
    Vector#(2, BramCtlIfc#(138, 256, 8)) bram_main <- replicateM(mkBramCtl); // (128 + 8 + 2) x 256 Size BRAM
    Vector#(2, BramCtlIfc#(129, 256, 8)) bram_sub <- replicateM(mkBramCtl); // (128 + 1) x 256 Size BRAM

    Vector#(3, FIFOLI#(Bit#(1), 7)) linespaceQ <- replicateM(mkFIFOLI);
    Vector#(3, FIFOLI#(Bit#(1), 5)) wordflagQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFO#(Bit#(2))) compareQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(1))) resultQ <- replicateM(mkFIFO);
    Vector#(2, FIFOLI#(Bit#(256), 3)) hit_compareQ <- replicateM(mkFIFOLI);
    Vector#(4, FIFOLI#(Bit#(8), 5)) hashQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFOLI#(Bit#(128), 5)) wordQ <- replicateM(mkFIFOLI);
    FIFO#(Bit#(1)) detectionQ <- mkFIFO;
    FIFOLI#(Bit#(128), 5) outputQ <- mkFIFOLI;
    FIFOLI#(Bit#(128), 5) wordoutQ <- mkFIFOLI;

    Vector#(2, Reg#(Bit#(2))) compare_handle <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(2))) sub_flag <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(8))) sub_link <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(256))) current_line_hit <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(1))) current_status <- replicateM(mkReg(1));
    Reg#(Bit#(256)) answer_table <- mkReg(0);

    Reg#(Bit#(2)) output_handle <- mkReg(0);
    Reg#(Bit#(2)) word_remain_handle <- mkReg(0);
    Reg#(Bit#(1)) template_flag <- mkReg(0);
    Reg#(Bit#(8)) bram_main_addr <- mkReg(0);
    Reg#(Bit#(8)) bram_sub_addr <- mkReg(0);

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
            Bit#(8) link = d[9:2];
            Bit#(2) flag = d[1:0]; // (Valid, Should/or Not)
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
            detectionQ.enq(0);
        end
    endrule

    rule outputCtl(output_handle == 0); // Line end
        detectionQ.deq;
        template_flag <= detectionQ.first;
        output_handle <= 1;
    endrule

    rule outputRule(output_handle == 1); // Normal status
        wordflagQ[2].deq;
        wordoutQ.deq;
        linespaceQ[2].deq;

        Bit#(1) linespace = linespaceQ[2].first;
        Bit#(1) wordflag = wordflagQ[2].first;
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
        wordflagQ[2].deq;
        Bit#(1) wordflag = wordflagQ[2].first;

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
        wordflagQ[2].deq;
        Bit#(1) wordflag = wordflagQ[2].first;

        if(wordflag == 0) begin
            output_handle <= 3;
        end else begin
            output_handle <= 1;
        end

        if (template_flag == 1) begin
            outputQ.enq(wordoutQ.first);
        end
    endrule

    method Action put_hash(Tuple4#(Bit#(1), Bit#(1), Bit#(8), Bit#(8)) hash);
        linespaceQ[0].enq(tpl_1(hash)); // for each table hit
        linespaceQ[1].enq(tpl_1(hash));
        linespaceQ[2].enq(tpl_1(hash)); // for output
        wordflagQ[0].enq(tpl_2(hash));
        wordflagQ[1].enq(tpl_2(hash));
        wordflagQ[2].enq(tpl_2(hash));
        hashQ[0].enq(tpl_3(hash));
        hashQ[1].enq(tpl_4(hash));
    endmethod

    method Action put_table(Bit#(144) word);
        Bit#(138) data = 0;
        data[137:10] = word[143:16];
        case (module_id) // Each different valid bits
            0 : data[9:8] = word[15:14];
            1 : data[9:8] = word[13:12];
            2 : data[9:8] = word[11:10];
            3 : data[9:8] = word[9:8];
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

    method Action put_word(Bit#(128) word);
        wordQ[0].enq(word);
        wordQ[1].enq(word);
        wordoutQ.enq(word);
    endmethod

    method ActionValue#(Bit#(128)) get_result;
        outputQ.deq;
        return (outputQ.first);
    endmethod
endmodule
endpackage
