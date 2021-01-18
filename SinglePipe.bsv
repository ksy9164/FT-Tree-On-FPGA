/* 
 * For log-analyzing 128 Bits/cycle, this module composed of three kinds of modules
 * decompressor -> tokenizer -> detector
 *  */
package SinglePipe;
import FIFO::*;
import Vector::*;

import LZAH::*;
import Serializer::*;
import Tokenizer::*;
import Detector::*;
import FIFOLI::*;
import DividedFIFO::*;
import MultiN::*;

import BRAM::*;
import BRAMFIFO::*;

interface GetIfc;
    method ActionValue#(Bit#(128)) get;
endinterface
interface SinglePipeIfc;
    method Action putHashTable(Bit#(152) data);
    method Action putSubHashTable(Bit#(129) data);
    method Action putData(Bit#(128) data);
    interface Vector#(8, GetIfc) get;
endinterface

(* synthesize *)
module mkSinglePipe(SinglePipeIfc);
    Vector#(2, DetectorIfc) detector <- replicateM(mkDetector);
    LZAHIfc#(128, 10) lzah_decompressor <- mkLZAH128_10;
    Vector#(8 ,TokenizerIfc) tokenizer <- replicateM(mkTokenizer);
    Reg#(Bit#(3)) tokenizer_input_handle <- mkReg(0);
    FIFOLI#(Bit#(2), 2) tokenizerSignalQ <- mkFIFOLI;
    Reg#(Bit#(3)) tokenizer_output_handle <- mkReg(0);
    Reg#(Bit#(3)) tokenizer_hash_handle <- mkReg(0);
    Vector#(8, FIFO#(Bit#(128))) outputQ <- replicateM(mkSizedBRAMFIFO(100)); 
    Vector#(8, Reg#(Bit#(1))) output_merge_handle <- replicateM(mkReg(0));

    rule getDecompAndPutTokenizer;
        lzah_decompressor.deq;
        Bit#(128) d = lzah_decompressor.first;
        if (d[127:120] == 10 || d[127:120] == 0) begin
            tokenizer_input_handle <= tokenizer_input_handle + 1;
        end
        tokenizer[tokenizer_input_handle].put(d);
    endrule

    rule getTokenized;
        Tuple2#(Bit#(2), Bit#(128)) d <- tokenizer[tokenizer_output_handle].get_word;
        Bit#(2) wordflag = tpl_1(d);
        Bit#(128) word = tpl_2(d);
        tokenizerSignalQ.enq(wordflag);
        if (wordflag == 2) begin
            tokenizer_output_handle <= tokenizer_output_handle + 1;
        end
        detector[tokenizer_output_handle % 2].put_word(d);
    endrule

    rule getHash;
        tokenizerSignalQ.deq;
        Bit#(2) flag = tokenizerSignalQ.first;
        if (flag != 0) begin
            Tuple2#(Bit#(8), Bit#(8)) d <- tokenizer[tokenizer_hash_handle].get_hash;
            detector[tokenizer_hash_handle % 2].put_hash(d);
            if (flag == 2) begin
                tokenizer_hash_handle <= tokenizer_hash_handle + 1;
            end
        end
    endrule
    
    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule outputMergingOne;
            Bit#(128) d <- detector[0].get[i].get;
            Bit#(1) check = 0;
            if (d == 10) begin
                output_merge_handle[i] <= output_merge_handle[i] + 1;
            end
            outputQ[i].enq(d);
        endrule

        rule outputMergingTwo;
            Bit#(128) d <- detector[1].get[i].get;
            Bit#(1) check = 0;
            if (d == 10) begin
                output_merge_handle[i] <= output_merge_handle[i] + 1;
            end
            outputQ[i].enq(d);
        endrule
    end

    Vector#(8, GetIfc) get_;
    for (Integer i = 0; i < 8; i = i+1) begin
        get_[i] = interface GetIfc;
            method ActionValue#(Bit#(128)) get;
                outputQ[i].deq;
                return outputQ[i].first;
            endmethod
        endinterface;
    end
    interface get = get_;

    method Action putHashTable(Bit#(152) data);
        detector[0].put_table(data);
        detector[1].put_table(data);
    endmethod
    method Action putSubHashTable(Bit#(129) data);
        detector[0].put_sub_table(data);
        detector[1].put_sub_table(data);
    endmethod
    method Action putData(Bit#(128) data);
        lzah_decompressor.enq(data);
    endmethod
endmodule
endpackage
