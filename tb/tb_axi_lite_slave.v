`timescale 1ns/1ps
`include "axi_lite_pkg.v"

module tb_axi_lite_slave;

    localparam ADDR_W = 32;
    localparam DATA_W = 32;
    localparam NUM_REGS = 8;

    reg clk = 0;
    reg rstn = 0;

    reg  [ADDR_W-1:0] awaddr;
    reg  [2:0]         awprot;
    reg                 awvalid;
    wire                awready;

    reg  [DATA_W-1:0]   wdata;
    reg  [DATA_W/8-1:0] wstrb;
    reg                  wvalid;
    wire                 wready;

    wire [1:0] bresp;
    wire       bvalid;
    reg        bready;

    reg  [ADDR_W-1:0] araddr;
    reg  [2:0]         arprot;
    reg                 arvalid;
    wire                arready;

    wire [DATA_W-1:0] rdata;
    wire [1:0]        rresp;
    wire               rvalid;
    reg                 rready;

    integer errors = 0;

    axi_lite_slave #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .NUM_REGS(NUM_REGS)) dut (
        .clk(clk), .rstn(rstn),
        .awaddr(awaddr), .awprot(awprot), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arprot(arprot), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    axi_lite_checker #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) chk (
        .clk(clk), .rstn(rstn),
        .awaddr(awaddr), .awprot(awprot), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arprot(arprot), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    always #5 clk = ~clk;

    task do_write(input [ADDR_W-1:0] a, input [DATA_W-1:0] d, input [DATA_W/8-1:0] s,
                  output [1:0] resp);
        reg aw_done, w_done;
        begin
            aw_done = 0;
            w_done  = 0;
            @(negedge clk);
            awaddr = a; awvalid = 1;
            wdata  = d; wstrb = s; wvalid = 1;

            while (!(aw_done && w_done)) begin
                @(posedge clk);
                if (awvalid && awready) aw_done = 1;
                if (wvalid  && wready)  w_done  = 1;
                @(negedge clk);
                if (aw_done) awvalid = 0;
                if (w_done)  wvalid  = 0;
            end

            bready = 1;
            while (!bvalid) @(posedge clk);
            resp = bresp;
            @(negedge clk); bready = 0;
        end
    endtask

    // AW asserted first, W held back a few cycles
    task do_write_aw_first(input [ADDR_W-1:0] a, input [DATA_W-1:0] d, input [DATA_W/8-1:0] s,
                            output [1:0] resp);
        begin
            @(negedge clk);
            awaddr = a; awvalid = 1;
            while (!(awvalid && awready)) @(posedge clk);
            @(negedge clk); awvalid = 0;

            repeat (2) @(negedge clk); // let a couple idle cycles pass

            wdata = d; wstrb = s; wvalid = 1;
            while (!(wvalid && wready)) @(posedge clk);
            @(negedge clk); wvalid = 0;

            bready = 1;
            while (!bvalid) @(posedge clk);
            resp = bresp;
            @(negedge clk); bready = 0;
        end
    endtask

    // W asserted first, AW held back a few cycles
    task do_write_w_first(input [ADDR_W-1:0] a, input [DATA_W-1:0] d, input [DATA_W/8-1:0] s,
                           output [1:0] resp);
        begin
            @(negedge clk);
            wdata = d; wstrb = s; wvalid = 1;
            while (!(wvalid && wready)) @(posedge clk);
            @(negedge clk); wvalid = 0;

            repeat (2) @(negedge clk);

            awaddr = a; awvalid = 1;
            while (!(awvalid && awready)) @(posedge clk);
            @(negedge clk); awvalid = 0;

            bready = 1;
            while (!bvalid) @(posedge clk);
            resp = bresp;
            @(negedge clk); bready = 0;
        end
    endtask

    task do_read(input [ADDR_W-1:0] a, output [DATA_W-1:0] d, output [1:0] resp);
        begin
            @(negedge clk);
            araddr = a; arvalid = 1;
            while (!(arvalid && arready)) @(posedge clk);
            @(negedge clk); arvalid = 0;

            rready = 1;
            while (!rvalid) @(posedge clk);
            d    = rdata;
            resp = rresp;
            @(negedge clk); rready = 0;
        end
    endtask

    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                errors = errors + 1;
            end else begin
                $display("pass: %0s", msg);
            end
        end
    endtask


    reg [DATA_W-1:0] rd;
    reg [1:0] resp;

    initial begin
        awaddr=0; awprot=0; awvalid=0;
        wdata=0; wstrb=0; wvalid=0;
        bready=0;
        araddr=0; arprot=0; arvalid=0;
        rready=0;

        @(negedge clk); rstn = 1;

        // 1. basic write then read back, reg 0
        do_write(32'h00, 32'hAAAA_5555, 4'hF, resp);
        check(resp == `RESP_OKAY, "write reg0 -> OKAY");
        do_read(32'h00, rd, resp);
        check(rd == 32'hAAAA_5555 && resp == `RESP_OKAY, "read back reg0");

        // 2. partial write via wstrb -- only touch the low byte of reg1
        do_write(32'h04, 32'h1111_1111, 4'hF, resp); // seed the register first
        do_write(32'h04, 32'hFFFF_FF00, 4'h1, resp); // only byte 0 strobe set
        do_read(32'h04, rd, resp);
        check(rd == 32'h1111_1100, "byte-strobe write only touched byte 0");

        // 3. AW arrives, then W a couple cycles later
        do_write_aw_first(32'h08, 32'hCAFEBABE, 4'hF, resp);
        do_read(32'h08, rd, resp);
        check(rd == 32'hCAFEBABE && resp == `RESP_OKAY, "AW-first write landed correctly");

        // 4. W arrives, then AW a couple cycles later
        do_write_w_first(32'h0C, 32'hDEAD1234, 4'hF, resp);
        do_read(32'h0C, rd, resp);
        check(rd == 32'hDEAD1234 && resp == `RESP_OKAY, "W-first write landed correctly");

        // 5. out-of-range write -> DECERR, and register storage untouched
        do_write(32'h40, 32'hFFFFFFFF, 4'hF, resp);
        check(resp == `RESP_DECERR, "out-of-range write -> DECERR");

        // 6. out-of-range read -> DECERR
        do_read(32'h40, rd, resp);
        check(resp == `RESP_DECERR, "out-of-range read -> DECERR");

        // 7. back-to-back writes, no idle cycle between them
        do_write(32'h10, 32'h0000_0001, 4'hF, resp);
        do_write(32'h14, 32'h0000_0002, 4'hF, resp);
        do_read(32'h10, rd, resp);
        check(rd == 32'h1, "back-to-back write 1 landed");
        do_read(32'h14, rd, resp);
        check(rd == 32'h2, "back-to-back write 2 landed");

        $display("");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        chk.report_summary;
        $finish;
    end

endmodule
