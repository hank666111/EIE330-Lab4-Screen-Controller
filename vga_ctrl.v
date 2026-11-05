`timescale 1ns/1ns

module vga_ctrl (
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [15:0] pix_data,
    output wire [9:0]  pix_x,
    output wire [9:0]  pix_y,
    output wire        hsync,
    output wire        vsync,
    output wire [15:0] rgb
);

localparam H_SYNC  = 10'd96;
localparam H_BACK  = 10'd40;
localparam H_LEFT  = 10'd8;
localparam H_VALID = 10'd640;
localparam H_RIGHT = 10'd8;
localparam H_FRONT = 10'd8;
localparam H_TOTAL = H_SYNC + H_BACK + H_LEFT + H_VALID
                  + H_RIGHT + H_FRONT;

localparam V_SYNC  = 10'd2;
localparam V_BACK  = 10'd25;
localparam V_TOP   = 10'd8;
localparam V_VALID = 10'd480;
localparam V_BOTTOM = 10'd8;
localparam V_FRONT = 10'd2;
localparam V_TOTAL = V_SYNC + V_BACK + V_TOP + V_VALID
                  + V_BOTTOM + V_FRONT;

reg [9:0] cnt_h;
reg [9:0] cnt_v;
wire rgb_valid;
wire pix_data_req;

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_h <= 10'd0;
    else if (cnt_h == H_TOTAL - 1'b1)
        cnt_h <= 10'd0;
    else
        cnt_h <= cnt_h + 1'b1;
end

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_v <= 10'd0;
    else if (cnt_h == H_TOTAL - 1'b1) begin
        if (cnt_v == V_TOTAL - 1'b1)
            cnt_v <= 10'd0;
        else
            cnt_v <= cnt_v + 1'b1;
    end
end

// The lecture and virtual board use high-going sync pulses.
assign hsync = (cnt_h < H_SYNC);
assign vsync = (cnt_v < V_SYNC);

assign rgb_valid = (cnt_h >= H_SYNC + H_BACK + H_LEFT)
                && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID)
                && (cnt_v >= V_SYNC + V_BACK + V_TOP)
                && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID);

// Request the next color one pixel early because vga_pic is registered.
assign pix_data_req = (cnt_h >= H_SYNC + H_BACK + H_LEFT - 1'b1)
                   && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID - 1'b1)
                   && (cnt_v >= V_SYNC + V_BACK + V_TOP)
                   && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID);

assign pix_x = pix_data_req
             ? cnt_h - (H_SYNC + H_BACK + H_LEFT - 1'b1) : 10'h3ff;
assign pix_y = pix_data_req
             ? cnt_v - (V_SYNC + V_BACK + V_TOP) : 10'h3ff;
assign rgb = rgb_valid ? pix_data : 16'h0000;

endmodule
