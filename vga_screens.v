`timescale 1ns/1ns

module vga_screens #(
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        key_in,
    output wire        hsync,
    output wire        vsync,
    output wire [15:0] rgb
);

wire vga_clk;
wire [9:0] pix_x;
wire [9:0] pix_y;
wire [15:0] pix_data;
wire click_pulse;
wire [1:0] state_q;
wire [1:0] display_state_q;

pll pll_inst (
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .vga_clk(vga_clk)
);

vga_ctrl vga_ctrl_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .pix_data(pix_data),
    .pix_x(pix_x), .pix_y(pix_y), .hsync(hsync), .vsync(vsync), .rgb(rgb)
);

button_click #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) button_click_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .key_in(key_in),
    .click_pulse(click_pulse)
);

screen_ctrl screen_ctrl_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .click_pulse(click_pulse),
    .vsync(vsync), .state_q(state_q), .display_state_q(display_state_q)
);

screen_pixels screen_pixels_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .pix_x(pix_x), .pix_y(pix_y),
    .display_state(display_state_q), .pix_data(pix_data)
);

endmodule
