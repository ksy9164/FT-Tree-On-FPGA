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

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    Reg#(Bit#(8)) addr <- mkReg(0);

    DeSerializerIfc#(32, 2) deserial_pcieio <- mkDeSerializer;
    TokenizerIfc tokenizer <- mkTokenizer;
    DetectorIfc detector <- mkDetector;

    rule getDataFromHost;
        let w <- pcie.dataReceive;
        let a = w.addr;
        let d = w.data;

        let off = (a>>2);
        if ( off == 0 ) begin
            file_size <= d;
        end else if (off == 1) begin
            deserial_pcieio.put(d);
        end else begin
            $display("PCIe offset error!");
        end
    endrule

    rule toTokenizingBridge; // Maximum word length is 8 (8 bytes)
        Bit#(64) d <- deserial_pcieio.get;
        tokenizer.put(d);
    endrule

    rule putHashToDetectorBridge;
        Tuple3#(Bit#(1), Bit#(8), Bit#(8)) d <- tokenizer.get_hash;
        detector.put_hash(d);
    endrule

    rule putWordToDetector;
        Bit#(128) d <- tokenizer.get_word;
        detector.put_word(d);
    endrule

    rule getResultSendToHost;
        Bit#(1) d <- detector.get_result;
        let r <- pcie.dataReq;
        let a = r.addr;
        let offset = (a>>2);

        // for preventing compiler optimize out
        if (offset == 0) begin
            pcie.dataSend(r, zeroExtend(d));
        end else begin
            pcie.dataSend(r, zeroExtend(d));
        end
    endrule
endmodule
