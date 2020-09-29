import Clocks :: *;
import DefaultValue :: *;
import Xilinx :: *;
import XilinxCells :: *;

import PcieImport :: *;
import PcieCtrl :: *;
import PcieCtrl_bsim :: *;

import Clocks :: *;
import FIFO :: *;

import HwMain::*;

interface TopIfc;
    (* always_ready *)
    interface PcieImportPins pcie_pins;
    (* always_ready *)
    method Bit#(4) led;
endinterface

(* no_default_clock, no_default_reset *)
module mkProjectTop#(
    Clock pcie_clk_p, Clock pcie_clk_n, Clock emcclk,
    Clock sys_clk_p, Clock sys_clk_n,
    Reset pcie_rst_n
    ) (TopIfc);

    PcieImportIfc pcie <- mkPcieImport(pcie_clk_p, pcie_clk_n, pcie_rst_n, emcclk);
    PcieCtrlIfc pcieCtrl <- mkPcieCtrl(pcie.user, clocked_by pcie.user_clk, reset_by pcie.user_reset);

    interface PcieImportPins pcie_pins = pcie.pins;

    method Bit#(4) led;
        return 0;
    endmethod
endmodule

module mkProjectTop_bsim (Empty);
    Clock curclk <- exposeCurrentClock;

    PcieCtrlIfc pcieCtrl <- mkPcieCtrl_bsim;

    HwMainIfc hwmain <- mkHwMain(pcieCtrl.user);
endmodule
