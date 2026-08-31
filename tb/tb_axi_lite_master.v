`timescale 1ns/1ps
`include "axi_lite_pkg.v"

module tb_axi_lite_master;

    localparam ADDR_W = 32;
    localparam DATA_W = 32;

    reg clk = 0;
    reg rstn = 0;

    reg               start;
    reg               rw;
    reg  [ADDR_W-1:0] addr;
    reg  [DATA_W-1:0] wdata_cmd;
    wire [DATA_W-1:0] rdata_cmd;
    wire              done;

    wire [ADDR_W-1:0] awaddr;
    wire               awvalid;
    reg                 awready;

    wire [DATA_W-1:0]   wdata;
    wire [DATA_W/8-1:0] wstrb;
    wire                 wvalid;
    reg                   wready;

    reg  [1:0] bresp;
    reg        bvalid;
    wire       bready;

    wire [ADDR_W-1:0] araddr;
    wire               arvalid;
    reg                 arready;

    reg  [DATA_W-1:0] rdata;
    reg  [1:0]        rresp;
    reg               rvalid;
    wire               rready;

    integer errors = 0;

    axi_lite_master #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
        .clk(clk), .rstn(rstn),
        .start(start), .rw(rw), .addr(addr), .wdata(wdata_cmd),
        .rdata(rdata_cmd), .done(done),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .m_wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .m_rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    axi_lite_checker #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) chk (
        .clk(clk), .rstn(rstn),
        .awaddr(awaddr), .awprot(3'b0), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arprot(3'b0), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    always #5 clk = ~clk;

    // waits DELAY cycles after seeing valid before asserting ready/valid
    integer aw_delay, w_delay, ar_delay;
    reg [DATA_W-1:0] mem_word; 

    // AW/W response
    reg [7:0] aw_wait_cnt, w_wait_cnt;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            awready <= 0; aw_wait_cnt <= 0;
        end else begin
            if (awvalid && !awready) begin
                if (aw_wait_cnt >= aw_delay) begin
                    awready <= 1;
                end else begin
                    aw_wait_cnt <= aw_wait_cnt + 1;
                end
            end else begin
                awready <= 0;
                aw_wait_cnt <= 0;
            end
        end
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wready <= 0; w_wait_cnt <= 0;
        end else begin
            if (wvalid && !wready) begin
                if (w_wait_cnt >= w_delay) begin
                    wready <= 1;
                    mem_word <= wdata;
                end else begin
                    w_wait_cnt <= w_wait_cnt + 1;
                end
            end else begin
                wready <= 0;
                w_wait_cnt <= 0;
            end
        end
    end

    // B response: fire one cycle after both aw/w handshakes have been seen
    reg aw_seen, w_seen;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            aw_seen <= 0; w_seen <= 0; bvalid <= 0; bresp <= 0;
        end else begin
            if (awvalid && awready) aw_seen <= 1;
            if (wvalid  && wready)  w_seen  <= 1;
            if (aw_seen && w_seen && !bvalid) begin
                bvalid <= 1;
                bresp  <= `RESP_OKAY;
            end else if (bvalid && bready) begin
                bvalid  <= 0;
                aw_seen <= 0;
                w_seen  <= 0;
            end
        end
    end

    // AR/R response
    reg [7:0] ar_wait_cnt;
    reg ar_seen;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            arready <= 0; ar_wait_cnt <= 0; ar_seen <= 0; rvalid <= 0; rresp <= 0; rdata <= 0;
        end else begin
            if (arvalid && !arready && !ar_seen) begin
                if (ar_wait_cnt >= ar_delay) begin
                    arready <= 1;
                    ar_seen <= 1;
                end else begin
                    ar_wait_cnt <= ar_wait_cnt + 1;
                end
            end else begin
                arready <= 0;
            end

            if (ar_seen && !rvalid) begin
                rdata  <= mem_word;
                rresp  <= `RESP_OKAY;
                rvalid <= 1;
            end else if (rvalid && rready) begin
                rvalid  <= 0;
                ar_seen <= 0;
                ar_wait_cnt <= 0;
            end
        end
    end


    task do_cmd(input rw_in, input [ADDR_W-1:0] a, input [DATA_W-1:0] d);
        begin
            @(negedge clk);
            rw = rw_in; addr = a; wdata_cmd = d;
            start = 1;
            @(negedge clk);
            start = 0;
            while (!done) @(posedge clk);
            @(negedge clk); // let done's one-cycle pulse pass
        end
    endtask

    task check(input cond, input [511:0] msg);
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                errors = errors + 1;
            end else begin
                $display("pass: %0s", msg);
            end
        end
    endtask

    initial begin
        start = 0; rw = 0; addr = 0; wdata_cmd = 0;
        aw_delay = 0; w_delay = 0; ar_delay = 0;

        @(negedge clk); rstn = 1;

        // 1. zero-latency write then read back
        do_cmd(0, 32'h00, 32'hDEAD_BEEF);
        check(1, "zero-latency write completed (done pulsed)");
        do_cmd(1, 32'h00, 32'h0);
        check(rdata_cmd == 32'hDEAD_BEEF, "zero-latency read got back what was written");

        // 2. slave inserts wait states on every channel
        aw_delay = 3; w_delay = 5; ar_delay = 4;
        do_cmd(0, 32'h04, 32'hCAFEF00D);
        do_cmd(1, 32'h04, 32'h0);
        check(rdata_cmd == 32'hCAFEF00D, "read-back correct even with wait states on every channel");

        // 3. back-to-back commands, no gap, delays still active
        do_cmd(0, 32'h08, 32'h1111_1111);
        do_cmd(0, 32'h08, 32'h2222_2222);
        do_cmd(1, 32'h08, 32'h0);
        check(rdata_cmd == 32'h2222_2222, "back-to-back writes under wait states, last one wins");

        // 4. no delay again, several transactions in a row
        aw_delay = 0; w_delay = 0; ar_delay = 0;
        do_cmd(0, 32'h0C, 32'hAAAA_1234);
        do_cmd(1, 32'h0C, 32'h0);
        check(rdata_cmd == 32'hAAAA_1234, "back to zero-latency after wait-state test");

        $display("");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        chk.report_summary;
        $finish;
    end

endmodule
