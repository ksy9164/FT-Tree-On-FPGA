import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;
import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;
import Serializer::*;
import Tokenizer::*;
import BramCtl::*;
import Detector::*;
import FIFOLI::*;
import DividedFIFO::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    Reg#(Bit#(32)) addr <- mkReg(0);
    /* Vector#(4, Reg#(Bit#(32))) dma_addr <- replicateM(mkReg(0)); */
    Vector#(4, Reg#(Bit#(32))) output_cnt <- replicateM(mkReg(0));
    Reg#(Bit#(10)) write_cnt <- mkReg(0);
    Reg#(Bit#(10)) write_target_number <- mkReg(0);
    Reg#(Bit#(10)) wordReadLeft <- mkReg(0);
    FIFO#(Bit#(2)) dma_handleQ <- mkFIFO;
    Reg#(Bit#(2)) dma_handle <- mkReg(0);

    Reg#(Bit#(144)) hash_table_data <- mkReg(0);
    Reg#(Bit#(129)) sub_hash_table_data <- mkReg(0);
    Reg#(Bit#(1)) table_merge_handle <- mkReg(0);
    Reg#(Bit#(2)) write_handle <- mkReg(0);
    Reg#(Bit#(1)) sub_table_merge_handle <- mkReg(0);
    
    FIFOLI#(Bit#(2), 5) write_doneQ <- mkFIFOLI;
    FIFOLI#(Bit#(144), 5) hashtableQ <- mkFIFOLI;
    FIFOLI#(Bit#(129), 5) sub_hashtableQ <- mkFIFOLI;

    Vector#(2, FIFO#(Bit#(144)))  put_hashQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(129)))  put_sub_hashQ <- replicateM(mkFIFO);

    FIFOLI#(Tuple2#(Bit#(20), Bit#(32)), 5) write_reqQ <- mkFIFOLI;
    
    Vector#(4, DividedBRAMFIFOIfc#(Bit#(128), 100, 5)) outputQ <- replicateM(mkDividedBRAMFIFO); // 128 x 50 Size and 5 steps (like FIFOLI)

    DeSerializerIfc#(32, 2) deserial_pcieio <- mkDeSerializer;
    TokenizerIfc tokenizer <- mkTokenizer;
    Vector#(4, DetectorIfc) detector;
    detector[0] <- mkDetector(0);
    detector[1] <- mkDetector(1);
    detector[2] <- mkDetector(2);
    detector[3] <- mkDetector(3);

    rule getDataFromHost;
        let w <- pcie.dataReceive;
        let a = w.addr;
        let d = w.data;

        let off = (a>>2);
        if ( off == 0 ) begin
            file_size <= d;
        end else if (off == 1) begin // Log Data In
            deserial_pcieio.put(d);
        end else if (off == 2) begin // Read Normal Hash Table fromt the DMA
            dma_handleQ.enq(1);
        end else if (off == 3) begin // 12
            dma_handleQ.enq(2);
        end else begin // write req 15,16,17,18
            write_reqQ.enq(tuple2(off >> 2, d));
        end
    endrule

    rule dmaReadRequest(wordReadLeft == 0);
        dma_handleQ.deq;
        Bit#(2) handle = dma_handleQ.first;
        case (handle)
            1 : pcie.dmaReadReq(0, 512); 
            2 : pcie.dmaReadReq(1000, 512); 
        endcase
        wordReadLeft <= 512;
        dma_handle <= handle;
    endrule

    rule recWriteRequest(write_target_number == write_cnt);
        write_reqQ.deq;
        Bit#(32) off = zeroExtend(tpl_1(write_reqQ.first));
        Bit#(10) step = truncate(tpl_2(write_reqQ.first));
        Bit#(2) idx = truncate(off);

        pcie.dmaWriteReq(off * 100, step); // each 4 module has 100 x 128 Bits DMA space

        write_target_number <= step;
        write_handle <= idx;
    endrule

    rule writeDMA(write_target_number != write_cnt);
        Bit#(2) idx = write_handle;
        outputQ[idx].deq;
        Bit#(128) d = outputQ[idx].first;
        pcie.dmaWriteData(d);
        if (write_target_number == write_cnt - 1) begin
            write_cnt <= 0;
            write_target_number <= 0;
            write_doneQ.enq(idx);
        end else begin
            write_cnt <= write_cnt + 1;
        end
    endrule

    rule recvHashTable(wordReadLeft != 0 && dma_handle == 1); // receive HashTable from the HOST
        DMAWord rd <- pcie.dmaReadWord;
        Bit#(1) handle = table_merge_handle;
        Bit#(144) merged = hash_table_data;
        if (handle == 0) begin // 0 => 128Bits word, 1 => 8Bits valbit
            merged[143:16] = rd;
        end else begin
            merged[15:0] = rd[127:112];
            hashtableQ.enq(merged);
        end
        hash_table_data <= merged;
        table_merge_handle <= table_merge_handle + 1;
        wordReadLeft <= wordReadLeft - 1;
    endrule

    rule recvHashSubTable(wordReadLeft != 0 && dma_handle == 2); // receive SubHashTable from the HOST
        DMAWord rd <- pcie.dmaReadWord;
        Bit#(1) handle = sub_table_merge_handle;
        Bit#(129) merged = sub_hash_table_data;
        if (handle == 0) begin // 0 => 128Bits word, 1 => 1Bit valbit
            merged[128:1] = rd;
        end else begin
            if (rd == 0)
                merged[0] = 0;
            else
                merged[0] = 1;
            sub_hashtableQ.enq(merged);
        end
        sub_hash_table_data <= merged;
        sub_table_merge_handle <= sub_table_merge_handle + 1;
        wordReadLeft <= wordReadLeft - 1;
    endrule

    rule getHashFromTheHost;
        hashtableQ.deq;
        put_hashQ[0].enq(hashtableQ.first);
        put_hashQ[1].enq(hashtableQ.first);
    endrule

    for (Bit#(4) i = 0; i < 2; i = i + 1) begin
        rule putHash;
            put_hashQ[i].deq;
            detector[i * 2].put_table(hashtableQ.first);
            detector[i * 2 + 1].put_table(hashtableQ.first);
        endrule
    end

    rule getSubHash;
        sub_hashtableQ.deq;
        put_sub_hashQ[0].enq(sub_hashtableQ.first);
        put_sub_hashQ[1].enq(sub_hashtableQ.first);
    endrule

    for (Bit#(4) i = 0; i < 2; i = i + 1) begin
        rule putSubHash;
            put_sub_hashQ[i].deq;
            detector[i * 2].put_sub_table(sub_hashtableQ.first);
            detector[i * 2 + 1].put_sub_table(sub_hashtableQ.first);
        endrule
    end

    rule toTokenizingBridge; // Maximum word length is 8 (8 bytes)
        Bit#(64) d <- deserial_pcieio.get;
        tokenizer.put(d);
    endrule

    rule putHashToDetectorBridge; // Get Hash data From the Tokenizer
        Tuple4#(Bit#(1), Bit#(1), Bit#(8), Bit#(8)) d <- tokenizer.get_hash;
        for (Bit#(4) i = 0; i < 4; i = i + 1) begin
            detector[i].put_hash(d);
        end
    endrule

    rule putWordToDetector;
        Bit#(128) d <- tokenizer.get_word; //Get Word From the Toknizer
        for (Bit#(4) i = 0; i < 4; i = i + 1) begin
            detector[i].put_word(d);
        end
    endrule

    for (Bit#(4) i = 0; i < 4; i = i + 1) begin
        rule getResult;
            Bit#(128) d <- detector[i].get_result;
            outputQ[i].enq(d);
            output_cnt[i] <= output_cnt[i] + 1;
        endrule
    end

    rule sendResultToHost; 
        Bit#(8) d = 0;
        let r <- pcie.dataReq;
        let a = r.addr;
        let off = (a>>2);
        Bit#(2) idx = truncate(off);
        if (off != 0) begin  // send current output numbers
            pcie.dataSend(r, output_cnt[off]);
        end else begin
            write_doneQ.deq; // DMA writing is done
            pcie.dataSend(r, zeroExtend(write_doneQ.first));
        end
    endrule
endmodule
