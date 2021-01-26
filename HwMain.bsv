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
import SinglePipe::*;
import Merger::*;

import DRAMController::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie, DRAMUserIfc dram) (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    Reg#(Bit#(32)) dramReadCnt <- mkReg(0);
    Reg#(Bit#(32)) dramWriteCnt <- mkReg(0);
    SerializerIfc#(512, 4) serial_dramQ <- mkSerializer; 

    Reg#(Bit#(32)) addr <- mkReg(0);

    FIFOLI#(Bit#(152), 3) hashtableQ <- mkFIFOLI;
    FIFOLI#(Bit#(129), 3) sub_hashtableQ <- mkFIFOLI;
    FIFOLI#(Tuple2#(Bit#(20), Bit#(32)), 2) pcie_reqQ <- mkFIFOLI;

    FIFO#(Bit#(128)) mergeOutQ <- mkSizedBRAMFIFO(512);

    FIFO#(Bit#(32)) hashtable_dataQ <- mkFIFO;
    FIFO#(Bit#(24)) hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(1)) sub_hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(32)) sub_hashtable_dataQ <- mkFIFO;
    Reg#(Bit#(3)) hasht_handle <- mkReg(0);
    Reg#(Bit#(3)) sub_hasht_handle <- mkReg(0);

    DeSerializerIfc#(32, 4) deserial_hasht <- mkDeSerializer;
    DeSerializerIfc#(32, 4) deserial_sub_hasht <- mkDeSerializer;
    DeSerializerIfc#(128, 4) deserial_pcieio <- mkDeSerializer;

    Vector#(3, SinglePipeIfc) pipe <- replicateM(mkSinglePipe);

    FIFO#(Bit#(32)) dmaReadReqQ <- mkFIFO;
    Reg#(Bit#(32)) readCnt <- mkReg(0);
    Reg#(Bit#(32)) readOff <- mkReg(0);

    Reg#(Bit#(3)) merging_out_handle <- mkReg(0);
    Reg#(Bit#(1)) merging_out_flag <- mkReg(0);
    Reg#(Bit#(3)) merging_target <- mkReg(0);

    FIFO#(Bit#(32)) dmaWriteReqQ <- mkFIFO;
    Reg#(Bit#(32)) outputCnt <- mkReg(0);
    Reg#(Bit#(1)) dmaWriteHandle <- mkReg(0);
    Reg#(Bit#(32)) dmaWriteTarget <- mkReg(0);
    Reg#(Bit#(32)) dmaWriteCnt <- mkReg(0);

    Reg#(Bit#(2)) dramToPipeHandle <- mkReg(0);

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
            file_size <= d * 3;
        end else if (off == 1) begin // Log Data In
            dmaReadReqQ.enq(d);
        end else if (off == 2) begin // Read Normal Hash Table fromt the DMA
            hashtable_dataQ.enq(d);
        end else if (off == 3) begin // 12
            sub_hashtable_dataQ.enq(d);
        end else if (off == 4) begin
            dmaWriteReqQ.enq(d);
        end
    endrule

    rule getReadReq(readCnt == 0);
        dmaReadReqQ.deq;
        Bit#(32) cnt = dmaReadReqQ.first;
        pcie.dmaReadReq(16 * readOff, truncate(cnt)); // offset, words
        readCnt <= cnt;
        readOff <= readOff + cnt;
    endrule

    rule getDataFromDMA(readCnt != 0);
        Bit#(128) rd <- pcie.dmaReadWord;
        deserial_pcieio.put(rd);
        readCnt <= readCnt - 1;
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
        Bit#(24) cmd = hashtable_cmdQ.first;

        Bit#(152) merged = zeroExtend(d);
        merged = merged << 24;
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
        Bit#(1) cmd = sub_hashtable_cmdQ.first;
        Bit#(129) merged = zeroExtend(d);
        merged = merged << 1;
        merged = merged | zeroExtend(cmd);
        sub_hashtableQ.enq(merged);
    endrule

    /* Put HashTable Data */
    rule putHash;
        hashtableQ.deq;
        let d = hashtableQ.first;
        pipe[0].putHashTable(d);
        pipe[1].putHashTable(d);
        pipe[2].putHashTable(d);
    endrule

    /* Put SubHashTable Data */
    rule putSubHash;
        sub_hashtableQ.deq;
        let d = sub_hashtableQ.first;
        pipe[0].putSubHashTable(d);
        pipe[1].putSubHashTable(d);
        pipe[2].putSubHashTable(d);
    endrule

///////////////////////////////////////////////////////////////////////////////////////
    /* DRAM CTL & Put data to Single-Pipe */
    rule dramWrite(dramWriteCnt < file_size);
        dramWriteCnt <= dramWriteCnt + 1;
        Bit#(512) d <- deserial_pcieio.get;
        dram.write(zeroExtend(dramWriteCnt)*64, d, 64);
    endrule

    rule dramReadReq(dramWriteCnt >= file_size && dramReadCnt < file_size);
        dramReadCnt <= dramReadCnt + 1;
        dram.readReq(zeroExtend(dramReadCnt)*64, 64);
    endrule

    rule dramRead;
        Bit#(512) d <- dram.read;
        serial_dramQ.put(d);
    endrule

    rule putDecomp;
        Bit#(128) d <- serial_dramQ.get;
        Bit#(2) idx = dramToPipeHandle;
        if (dramToPipeHandle == 2) begin
            dramToPipeHandle <= 0;
        end else begin
            dramToPipeHandle <= dramToPipeHandle + 1;
        end
        pipe[idx].putData(d);
    endrule

    Vector#(8, MergerIfc) outmerger_1 <- replicateM(mkMerger);
    Vector#(8, MergerIfc) outmerger_2 <- replicateM(mkMerger);

    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule merge_step1_1;
            Bit#(128) d <- pipe[0].get[i].get;
            if (d != 0) begin
                outmerger_1[i].enqOne(d);
            end
        endrule
        rule merge_step1_2;
            Bit#(128) d <- pipe[1].get[i].get;
            if (d != 0) begin
                outmerger_1[i].enqTwo(d);
            end
        endrule
    end


    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule merge_step2_1;
            outmerger_1[i].deq;
            Bit#(128) d = outmerger_1[i].first;
            if (d != 0) begin
                outmerger_2[i].enqOne(d);
            end
        endrule
        rule merge_step2_2;
            Bit#(128) d <- pipe[2].get[i].get;
            if (d != 0) begin
                outmerger_2[i].enqTwo(d);
            end
        endrule
    end

/////////////////////Merging outputs and Sending to Host via DMA//////////////////////

    Vector#(4, MergerIfc) merger8to4 <- replicateM(mkMerger);
    Vector#(2, MergerIfc) merger4to2 <- replicateM(mkMerger);
    MergerIfc merger2to1 <- mkMerger;

    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule mergeStep1;
            Bit#(8) id = i / 2;
            outmerger_2[i].deq;
            if (i%2 == 0) begin
                merger8to4[id].enqOne(outmerger_2[i].first);
            end else begin
                merger8to4[id].enqTwo(outmerger_2[i].first);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 4; i = i + 1) begin
        rule mergeStep2;
            Bit#(8) id = i / 2;
            merger8to4[i].deq;
            if (i%2 == 0) begin
                merger4to2[id].enqOne(merger8to4[i].first);
            end else begin
                merger4to2[id].enqTwo(merger8to4[i].first);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule mergeStep3;
            Bit#(8) id = i / 2;
            merger4to2[i].deq;
            if (i%2 == 0) begin
                merger2to1.enqOne(merger4to2[i].first);
            end else begin
                merger2to1.enqTwo(merger4to2[i].first);
            end
        endrule
    end

    rule toMergeQ;
        merger2to1.deq;
        mergeOutQ.enq(merger2to1.first);
        $display("%s",merger2to1.first);
        outputCnt <= outputCnt + 1;
    endrule

    rule getDmaWriteReq(dmaWriteHandle == 0);
        dmaWriteReqQ.deq;
        pcie.dmaWriteReq(0, truncate(dmaWriteReqQ.first));
        dmaWriteHandle <= 1;
        dmaWriteTarget <= dmaWriteReqQ.first;
        dmaWriteCnt <= 0;
    endrule

    rule putDataToDma(dmaWriteHandle != 0);
        mergeOutQ.deq;
        pcie.dmaWriteData(mergeOutQ.first);
        if (dmaWriteCnt + 1 == dmaWriteTarget) begin
            dmaWriteHandle <= 0;
        end else begin
            dmaWriteCnt <= dmaWriteCnt + 1;
        end
    endrule

    rule sendResultToHost; 
        let r <- pcie.dataReq;
        let a = r.addr;
        let offset = (a>>2);

        if (offset == 0) begin
            pcie.dataSend(r, outputCnt);
        end else begin
            pcie.dataSend(r, dmaWriteCnt);
        end
    endrule
endmodule
