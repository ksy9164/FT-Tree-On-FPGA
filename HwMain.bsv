import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;
import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;
import Serializer::*;
import Tokenizer::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);

    DeSerializerIfc#(32, 2) deserial_pcieio <- mkDeSerializer;
    TokenizerIfc tokenizer <- mkTokenizer;

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

        /* For Test */
/*         Bit#(128) temp = tpl_2(d);
 *         Vector#(16, Bit#(8)) vec = replicate(0);
 *         Bit#(5) cnt = 0;
 *
 *         for (Bit#(7) i = 0; i < 16; i = i + 1) begin
 *             vec[i] = temp[(i+1) * 8 - 1 : i * 8];
 *         end
 *
 *         for (Int#(7) i = 15; i >= 0; i = i - 1) begin
 *             if (vec[i] == 0) begin
 *                 cnt = cnt + 1;
 *             end else begin
 *                 $write("%c", vec[i]);
 *             end
 *         end
 *
 *         if (cnt != 0) begin
 *             $display("");
 *         end */

        // for preventing compiler optimize out
        if (offset == 0) begin
            pcie.dataSend(r, tpl_2(d) | zeroExtend(tpl_1(d)));
        end else begin
            pcie.dataSend(r, tpl_3(d) | zeroExtend(tpl_1(d)));
        end
    endrule
endmodule
