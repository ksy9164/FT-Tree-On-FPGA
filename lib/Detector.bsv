package Detector;
import FIFO::*;
import Vector::*;

import BramCtl::*;
import FIFOLI::*;

interface DetectorIfc;
    method Action put_hash(Tuple3#(Bit#(1), Bit#(8), Bit#(8)) hash);
    method Action put_word(Bit#(128) word);
    method ActionValue#(Bit#(1)) get_result;
endinterface

(* synthesize *)
module mkDetector (DetectorIfc);
    Vector#(2, BramCtlIfc#(138, 256, 8)) bram_main <- replicateM(mkBramCtl); // (128 + 8 + 2) x 256 Size BRAM
    Vector#(2, BramCtlIfc#(129, 256, 8)) bram_sub <- replicateM(mkBramCtl); // (128 + 1) x 256 Size BRAM

    Vector#(2, FIFO#(Bit#(1))) linespaceQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(2))) compareQ <- replicateM(mkFIFO);
    Vector#(4, FIFOLI#(Bit#(8), 5)) hashQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFOLI#(Bit#(128), 5)) wordQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFOLI#(Bit#(1), 5)) resultQ <- replicateM(mkFIFOLI);

    Vector#(2, Reg#(Bit#(1))) compare_handle <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(2))) sub_flag <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(8))) sub_link <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(256))) answer_table <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(256))) current_line_hit <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(1))) current_status <- replicateM(mkReg(1));

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule readReq;
            hashQ[i].deq;
            Bit#(8) hash = hashQ[i].first;
            bram_main[i].read_req(hash); // Bram read request
            hashQ[i + 2].enq(hash);
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareValue(compare_handle[i] == 0); // Short word
            wordQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(138) d <- bram_main[i].get;
            Bit#(128) table_word = d[137:10];
            Bit#(8) link = d[9:2];
            Bit#(2) flag = d[1:0]; // (Valid, Should/or Not)

            if (word == table_word) begin
                if (link == 0) begin // short word
                    compareQ[i].enq(flag);
                end else begin // long word
                    sub_flag[i] <= flag;
                    sub_link[i] <= link;
                    bram_sub[i].read_req(link);
                    compare_handle[i] <= 1;
                end
            end else begin
                compareQ[i].enq(0);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareLargeValue(compare_handle[i] == 1); // Long word (more than 128bits)
            wordQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(129) d <- bram_sub[i].get;
            Bit#(128) table_word = d[128:1];
            Bit#(2) flag = sub_flag[i];
            Bit#(1) end_detect = d[0];
            if (word == table_word) begin
                if (end_detect == 0) begin
                    compareQ[i].enq(flag);
                    compare_handle[i] <= 0;
                end else begin
                    bram_sub[i].read_req(sub_link[i] + 1);
                    sub_link[i] <= sub_link[i] + 1;
                end
            end else begin
                compareQ[i].enq(0);
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
            Bit#(8) hash = hashQ[i + 2].first;
            Bit#(2) flag = compareQ[i].first;
            Bit#(1) linespace = linespaceQ[i].first;
            Bit#(1) status = current_status[i];

            if (flag == 3) begin // Valid & Should
                current_hit[hash] = 1;
            end else if (flag == 2) begin // Valid & Should Not
                status = 0;
            end

            if (linespace == 1) begin // Line end
                if (current_hit == answer_table[i]) begin
                    resultQ[i].enq(status);
                end else begin
                    resultQ[i].enq(0);
                end
                status = 1; // reset
                current_hit = 0;
            end
            current_status[i] <= status;
            current_line_hit[i] <= current_hit;
        endrule
    end

    method Action put_hash(Tuple3#(Bit#(1), Bit#(8), Bit#(8)) hash);
        linespaceQ[0].enq(tpl_1(hash));
        linespaceQ[1].enq(tpl_1(hash));
        hashQ[0].enq(tpl_2(hash));
        hashQ[1].enq(tpl_3(hash));
    endmethod
    method Action put_word(Bit#(128) word);
        wordQ[0].enq(word);
        wordQ[1].enq(word);
    endmethod
    method ActionValue#(Bit#(1)) get_result;
        resultQ[0].deq;
        resultQ[1].deq;
        return (resultQ[0].first & resultQ[1].first);
    endmethod
endmodule
endpackage
