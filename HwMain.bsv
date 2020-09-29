import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;

import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;

interface HwMainIfc;
endinterface


module mkHwMain#(PcieUserIfc pcie) 
    (HwMainIfc);
    Reg#(Bit#(32)) file_size <- mkReg(0);
    FIFO#(Bit#(32)) inputQ <- mkFIFO;

    rule getDataFromHost;
        let w <- pcie.dataReceive;
        let a = w.addr;
        let d = w.data;

        let off = (a>>2);
        if ( off == 0 ) begin
            file_size <= d;
        end else if (off == 1) begin
            inputQ.enq(d);
        end else begin
            $display("PCIe offset error!");
        end
    endrule

    rule dividingData;
        inputQ.deq;
        let d = inputQ.first;
        $display("%d", d[7:0]);
        $display("%d", d[15:8]);
        $display("%d", d[23:16]);
        $display("%d", d[31:24]);
    endrule
endmodule
