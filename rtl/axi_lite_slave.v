
`include "axi_lite_pkg.v"

module axi_lite_slave #(
    parameter ADDR_W   = `ADDR_W,
    parameter DATA_W   = `DATA_W,
    parameter NUM_REGS = 8
)(
    input wire clk,
    input wire rstn,

    input  wire [ADDR_W-1:0] awaddr,
    input  wire [2:0]        awprot,
    input  wire               awvalid,
    output wire               awready,

    input  wire [DATA_W-1:0]   wdata,
    input  wire [DATA_W/8-1:0] wstrb,
    input  wire                 wvalid,
    output wire                 wready,

    output wire [1:0] bresp,
    output wire       bvalid,
    input  wire       bready,

    input  wire [ADDR_W-1:0] araddr,
    input  wire [2:0]        arprot,
    input  wire               arvalid,
    output wire               arready,

    output wire [DATA_W-1:0] rdata,
    output wire [1:0]        rresp,
    output wire               rvalid,
    input  wire                rready
);

    localparam IDX_W = $clog2(NUM_REGS);

    reg [DATA_W-1:0] reg_file [0:NUM_REGS-1];


    reg [1:0] wstate;
    reg have_aw, have_w;
    reg [ADDR_W-1:0]   awaddr_latch;
    reg [DATA_W-1:0]   wdata_latch;
    reg [DATA_W/8-1:0] wstrb_latch;
    reg bvalid_r;
    reg [1:0] bresp_r;

    wire aw_here = have_aw || awvalid;
    wire w_here  = have_w  || wvalid;

    wire [IDX_W-1:0] aw_idx      = awaddr_latch[IDX_W+1:2];
    wire             aw_in_range = (awaddr_latch[ADDR_W-1:IDX_W+2] == 0);

    assign awready = (wstate == `SW_IDLE) || (wstate == `SW_DATA && !have_aw);
    assign wready  = (wstate == `SW_IDLE) || (wstate == `SW_DATA && !have_w);
    assign bvalid  = bvalid_r;
    assign bresp   = bresp_r;

    integer i;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wstate   <= `SW_IDLE;
            have_aw  <= 1'b0;
            have_w   <= 1'b0;
            bvalid_r <= 1'b0;
            bresp_r  <= 2'b00;
            for (i = 0; i < NUM_REGS; i = i + 1)
                reg_file[i] <= {DATA_W{1'b0}};
        end else begin
            case (wstate)

                `SW_IDLE: begin
                    if (awvalid) begin
                        awaddr_latch <= awaddr;
                        have_aw      <= 1'b1;
                    end
                    if (wvalid) begin
                        wdata_latch <= wdata;
                        wstrb_latch <= wstrb;
                        have_w      <= 1'b1;
                    end
                    if (aw_here && w_here)
                        wstate <= `SW_RESP;
                    else if (awvalid || wvalid)
                        wstate <= `SW_DATA;
                end

                `SW_DATA: begin
                    if (!have_aw && awvalid) begin
                        awaddr_latch <= awaddr;
                        have_aw      <= 1'b1;
                    end
                    if (!have_w && wvalid) begin
                        wdata_latch <= wdata;
                        wstrb_latch <= wstrb;
                        have_w      <= 1'b1;
                    end
                    if (aw_here && w_here)
                        wstate <= `SW_RESP;
                end

                `SW_RESP: begin
                    if (!bvalid_r) begin
                        if (aw_in_range) begin
                            for (i = 0; i < DATA_W/8; i = i + 1)
                                if (wstrb_latch[i])
                                    reg_file[aw_idx][i*8 +: 8] <= wdata_latch[i*8 +: 8];
                            bresp_r <= `RESP_OKAY;
                        end else begin
                            bresp_r <= `RESP_DECERR;
                        end
                        bvalid_r <= 1'b1;
                    end else if (bready) begin
                        bvalid_r <= 1'b0;
                        have_aw  <= 1'b0;
                        have_w   <= 1'b0;
                        wstate   <= `SW_IDLE;
                    end
                end

                default: wstate <= `SW_IDLE;
            endcase
        end
    end

    reg rstate;
    reg [ADDR_W-1:0] araddr_latch;
    reg rvalid_r;
    reg [DATA_W-1:0] rdata_r;
    reg [1:0] rresp_r;

    wire [IDX_W-1:0] ar_idx      = araddr_latch[IDX_W+1:2];
    wire             ar_in_range = (araddr_latch[ADDR_W-1:IDX_W+2] == 0);

    assign arready = (rstate == `SR_IDLE);
    assign rvalid  = rvalid_r;
    assign rdata   = rdata_r;
    assign rresp   = rresp_r;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rstate   <= `SR_IDLE;
            rvalid_r <= 1'b0;
            rdata_r  <= {DATA_W{1'b0}};
            rresp_r  <= 2'b00;
        end else begin
            case (rstate)
                `SR_IDLE: begin
                    if (arvalid) begin
                        araddr_latch <= araddr;
                        rstate       <= `SR_DATA;
                    end
                end
                `SR_DATA: begin
                    if (!rvalid_r) begin
                        rdata_r  <= ar_in_range ? reg_file[ar_idx] : {DATA_W{1'b0}};
                        rresp_r  <= ar_in_range ? `RESP_OKAY : `RESP_DECERR;
                        rvalid_r <= 1'b1;
                    end else if (rready) begin
                        rvalid_r <= 1'b0;
                        rstate   <= `SR_IDLE;
                    end
                end
                default: rstate <= `SR_IDLE;
            endcase
        end
    end

endmodule
