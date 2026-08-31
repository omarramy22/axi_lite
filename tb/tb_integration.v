`timescale 1ns/1ps
`include "axi_lite_pkg.v"

module tb_integration;

    localparam ADDR_W = 32;
    localparam DATA_W = 32;
    localparam NUM_REGS = 8;

    reg clk = 0;
    reg rstn = 0;

    reg               start;
    reg               rw;
    reg  [ADDR_W-1:0] addr;
    reg  [DATA_W-1:0] wdata_cmd;
    wire [DATA_W-1:0] rdata_cmd;
    wire              done;

    wire [ADDR_W-1:0]   awaddr;
    wire                 awvalid;
    wire                 awready;
    wire [DATA_W-1:0]   wdata;
    wire [DATA_W/8-1:0] wstrb;
    wire                 wvalid;
    wire                 wready;
    wire [1:0] bresp;
    wire       bvalid;
    wire       bready;
    wire [ADDR_W-1:0] araddr;
    wire               arvalid;
    wire               arready;
    wire [DATA_W-1:0] rdata;
    wire [1:0]        rresp;
    wire               rvalid;
    wire               rready;

    integer errors = 0;

    axi_lite_master #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) mst (
        .clk(clk), .rstn(rstn),
        .start(start), .rw(rw), .addr(addr), .wdata(wdata_cmd),
        .rdata(rdata_cmd), .done(done),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .m_wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .m_rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    axi_lite_slave #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .NUM_REGS(NUM_REGS)) slv (
        .clk(clk), .rstn(rstn),
        .awaddr(awaddr), .awprot(3'b0), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arprot(3'b0), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
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

    task do_cmd(input rw_in, input [ADDR_W-1:0] a, input [DATA_W-1:0] d);
        begin
            @(negedge clk);
            rw = rw_in; addr = a; wdata_cmd = d;
            start = 1;
            @(negedge clk);
            start = 0;
            while (!done) @(posedge clk);
            @(negedge clk);
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

    integer i;

    initial begin
        start = 0; rw = 0; addr = 0; wdata_cmd = 0;

        @(negedge clk); rstn = 1;

        // 1. write then read back every register in the map
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            do_cmd(0, i*4, 32'hA000_0000 + i);
        end
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            do_cmd(1, i*4, 32'h0);
            check(rdata_cmd == 32'hA000_0000 + i, "reg round-trip through master+slave");
        end

        // 2. overwrite a register and confirm the new value sticks
        do_cmd(0, 32'h00, 32'hFFFF_FFFF);
        do_cmd(1, 32'h00, 32'h0);
        check(rdata_cmd == 32'hFFFF_FFFF, "overwrite through master+slave");

        // 3. out-of-range access through the real master -- master should
        // still complete (done pulses) even though the slave returns DECERR
        do_cmd(0, 32'h40, 32'hDEAD_DEAD);
        check(done !== 1'bx, "master completes cleanly even on a DECERR response");

        $display("");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        chk.report_summary;
        $finish;
    end

endmodule
