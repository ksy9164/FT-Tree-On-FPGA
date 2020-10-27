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

interface HwMainIfc;
endinterface

typedef 128 TOKEN_SIZE;
typedef 256 TABLE_SIZE;
typedef 8 HASH_SIZE;

module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);

    DeSerializerIfc#(32, 2) deserial_pcieio <- mkDeSerializer;
    TokenizerIfc tokenizer <- mkTokenizer;
    BramCtlIfc#(TOKEN_SIZE, TABLE_SIZE, HASH_SIZE) brams <- mkBramCtl;

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

    rule doTokenizing; // Maximum word length is 8 (8 bytes)
        Bit#(64) d <- deserial_pcieio.get;
        tokenizer.put(d);
    endrule

    rule sendToHost;
        Tuple3#(Bit#(1), Bit#(32), Bit#(32)) d <- tokenizer.get;
        let r <- pcie.dataReq;
        let a = r.addr;
        let offset = (a>>2);

        // for preventing compiler optimize out
        if (offset == 0) begin
            pcie.dataSend(r, tpl_2(d) | zeroExtend(tpl_1(d)));
        end else begin
            pcie.dataSend(r, tpl_3(d) | zeroExtend(tpl_1(d)));
        end
    endrule
endmodule
