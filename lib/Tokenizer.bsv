package Tokenizer;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;
import FIFOLI::*;

interface TokenizerIfc;
    method Action put(Bit#(64) data);
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get_word;
    method ActionValue#(Tuple3#(Bit#(1), Bit#(8), Bit#(8))) get_hash;
endinterface

function Bit#(8) rand_generator (Bit#(8) old_rand);
    Bit#(8) a = 133;
    Bit#(8) b = 237;
    Bit#(8) c = 255;
	return ((a*old_rand) + b) % c;
endfunction

function Bit#(8) cuckoohash_1 (Bit#(8) idx, Bit#(8) temp);
	return (((idx ^ temp) * (idx + temp)) + idx);
endfunction

function Bit#(8) cuckoohash_2 (Bit#(8) idx, Bit#(8) temp);
	Bit#(8) rd = rand_generator(idx);
	return ((idx ^ (temp + rd)) * rd);
endfunction

(* synthesize *)
module mkTokenizer (TokenizerIfc);
    FIFOLI#(Bit#(64), 5) inputQ <- mkFIFOLI;
    FIFO#(Vector#(2, Bit#(8))) toTokenizingQ <- mkFIFO;
    FIFO#(Vector#(2, Bit#(8))) toHashingQ <- mkFIFO;
    FIFOLI#(Vector#(2, Bit#(8)), 5) hashQ <- mkFIFOLI;
    FIFOLI#(Bit#(128), 5) wordQ <- mkFIFOLI;
    FIFOLI#(Bit#(1), 5) linespaceQ <- mkFIFOLI;
    FIFOLI#(Bit#(1), 5) wordendQ <- mkFIFOLI;

    Reg#(Bit#(128)) token_buff <- mkReg(0);
    Reg#(Bit#(4)) char_cnt <- mkReg(0);
    Reg#(Bit#(8)) hash_a <- mkReg(0);
    Reg#(Bit#(8)) hash_b <- mkReg(33);

    Reg#(Bit#(1)) token_handle <- mkReg(0);

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

    rule doTokenizing(token_handle == 0);
        toTokenizingQ.deq;
        Vector#(2, Bit#(8)) d = toTokenizingQ.first;
        Bit#(4) cnt = char_cnt;
        Bit#(128) t_buff = token_buff;

        if (d[0] == 32 || d[0] == 10) begin // If it has space or lineSpace
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            if (d[0] == 10) begin
                linespaceQ.enq(1);
            end else begin
                linespaceQ.enq(0);
            end

            wordendQ.enq(1);
            wordQ.enq(t_buff);

        end else if (d[1] == 32|| d[1] == 10) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= 0;
            char_cnt <= 0;
            if (d[1] == 10) begin
                linespaceQ.enq(1);
            end else begin
                linespaceQ.enq(0);
            end

            wordendQ.enq(1);
            wordQ.enq(t_buff);

        end else if (cnt == 14) begin // maximum word length is 16
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= 0;
            char_cnt <= 0;
            wordQ.enq(t_buff);
            token_handle <= 1;

        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            wordQ.enq(t_buff);
            wordendQ.enq(0);

        end else begin              // append to Buffer
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= t_buff;
            char_cnt <= cnt + 2;

        end
    endrule

    rule bytes16Exception(token_handle == 1);
        Vector#(2, Bit#(8)) d = toTokenizingQ.first;
        if (d[0] == 32 || d[0] == 10) begin
            toTokenizingQ.deq;
            token_buff <= zeroExtend(d[1]);
            wordendQ.enq(1);
            char_cnt <= 1;
            if (d[0] == 10) begin
                linespaceQ.enq(1);
            end else begin
                linespaceQ.enq(0);
            end
        end else begin
            wordendQ.enq(0);
        end
        token_handle <= 0;
    endrule

    rule doHash;
        toHashingQ.deq;
        Vector#(2, Bit#(8)) d = toHashingQ.first;
        Vector#(2, Bit#(8)) hash = replicate(0);
        Bit#(8) rd = 0;
        hash[0] = hash_a;
        hash[1] = hash_b;

        if (d[0] == 32 || d[0] == 10) begin // If d[0] = ' ' or '\n'
			hash_a <= cuckoohash_1(0, d[1]);

			hash_b <= cuckoohash_2(33, d[1]);

            hashQ.enq(hash);
        end else if (d[1] == 32|| d[1] == 10) begin // If d[0] = ' ' or '\n'
			hash[0] = cuckoohash_1(hash[0], d[0]);

			hash[1] = cuckoohash_2(hash[1], d[0]);

            hash_a <= 0;
            hash_b <= 33;

            hashQ.enq(hash);
        end else begin
			hash[0] = cuckoohash_1(hash[0], d[0]);
			hash[0] = cuckoohash_1(hash[0], d[1]);

			hash[1] = cuckoohash_2(hash[1], d[0]);
			hash[1] = cuckoohash_2(hash[1], d[1]);

            hash_a <= hash[0];
            hash_b <= hash[1];
        end
    endrule

    method Action put(Bit#(64) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get_word;
        wordendQ.deq;
        wordQ.deq;
        return tuple2(wordendQ.first, wordQ.first);
    endmethod
    method ActionValue#(Tuple3#(Bit#(1), Bit#(8), Bit#(8))) get_hash;
        hashQ.deq;
        linespaceQ.deq;
        return tuple3(linespaceQ.first, hashQ.first[0], hashQ.first[1]);
    endmethod

endmodule
endpackage
