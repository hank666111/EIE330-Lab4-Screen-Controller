`timescale 1ns/1ns

module button_click #(
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input  wire vga_clk,
    input  wire sys_rst_n,
    input  wire key_in,
    output reg  click_pulse
);

localparam integer COUNT_WIDTH = (DEBOUNCE_CYCLES < 2)
                              ? 1 : $clog2(DEBOUNCE_CYCLES);
localparam integer LAST_COUNT_INT = DEBOUNCE_CYCLES - 1;
localparam [COUNT_WIDTH-1:0] LAST_COUNT = LAST_COUNT_INT[COUNT_WIDTH-1:0];

// Bring the asynchronous active-low button into the pixel-clock domain.
(* ASYNC_REG = "TRUE" *) reg sync_meta;
(* ASYNC_REG = "TRUE" *) reg sync_key;
reg [1:0] sync_valid;
reg [COUNT_WIDTH-1:0] counter_q;
reg armed_q;

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sync_meta <= 1'b1;
        sync_key <= 1'b1;
        sync_valid <= 2'b00;
    end
    else begin
        sync_meta <= key_in;
        sync_key <= sync_meta;
        sync_valid <= {sync_valid[0], 1'b1};
    end
end

// When unarmed, qualify a release. When armed, qualify a press.
// A level must remain unchanged for the whole qualification interval.
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        counter_q <= {COUNT_WIDTH{1'b0}};
        armed_q <= 1'b0;
        click_pulse <= 1'b0;
    end
    else begin
        click_pulse <= 1'b0;
        // Ignore the synchronizer's reset values until real samples arrive.
        if (!sync_valid[1]) begin
            counter_q <= {COUNT_WIDTH{1'b0}};
            armed_q <= 1'b0;
        end
        else if (armed_q) begin
            if (sync_key)
                counter_q <= {COUNT_WIDTH{1'b0}};
            else if (counter_q == LAST_COUNT) begin
                counter_q <= {COUNT_WIDTH{1'b0}};
                armed_q <= 1'b0;
                click_pulse <= 1'b1;
            end
            else
                counter_q <= counter_q + 1'b1;
        end
        else begin
            if (!sync_key)
                counter_q <= {COUNT_WIDTH{1'b0}};
            else if (counter_q == LAST_COUNT) begin
                counter_q <= {COUNT_WIDTH{1'b0}};
                armed_q <= 1'b1;
            end
            else
                counter_q <= counter_q + 1'b1;
        end
    end
end

endmodule
