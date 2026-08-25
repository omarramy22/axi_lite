// axi_lite_checker.v
// watches an AXI-Lite bus and flags protocol violations, doesn't drive anything. 
`include "axi_lite_pkg.v"

// one of these per channel (aw, w, b, ar, r)
module handshake_check #(
    parameter WIDTH = 32,
    parameter TIMEOUT = 256,
    parameter NAME = "CH"
)(
    input wire             clk,
    input wire             rstn,
    input wire             valid,
    input wire             ready,
    input wire [WIDTH-1:0] data
);

    reg [WIDTH-1:0] data_prev;
    reg [15:0] wait_cnt;
    reg waiting; // valid was high and ready wasn't, last cycle

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_prev <= 0;
            wait_cnt  <= 0;
            waiting   <= 0;
        end else begin
            if (waiting) begin
                if (!valid)
                    $error("[%0t] %0s: valid dropped before handshake", $time, NAME);
                if (data !== data_prev)
                    $error("[%0t] %0s: data changed while valid was pending", $time, NAME);
            end

            if (valid === 1'bx)
                $error("[%0t] %0s: valid is X", $time, NAME);
            if (ready === 1'bx)
                $error("[%0t] %0s: ready is X", $time, NAME);

            if (valid && !ready) begin
                if (wait_cnt >= TIMEOUT)
                    $error("[%0t] %0s: stuck waiting on ready for %0d+ cycles", $time, NAME, TIMEOUT);
                wait_cnt <= wait_cnt + 1;
            end else begin
                wait_cnt <= 0;
            end

            waiting   <= valid && !ready;
            data_prev <= data;
        end
    end

endmodule


module axi_lite_checker #(
    parameter ADDR_W = `ADDR_W,
    parameter DATA_W = `DATA_W,
    parameter TIMEOUT = 256
)(
    input wire clk,
    input wire rstn,

    input wire [ADDR_W-1:0] awaddr,
    input wire [2:0]        awprot,
    input wire               awvalid,
    input wire               awready,

    input wire [DATA_W-1:0]   wdata,
    input wire [DATA_W/8-1:0] wstrb,
    input wire                 wvalid,
    input wire                 wready,

    input wire [1:0] bresp,
    input wire       bvalid,
    input wire       bready,

    input wire [ADDR_W-1:0] araddr,
    input wire [2:0]        arprot,
    input wire               arvalid,
    input wire               arready,

    input wire [DATA_W-1:0] rdata,
    input wire [1:0]        rresp,
    input wire               rvalid,
    input wire               rready
);

    handshake_check #(.WIDTH(ADDR_W+3), .TIMEOUT(TIMEOUT), .NAME("AW"))
        chk_aw (.clk(clk), .rstn(rstn), .valid(awvalid), .ready(awready), .data({awaddr, awprot}));

    handshake_check #(.WIDTH(DATA_W+DATA_W/8), .TIMEOUT(TIMEOUT), .NAME("W"))
        chk_w (.clk(clk), .rstn(rstn), .valid(wvalid), .ready(wready), .data({wdata, wstrb}));

    handshake_check #(.WIDTH(2), .TIMEOUT(TIMEOUT), .NAME("B"))
        chk_b (.clk(clk), .rstn(rstn), .valid(bvalid), .ready(bready), .data(bresp));

    handshake_check #(.WIDTH(ADDR_W+3), .TIMEOUT(TIMEOUT), .NAME("AR"))
        chk_ar (.clk(clk), .rstn(rstn), .valid(arvalid), .ready(arready), .data({araddr, arprot}));

    handshake_check #(.WIDTH(DATA_W+2), .TIMEOUT(TIMEOUT), .NAME("R"))
        chk_r (.clk(clk), .rstn(rstn), .valid(rvalid), .ready(rready), .data({rdata, rresp}));

    // just catch X on the resp codes when they're actually sampled
    always @(posedge clk) begin
        if (rstn && bvalid && bready && ^bresp === 1'bx)
            $error("[%0t] B: bresp is X", $time);
        if (rstn && rvalid && rready && ^rresp === 1'bx)
            $error("[%0t] R: rresp is X", $time);
    end

    // counters for the final report
    integer aw_n, w_n, b_n, ar_n, r_n, slverr_n, decerr_n;

    initial begin
        aw_n = 0; w_n = 0; b_n = 0; ar_n = 0; r_n = 0;
        slverr_n = 0; decerr_n = 0;
    end

    always @(posedge clk) begin
        if (rstn) begin
            if (awvalid && awready) aw_n <= aw_n + 1;
            if (wvalid  && wready)  w_n  <= w_n + 1;
            if (bvalid  && bready) begin
                b_n <= b_n + 1;
                if (bresp == `RESP_SLVERR) slverr_n <= slverr_n + 1;
                if (bresp == `RESP_DECERR) decerr_n <= decerr_n + 1;
            end
            if (arvalid && arready) ar_n <= ar_n + 1;
            if (rvalid  && rready) begin
                r_n <= r_n + 1;
                if (rresp == `RESP_SLVERR) slverr_n <= slverr_n + 1;
                if (rresp == `RESP_DECERR) decerr_n <= decerr_n + 1;
            end
        end
    end

    task report_summary;
        begin
            $display("---- checker summary ----");
            $display("AW: %0d  W: %0d  B: %0d (slverr %0d, decerr %0d)", aw_n, w_n, b_n, slverr_n, decerr_n);
            $display("AR: %0d  R: %0d (slverr %0d, decerr %0d)", ar_n, r_n, slverr_n, decerr_n);
            $display("--------------------------");
        end
    endtask

endmodule