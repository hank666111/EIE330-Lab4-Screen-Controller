`timescale 1ns/1ns

module screen_pixels (
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [1:0]  display_state,
    output reg  [15:0] pix_data
);

localparam [1:0] BARS = 2'b00;
localparam [1:0] MUST = 2'b01;
localparam [1:0] END_SCREEN = 2'b10;
localparam [15:0] BLACK = 16'h0000;
localparam [15:0] WHITE = 16'hffff;

// Rows are ordered top to bottom; bit 7 is the leftmost cell.
// M/U/S/T reuse the Lab 3 bitmaps. E/N/D were drawn for this lab.
function [7:0] font_row;
    input [2:0] letter;
    input [2:0] row;
    reg [63:0] bitmap;
    begin
        case (letter)
            3'd0: bitmap = 64'hc3e7ffdbc3c3c3c3; // M
            3'd1: bitmap = 64'hc3c3c3c3c3c3663c; // U
            3'd2: bitmap = 64'h7ec3c07e0303c37e; // S
            3'd3: bitmap = 64'hffff181818181818; // T
            3'd4: bitmap = 64'hffc0c0fcc0c0c0ff; // E
            3'd5: bitmap = 64'hc3e3f3dbcfc7c3c3; // N
            3'd6: bitmap = 64'hfcc6c3c3c3c3c6fc; // D
            default: bitmap = 64'h0000000000000000;
        endcase
        font_row = bitmap[6'd63 - {row, 3'b000} -: 8];
    end
endfunction

reg [15:0] next_pixel;
reg [2:0] letter_index;
reg [9:0] box_x;
reg in_box;
reg [2:0] cell_x;
reg [2:0] cell_y;
reg [7:0] row_bits;

always @* begin
    next_pixel = BLACK;
    letter_index = 3'd7;
    box_x = 10'd0;
    in_box = 1'b0;
    cell_x = 3'd0;
    cell_y = 3'd0;
    row_bits = 8'h00;

    if ((pix_x < 10'd640) && (pix_y < 10'd480)) begin
        case (display_state)
            BARS: begin
                if (pix_x < 10'd80)       next_pixel = WHITE;
                else if (pix_x < 10'd160) next_pixel = 16'hffe0;
                else if (pix_x < 10'd240) next_pixel = 16'h07ff;
                else if (pix_x < 10'd320) next_pixel = 16'h07e0;
                else if (pix_x < 10'd400) next_pixel = 16'hf81f;
                else if (pix_x < 10'd480) next_pixel = 16'hf800;
                else if (pix_x < 10'd560) next_pixel = 16'h001f;
                else                     next_pixel = BLACK;
            end
            MUST: begin
                if ((pix_x >= 10'd168) && (pix_x < 10'd232)) begin
                    letter_index = 3'd0;
                    box_x = 10'd168;
                    in_box = 1'b1;
                end
                else if ((pix_x >= 10'd248) && (pix_x < 10'd312)) begin
                    letter_index = 3'd1;
                    box_x = 10'd248;
                    in_box = 1'b1;
                end
                else if ((pix_x >= 10'd328) && (pix_x < 10'd392)) begin
                    letter_index = 3'd2;
                    box_x = 10'd328;
                    in_box = 1'b1;
                end
                else if ((pix_x >= 10'd408) && (pix_x < 10'd472)) begin
                    letter_index = 3'd3;
                    box_x = 10'd408;
                    in_box = 1'b1;
                end
            end
            END_SCREEN: begin
                if ((pix_x >= 10'd208) && (pix_x < 10'd272)) begin
                    letter_index = 3'd4;
                    box_x = 10'd208;
                    in_box = 1'b1;
                end
                else if ((pix_x >= 10'd288) && (pix_x < 10'd352)) begin
                    letter_index = 3'd5;
                    box_x = 10'd288;
                    in_box = 1'b1;
                end
                else if ((pix_x >= 10'd368) && (pix_x < 10'd432)) begin
                    letter_index = 3'd6;
                    box_x = 10'd368;
                    in_box = 1'b1;
                end
            end
            default: next_pixel = BLACK;
        endcase

        if (in_box && (pix_y >= 10'd208) && (pix_y < 10'd272)) begin
            // All origins are multiples of eight; the 3-bit offsets wrap
            // modulo eight inside each 64-pixel box.
            cell_x = pix_x[5:3] - box_x[5:3];
            cell_y = pix_y[5:3] - 3'd2;
            row_bits = font_row(letter_index, cell_y);
            next_pixel = row_bits[3'd7 - cell_x] ? WHITE : BLACK;
        end
    end
end

// This one-cycle register matches the controller's early color request.
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pix_data <= BLACK;
    else
        pix_data <= next_pixel;
end

endmodule
