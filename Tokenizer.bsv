package Tokenizer;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;

interface TokenizerIfc;
    method Action put(Bit#(64) data);
    method ActionValue#(Tuple3#(Bit#(1), Bit#(32), Bit#(32))) get;
endinterface

function Bit#(32) hashorder32char (Bit#(32) d);
    Bit#(32) hashed = 0;
    hashed[6:0] = d[6:0];
    hashed[13:7] = d[14:8];
    hashed[20:14] = d[22:16];
    hashed[27:21] = d[30:24];
    hashed[28] = d[7];
    hashed[29] = d[15];
    hashed[30] = d[23];
    hashed[31] = d[31];
    return hashed;
endfunction
(* synthesize *)
module mkTokenizer (TokenizerIfc);
    FIFO#(Bit#(64)) inputQ <- mkFIFO;
    FIFO#(Vector#(2, Bit#(8))) toTokenizingQ <- mkFIFO;
    FIFO#(Bit#(128)) toHashingQ_1 <- mkFIFO;
    FIFO#(Bit#(64)) toHashingQ_2 <- mkFIFO;
    FIFO#(Bit#(32)) toOutQ <- mkFIFO;
    FIFO#(Bit#(1)) tokenFlagQ <- mkSizedFIFO(4);
    FIFO#(Tuple3#(Bit#(1), Bit#(32), Bit#(32))) outputQ <- mkFIFO; // lineSpace flag & data

    Reg#(Bit#(128)) token_buff <- mkReg(0);
    Reg#(Bit#(1)) token_flag <- mkReg(0);
    Reg#(Bit#(4)) char_cnt <- mkReg(0);

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
            toHashingQ_1.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (d[1] == 32|| d[1] == 10) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= 0;
            char_cnt <= 0;
            if (d[1] == 10)
                token_flag <= token_flag + 1;
            toHashingQ_1.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (cnt == 14) begin // maximum word length is 16
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= 0;
            char_cnt <= 0;
            toHashingQ_1.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            toHashingQ_1.enq(t_buff);
            tokenFlagQ.enq(flag);

        end else begin              // append to Buffer
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= t_buff;
            char_cnt <= cnt + 2;

        end
    endrule

    rule doHashing_1;
        toHashingQ_1.deq;
        Bit#(128) d = toHashingQ_1.first;
        Bit#(32) lower = d[31:0] ^ d[63:32];
        Bit#(32) upper = d[95:64] ^ d[127:96];
        Bit#(64) out = 0;
        out[63:32] = upper;
        out[31:0] = lower;
        toHashingQ_2.enq(out);
    endrule

    rule doHashing_2;
        toHashingQ_2.deq;
        tokenFlagQ.deq;
        Bit#(64) d = toHashingQ_2.first;
        Bit#(32) hashed = d[63:32] ^ d[31:0];
        Bit#(32) seed = 2293;
        outputQ.enq(tuple3(tokenFlagQ.first, hashed, hashed * seed));
    endrule

    method Action put(Bit#(64) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple3#(Bit#(1), Bit#(32), Bit#(32))) get;
        outputQ.deq;
        return outputQ.first;
    endmethod

endmodule
endpackage

