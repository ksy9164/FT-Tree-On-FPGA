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

import DRAMController::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie, DRAMUserIfc dram) (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    Reg#(Bit#(32)) dramReadCnt <- mkReg(0);
    Reg#(Bit#(32)) dramWriteCnt <- mkReg(0);
    SerializerIfc#(512, 4) serial_dramQ <- mkSerializer; 

    Reg#(Bit#(32)) addr <- mkReg(0);
    
    FIFO#(Bit#(152)) hashtableQ <- mkFIFO;
    FIFO#(Bit#(129)) sub_hashtableQ <- mkFIFO;
    FIFOLI#(Tuple2#(Bit#(20), Bit#(32)), 5) pcie_reqQ <- mkFIFOLI;
    
    Vector#(8, FIFO#(Bit#(32))) outputQ <- replicateM(mkSizedBRAMFIFO(10000000));
    Vector#(8, SerializerIfc#(128 , 4)) serial_outQ <- replicateM(mkSerializer);

    FIFO#(Bit#(32)) hashtable_dataQ <- mkFIFO;
    FIFO#(Bit#(24)) hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(1)) sub_hashtable_cmdQ <- mkFIFO;
    FIFO#(Bit#(32)) sub_hashtable_dataQ <- mkFIFO;
    Reg#(Bit#(3)) hasht_handle <- mkReg(0);
    Reg#(Bit#(3)) sub_hasht_handle <- mkReg(0);

    DeSerializerIfc#(32, 4) deserial_hasht <- mkDeSerializer;
    DeSerializerIfc#(32, 4) deserial_sub_hasht <- mkDeSerializer;
    DeSerializerIfc#(128, 4) deserial_pcieio <- mkDeSerializer;

    SinglePipeIfc pipe <- mkSinglePipe;

    FIFO#(Bit#(32)) dmaReadReqQ <- mkFIFO;
    Reg#(Bit#(32)) readCnt <- mkReg(0);
    Reg#(Bit#(32)) readOff <- mkReg(0);

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
            dmaReadReqQ.enq(d);
            /* deserial_pcieio.put(d); */
        end else if (off == 2) begin // Read Normal Hash Table fromt the DMA
            hashtable_dataQ.enq(d);
        end else if (off == 3) begin // 12
            sub_hashtable_dataQ.enq(d);
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
        pipe.putHashTable(d);
    endrule

    /* Put SubHashTable Data */
    rule putSubHash;
        sub_hashtableQ.deq;
        let d = sub_hashtableQ.first;
        pipe.putSubHashTable(d);
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
        pipe.putData(d);
    endrule

    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule serialResult;
            Bit#(128) d <- pipe.get[i].get;
            $write("ans %d %s \n",i, d);
            serial_outQ[i].put(d);
        endrule
    end

    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule getResult;
            Bit#(32) d <- serial_outQ[i].get;
            outputQ[i].enq(d);
        endrule
    end

    rule sendResultToHost; 
        Bit#(8) d = 0;
        let r <- pcie.dataReq;
        let a = r.addr;
        let off = (a>>2);
        Bit#(3) idx = truncate(off);
        outputQ[idx].deq;
        pcie.dataSend(r, outputQ[idx].first);
    endrule
endmodule
