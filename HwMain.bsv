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
import MultiN::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    Reg#(Bit#(32)) addr <- mkReg(0);
    Vector#(4, Reg#(Bit#(32))) output_cnt <- replicateM(mkReg(0));
    Reg#(Bit#(10)) write_cnt <- mkReg(0);
    Reg#(Bit#(10)) write_target_number <- mkReg(0);

    Reg#(Bit#(2)) write_handle <- mkReg(0);
    
    FIFOLI#(Bit#(2), 5) write_doneQ <- mkFIFOLI;
    MultiOneToFourIfc#(Bit#(144)) hashtableQ <- mkMultiOnetoFour;
    MultiOneToFourIfc#(Bit#(129)) sub_hashtableQ <- mkMultiOnetoFour;
    MultiOneToFourIfc#(Tuple2#(Bit#(1), Bit#(128))) put_wordQ <- mkMultiOnetoFour;
    MultiOneToFourIfc#(Tuple3#(Bit#(1), Bit#(8), Bit#(8))) put_hashQ <- mkMultiOnetoFour;

    FIFOLI#(Tuple2#(Bit#(20), Bit#(32)), 5) write_reqQ <- mkFIFOLI;
    FIFOLI#(Tuple2#(Bit#(20), Bit#(32)), 5) pcie_reqQ <- mkFIFOLI;
    
    Vector#(4, DividedBRAMFIFOIfc#(Bit#(128), 100, 10)) outputQ <- replicateM(mkDividedBRAMFIFO); // 128 x 1000 Size and 10 steps (like FIFOLI)

    FIFO#(Bit#(32)) hashtable_dataQ <- mkFIFO;
    FIFO#(Bit#(16)) hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(1)) sub_hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(32)) sub_hashtable_dataQ <- mkFIFO;
    Reg#(Bit#(3)) hasht_handle <- mkReg(0);
    Reg#(Bit#(3)) sub_hasht_handle <- mkReg(0);

    DeSerializerIfc#(32, 4) deserial_hasht <- mkDeSerializer;
    DeSerializerIfc#(32, 4) deserial_sub_hasht <- mkDeSerializer;
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
        pcie_reqQ.enq(tuple2(a, d));
    endrule

    rule getPCIeData;
        pcie_reqQ.deq;
        Bit#(20) a = tpl_1(pcie_reqQ.first);
        Bit#(32) d = tpl_2(pcie_reqQ.first);

        let off = (a>>2);
        if ( off == 0 ) begin
            file_size <= d;
        end else if (off == 1) begin // Log Data In
            deserial_pcieio.put(d);
        end else if (off == 2) begin // Read Normal Hash Table fromt the DMA
            hashtable_dataQ.enq(d);
        end else if (off == 3) begin // 12
            sub_hashtable_dataQ.enq(d);
        end else begin // write req 15,16,32,48
            write_reqQ.enq(tuple2(off >> 2, d));
        end
    endrule

    /* Send Output To The Host */
    rule recWriteRequest(write_target_number == write_cnt);
        write_reqQ.deq;
        Bit#(32) off = zeroExtend(tpl_1(write_reqQ.first));
        Bit#(10) step = truncate(tpl_2(write_reqQ.first));
        Bit#(2) idx = truncate(off);

        pcie.dmaWriteReq(off * 1000, step); // each 4 module has 1000 x 128 Bits DMA space

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

    /* Get Hash Table Data From The Host */
    rule mergeHashTableData;
        hashtable_dataQ.deq;
        Bit#(32) d = hashtable_dataQ.first;
        if (hasht_handle < 4) begin
            deserial_hasht.put(d);
            hasht_handle <= hasht_handle + 1;
        end else begin
            hashtable_cmdQ.enq(truncate(d));
            hasht_handle <= 0;
        end
    endrule
    rule getHashTableData;
        hashtable_cmdQ.deq;
        Bit#(128) d <- deserial_hasht.get;
        Bit#(16) cmd = hashtable_cmdQ.first;

        /* Need to Change */
        for (Bit#(8) i = 0; i < 16; i = i + 1) begin
            if (d[7:0] == 0) begin
                d = d >> 8;
            end
        end

        Bit#(144) merged = zeroExtend(d);
        merged = merged << 16;
        merged = merged | zeroExtend(cmd);
        hashtableQ.enq(merged);
    endrule

    /* Get Sub Hashtable Data From the Host */
    rule mergeSubHashTableData;
        sub_hashtable_dataQ.deq;
        Bit#(32) d = sub_hashtable_dataQ.first;
        if (sub_hasht_handle < 4) begin
            deserial_sub_hasht.put(d);
            sub_hasht_handle <= sub_hasht_handle + 1;
        end else begin
            sub_hashtable_cmdQ.enq(truncate(d));
            sub_hasht_handle <= 0;
        end
    endrule
    rule getSubHashTableData;
        sub_hashtable_cmdQ.deq;
        Bit#(128) d <- deserial_sub_hasht.get;
        /* Need to Change */
        for (Bit#(8) i = 0; i < 16; i = i + 1) begin
            if (d[7:0] == 0) begin
                d = d >> 8;
            end
        end
        Bit#(1) cmd = sub_hashtable_cmdQ.first;
        Bit#(129) merged = zeroExtend(d);
        merged = merged << 1;
        merged = merged | zeroExtend(cmd);
        sub_hashtableQ.enq(merged);
    endrule


    /* Put HashTable Data */
    for (Bit#(4) i = 0; i < 4; i = i + 1) begin
        rule putHash;
            let d <- hashtableQ.get[i].get;
            detector[i].put_table(d);
        endrule
    end
    /* Put SubHashTable Data */
    for (Bit#(4) i = 0; i < 4; i = i + 1) begin
        rule putSubHash;
            let d <- sub_hashtableQ.get[i].get;
            detector[i].put_sub_table(d);
        endrule
    end

    /* Put 128Bits Log Data To Tokenizer */
    rule toTokenizingBridge; // Maximum word length is 8 (8 bytes)
        Bit#(64) d <- deserial_pcieio.get;
        tokenizer.put(d);
    endrule

    /* Word -> Detector */
    rule getWordFromTokenizer; // Get Hash data From the Tokenizer
        Tuple2#(Bit#(1), Bit#(128)) d <- tokenizer.get_word;
        put_wordQ.enq(d);
    endrule
    for (Bit#(4) i = 0; i < 4; i = i + 1) begin
        rule putWordToDetector;
            Tuple2#(Bit#(1), Bit#(128)) d <- put_wordQ.get[i].get; //Get Word From the Toknizer
            detector[i].put_word(d);
        endrule
    end

    /* Hash -> Detector */
    rule getHashFromTokenizer;
        Tuple3#(Bit#(1), Bit#(8), Bit#(8)) d <- tokenizer.get_hash; //Get Word From the Toknizer
        put_hashQ.enq(d);
    endrule

    for (Bit#(4) i = 0; i < 4; i = i + 1) begin //Put Word to Detector
        rule putWord;
            Tuple3#(Bit#(1), Bit#(8), Bit#(8)) d <- put_hashQ.get[i].get;
            detector[i].put_hash(d);
        endrule
    end

    for (Bit#(4) i = 0; i < 4; i = i + 1) begin
        rule getResult;
            Bit#(128) d <- detector[i].get_result;
            if (i == 3) begin
                $write("%s",d);
            end
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
