// axi_lite_pkg.v
// common defines used by the master, slave, interconnect and checker

`ifndef AXI_LITE_PKG_V
`define AXI_LITE_PKG_V

// bus widths
`define ADDR_W   16
`define DATA_W   32
`define STRB_W   (`DATA_W/8)
`define PROT_W   3

// resp codes 
`define RESP_OKAY    2'b00
`define RESP_SLVERR  2'b10  // valid addr, bad access (e.g. write to RO reg)
`define RESP_DECERR  2'b11  // addr doesn't map to anything

// slave write fsm states
`define SW_IDLE  2'd0
`define SW_DATA  2'd1
`define SW_RESP  2'd2

// slave read fsm states
`define SR_IDLE  2'd0
`define SR_DATA  2'd1

// master fsm states
`define M_IDLE     3'd0
`define M_WADDR    3'd1
`define M_WRESP    3'd2
`define M_RADDR    3'd3
`define M_RDATA    3'd4
`define M_DONE     3'd5


`endif
