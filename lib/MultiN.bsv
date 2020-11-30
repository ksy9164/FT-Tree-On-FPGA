/* This module scatters same data to each output FIFO */

package MultiN;
import FIFO::*;
import Vector::*;
import FIFOLI::*;

interface GetIfc#(type t);
    method ActionValue#(t) get;
endinterface

interface MultiOneToFourIfc#(type t);
    method Action enq(t d);
    interface Vector#(4, GetIfc#(t)) get;
endinterface

module mkMultiOnetoFour (MultiOneToFourIfc#(t))
    provisos (
        Bits#(t , a__)
    );
    FIFO#(t) inQ <- mkFIFO;
    Vector#(4, FIFOLI#(t, 3)) outQ <- replicateM(mkFIFOLI);
    Vector#(2, FIFO#(t)) tempQ <- replicateM(mkFIFO);

    rule ontToTwo;
        inQ.deq;
        t d = inQ.first;
        tempQ[0].enq(d);
        tempQ[1].enq(d);
    endrule

    for (Bit#(4) i = 0; i < 2; i = i + 1) begin
        rule twoToFour;
            tempQ[i].deq;
            t d = tempQ[i].first;
            outQ[i * 2].enq(d);
            outQ[i * 2 + 1].enq(d);
        endrule
    end

    Vector#(4, GetIfc#(t)) get_;
    for (Integer i = 0; i < 4; i = i+1) begin
        get_[i] = interface GetIfc;
            method ActionValue#(t) get;
                outQ[i].deq;
                return outQ[i].first;
            endmethod
        endinterface;
    end
    interface get = get_;

    method Action enq(t d);
        inQ.enq(d);
    endmethod

endmodule

endpackage: MultiN
