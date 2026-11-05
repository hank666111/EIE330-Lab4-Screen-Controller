// Independent expected-image oracle from the frozen screen specification.
// Whole 64-bit bitmaps and integer geometry deliberately differ from RTL lookup.
function [15:0] expected_pixel;
    input integer mode;
    input integer sx;
    input integer sy;
    integer letter;
    integer origin;
    integer lx;
    integer row;
    integer col;
    integer total;
    reg [63:0] bits;
    begin
        expected_pixel = 16'h0000;
        if (sx >= 0 && sx < 640 && sy >= 0 && sy < 480) begin
            if (mode == 0) begin
                case (sx / 80)
                    0: expected_pixel = 16'hffff;
                    1: expected_pixel = 16'hffe0;
                    2: expected_pixel = 16'h07ff;
                    3: expected_pixel = 16'h07e0;
                    4: expected_pixel = 16'hf81f;
                    5: expected_pixel = 16'hf800;
                    6: expected_pixel = 16'h001f;
                    7: expected_pixel = 16'h0000;
                endcase
            end else if (mode == 1 || mode == 2) begin
                total = (mode == 1) ? 4 : 3;
                origin = (mode == 1) ? 168 : 208;
                for (letter = 0; letter < total; letter = letter + 1) begin
                    lx = sx - (origin + 80*letter);
                    bits = 64'h0;
                    if (mode == 1) begin
                        case (letter)
                            0: bits = 64'hc3e7ffdbc3c3c3c3;
                            1: bits = 64'hc3c3c3c3c3c3663c;
                            2: bits = 64'h7ec3c07e0303c37e;
                            3: bits = 64'hffff181818181818;
                        endcase
                    end else begin
                        case (letter)
                            0: bits = 64'hffc0c0fcc0c0c0ff;
                            1: bits = 64'hc3e3f3dbcfc7c3c3;
                            2: bits = 64'hfcc6c3c3c3c3c6fc;
                        endcase
                    end
                    if (lx >= 0 && lx < 64 && sy >= 208 && sy < 272) begin
                        row = (sy - 208) / 8;
                        col = lx / 8;
                        if (bits[63-8*row-col]) expected_pixel = 16'hffff;
                    end
                end
            end
        end
    end
endfunction
