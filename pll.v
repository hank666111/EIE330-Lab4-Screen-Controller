`timescale 1ns/1ns

module pll (
    input  wire sys_clk,
    input  wire sys_rst_n,
    output reg  vga_clk
);

// The lab uses a divide-by-two flip-flop rather than a PLL IP core.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        vga_clk <= 1'b0;
    else
        vga_clk <= ~vga_clk;
end

endmodule
