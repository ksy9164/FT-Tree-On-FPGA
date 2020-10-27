package Tokenizer;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;

interface TokenizerIfc;
    method Action put(Bit#(64) data);
    method ActionValue#(Tuple4#(Bit#(1), Bit#(128), Bit#(8), Bit#(8))) get;
endinterface

(* synthesize *)
module mkTokenizer (TokenizerIfc);
    FIFO#(Bit#(64)) inputQ <- mkFIFO;
    FIFO#(Vector#(2, Bit#(8))) toTokenizingQ <- mkFIFO;
    FIFO#(Vector#(2, Bit#(8))) toHashingQ <- mkFIFO;
    FIFO#(Vector#(2, Bit#(8))) toOutQ <- mkFIFO;
    FIFO#(Bit#(128)) wordQ <- mkSizedFIFO(4);
    FIFO#(Bit#(1)) tokenFlagQ <- mkSizedFIFO(4);
    FIFO#(Tuple4#(Bit#(1),Bit#(128), Bit#(8), Bit#(8))) outputQ <- mkFIFO; // lineSpace flag & data

    Reg#(Bit#(128)) token_buff <- mkReg(0);
    Reg#(Bit#(1)) token_flag <- mkReg(0);
    Reg#(Bit#(4)) char_cnt <- mkReg(0);
    Reg#(Bit#(8)) hash_a <- mkReg(0);
    Reg#(Bit#(8)) hash_b <- mkReg(0);

    SerializerIfc#(64, 4) serial_inputQ <- mkSerializer; 

    rule serial16Bits;
        inputQ.deq;
        Bit#(64) d = inputQ.first;
        serial_inputQ.put(d);
    endrule

    rule get16Bits;
        Bit#(16) serialized <- serial_inputQ.get;
        Vector#(2, Bit#(8)) d = replicate(0);

        d[0] = serialized[7:0];
        d[1] = serialized[15:8];

        toTokenizingQ.enq(d);
        toHashingQ.enq(d);
    endrule

    rule doTokenizing;
        toTokenizingQ.deq;
        Vector#(2, Bit#(8)) d = toTokenizingQ.first;
        Bit#(4) cnt = char_cnt;
        Bit#(128) t_buff = token_buff;
        Bit#(1) flag =  token_flag;

        if (d[0] == 32 || d[0] == 10) begin // If it has space or lineSpace
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            if (d[0] == 10)
                token_flag <= token_flag + 1;

            wordQ.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (d[1] == 32|| d[1] == 10) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= 0;
            char_cnt <= 0;
            if (d[1] == 10)
                token_flag <= token_flag + 1;
            wordQ.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (cnt == 14) begin // maximum word length is 16
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= 0;
            char_cnt <= 0;
            wordQ.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            wordQ.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else begin              // append to Buffer
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= t_buff;
            char_cnt <= cnt + 2;

        end
    endrule

    rule doHash;
        toHashingQ.deq;
        Vector#(2, Bit#(8)) d = toHashingQ.first;
        Vector#(2, Bit#(8)) hash = replicate(0);
        hash[0] = hash_a;
        hash[1] = hash_b;

        if (d[0] == 32 || d[0] == 10) begin
            hash_a <= d[1];
            hash_b <= d[1] + 3;
            toOutQ.enq(hash);
        end else if (d[1] == 32|| d[1] == 10) begin
            hash[0] = hash_a ^ d[0];
            hash[1] = hash_b ^ (d[0] + 3);
            hash_a <= 0;
            hash_b <= 0;
            toOutQ.enq(hash);
        end else begin
            hash_a <= hash_a ^ d[0] ^ d[1];
            hash_b <= hash_b ^ (d[0] + 3) ^ (d[1] + 3);
        end
    endrule

    rule out;
        toOutQ.deq;
        wordQ.deq;
        tokenFlagQ.deq;
        outputQ.enq(tuple4(tokenFlagQ.first, wordQ.first, toOutQ.first[0], toOutQ.first[1]));
    endrule
    method Action put(Bit#(64) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple4#(Bit#(1),Bit#(128), Bit#(8), Bit#(8))) get;
        outputQ.deq;
        return outputQ.first;
    endmethod

endmodule
endpackage

