package Tokenizer;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;

interface TokenizerIfc;
    method Action put(Bit#(64) data);
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get;
endinterface

(* synthesize *)
module mkTokenizer (TokenizerIfc);
    FIFO#(Bit#(64)) inputQ <- mkFIFO;
    FIFO#(Tuple2#(Bit#(1), Bit#(128))) outputQ <- mkFIFO; // lineSpace flag & data
    FIFO#(Vector#(2, Bit#(8))) toTokenizing <- mkFIFO;

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

        toTokenizing.enq(d);
    endrule

    rule doTokenizing;
        toTokenizing.deq;
        Vector#(2, Bit#(8)) d = toTokenizing.first;
        Bit#(4) cnt = char_cnt;
        Bit#(128) t_buff = token_buff;
        Bit#(1) flag =  token_flag;

        if (d[0] == 32 || d[0] == 10) begin // If it has space or lineSpace
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            if (d[0] == 10)
                token_flag <= token_flag + 1;
            outputQ.enq(tuple2(flag, t_buff));

        end else if (d[1] == 32|| d[1] == 10) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= 0;
            char_cnt <= 0;
            if (d[1] == 10)
                token_flag <= token_flag + 1;
            outputQ.enq(tuple2(flag,t_buff));

        end else if (cnt == 14) begin // maximum word length is 16
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= 0;
            char_cnt <= 0;
            outputQ.enq(tuple2(flag,t_buff));

        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            outputQ.enq(tuple2(flag,t_buff));

        end else begin              // append to Buffer
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= t_buff;
            char_cnt <= cnt + 2;
        end

    endrule

    method Action put(Bit#(64) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get;
        outputQ.deq;
        return outputQ.first;
    endmethod

endmodule
endpackage

