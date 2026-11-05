`timescale 1ns/1ns

module screen_ctrl (
    input  wire       vga_clk,
    input  wire       sys_rst_n,
    input  wire       click_pulse,
    input  wire       vsync,
    output reg  [1:0] state_q,
    output reg  [1:0] display_state_q
);

localparam [1:0] BARS = 2'b00;
localparam [1:0] MUST = 2'b01;
localparam [1:0] END_SCREEN = 2'b10;

reg [1:0] state_d;
reg previous_vsync;
wire frame_start;

assign frame_start = vsync && !previous_vsync;

// The logical state advances once for each qualified click.
always @* begin
    state_d = state_q;
    case (state_q)
        BARS:       if (click_pulse) state_d = MUST;
        MUST:       if (click_pulse) state_d = END_SCREEN;
        END_SCREEN: if (click_pulse) state_d = BARS;
        default: state_d = BARS;
    endcase
end

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state_q <= BARS;
        display_state_q <= BARS;
        previous_vsync <= 1'b1;
    end
    else begin
        state_q <= state_d;
        previous_vsync <= vsync;
        // Change the visible selection in vertical blanking, never mid-frame.
        // state_d also handles a click coinciding with this frame boundary.
        if (frame_start)
            display_state_q <= state_d;
    end
end

endmodule
