`include "axi_lite_pkg.v"

module axi_lite_master #(
    parameter ADDR_W = `ADDR_W,
    parameter DATA_W = `DATA_W
)(
    input wire clk,
    input wire rstn,

    input  wire               start,
    input  wire               rw,     
    input  wire [ADDR_W-1:0]  addr,
    input  wire [DATA_W-1:0]  wdata,
    output reg  [DATA_W-1:0]  rdata,
    output reg                done,

    output reg  [ADDR_W-1:0] awaddr,
    output reg                awvalid,
    input  wire                awready,

    output reg  [DATA_W-1:0]   m_wdata,
    output reg  [DATA_W/8-1:0] wstrb,
    output reg                  wvalid,
    input  wire                  wready,

    input  wire [1:0] bresp,
    input  wire       bvalid,
    output reg         bready,

    output reg  [ADDR_W-1:0] araddr,
    output reg                arvalid,
    input  wire                arready,

    input  wire [DATA_W-1:0] m_rdata,
    input  wire [1:0]        rresp,
    input  wire               rvalid,
    output reg                 rready
);

    reg [2:0] state;
    reg [ADDR_W-1:0] addr_latch;
    reg [DATA_W-1:0] wdata_latch;
    reg aw_sent, w_sent; // did this channel's handshake already complete

    wire aw_done = aw_sent || (awvalid && awready);
    wire w_done  = w_sent  || (wvalid  && wready);

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state       <= `M_IDLE;
            awaddr      <= 0;
            awvalid     <= 1'b0;
            m_wdata     <= 0;
            wstrb       <= 0;
            wvalid      <= 1'b0;
            bready      <= 1'b0;
            araddr      <= 0;
            arvalid     <= 1'b0;
            rready      <= 1'b0;
            rdata       <= 0;
            done        <= 1'b0;
            aw_sent     <= 1'b0;
            w_sent      <= 1'b0;
            addr_latch  <= 0;
            wdata_latch <= 0;
        end else begin
            done <= 1'b0; 
            case (state)

                `M_IDLE: begin
                    if (start) begin
                        addr_latch  <= addr;
                        wdata_latch <= wdata;
                        aw_sent     <= 1'b0;
                        w_sent      <= 1'b0;
                        if (!rw) begin
                            awaddr  <= addr;
                            awvalid <= 1'b1;
                            m_wdata <= wdata;
                            wstrb   <= {DATA_W/8{1'b1}};
                            wvalid  <= 1'b1;
                            state   <= `M_WADDR;
                        end else begin
                            araddr  <= addr;
                            arvalid <= 1'b1;
                            state   <= `M_RADDR;
                        end
                    end
                end

                `M_WADDR: begin
                    if (awvalid && awready) begin
                        awvalid <= 1'b0;
                        aw_sent <= 1'b1;
                    end
                    if (wvalid && wready) begin
                        wvalid <= 1'b0;
                        w_sent <= 1'b1;
                    end
                    if (aw_done && w_done) begin
                        bready <= 1'b1;
                        state  <= `M_WRESP;
                    end
                end

                `M_WRESP: begin
                    if (bready && bvalid) begin
                        bready <= 1'b0;
                        done   <= 1'b1;
                        state  <= `M_IDLE;
                    end
                end

                `M_RADDR: begin
                    if (arvalid && arready) begin
                        arvalid <= 1'b0;
                        rready  <= 1'b1;
                        state   <= `M_RDATA;
                    end
                end

                `M_RDATA: begin
                    if (rready && rvalid) begin
                        rdata  <= m_rdata;
                        rready <= 1'b0;
                        done   <= 1'b1;
                        state  <= `M_IDLE;
                    end
                end

                default: state <= `M_IDLE;
            endcase
        end
    end

endmodule
