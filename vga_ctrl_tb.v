`timescale 1ns/1ps

module vga_ctrl_tb;
    reg vga_clk = 1'b0;
    reg sys_rst_n = 1'b1;
    reg [15:0] pix_data = 16'ha55a;
    wire [9:0] pix_x, pix_y;
    wire hsync, vsync;
    wire [15:0] rgb;
    integer x = 0;
    integer y = 0;
    integer n;
    integer checks = 0;
    integer visible = 0;
    integer requests = 0;
    integer hsync_high = 0;
    integer vsync_high = 0;
    reg dumping = 1'b1;
    reg wanted_dump;

    vga_ctrl dut (
        .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .pix_data(pix_data),
        .pix_x(pix_x), .pix_y(pix_y), .hsync(hsync), .vsync(vsync), .rgb(rgb)
    );
    always #20 vga_clk = ~vga_clk;

    task advance_position;
        begin
            if (x == 799) begin
                x = 0;
                if (y == 524) y = 0;
                else y = y + 1;
            end else x = x + 1;
        end
    endtask

    task check_outputs;
        reg active;
        reg requested;
        reg [9:0] expected_x, expected_y;
        reg [15:0] expected_rgb;
        begin
            active = (x >= 144 && x < 784 && y >= 35 && y < 515);
            requested = (x >= 143 && x < 783 && y >= 35 && y < 515);
            expected_x = requested ? x - 143 : 1023;
            expected_y = requested ? y - 35 : 1023;
            expected_rgb = active ? pix_data : 16'h0000;
            if (hsync !== (x < 96) || vsync !== (y < 2))
                $fatal(1, "Sync mismatch at x=%0d y=%0d", x, y);
            if (pix_x !== expected_x || pix_y !== expected_y)
                $fatal(1, "Coordinate mismatch x=%0d y=%0d: got %0d,%0d expected %0d,%0d", x, y, pix_x, pix_y, expected_x, expected_y);
            if (rgb !== expected_rgb)
                $fatal(1, "RGB gating mismatch at x=%0d y=%0d", x, y);
            checks = checks + 1;
        end
    endtask

    initial begin
        $dumpfile("vga_ctrl_tb.vcd");
        $dumpvars(0, vga_ctrl_tb);
        #1 sys_rst_n = 1'b0;
        #1;
        check_outputs;
        #11 sys_rst_n = 1'b1;
        for (n = 0; n < 420000; n = n + 1) begin
            @(posedge vga_clk);
            advance_position;
            #1;
            wanted_dump = (y == 0 || y == 35 || y == 514 || y == 524);
            if (wanted_dump && !dumping) begin $dumpon; dumping = 1'b1; end
            if (!wanted_dump && dumping) begin $dumpoff; dumping = 1'b0; end
            check_outputs;
            if (x >= 144 && x < 784 && y >= 35 && y < 515) visible = visible + 1;
            if (x >= 143 && x < 783 && y >= 35 && y < 515) requests = requests + 1;
            if (hsync) hsync_high = hsync_high + 1;
            if (vsync) vsync_high = vsync_high + 1;
            @(negedge vga_clk);
            pix_data = n[15:0] ^ 16'ha55a;
        end
        if (visible != 307200 || requests != 307200 || hsync_high != 50400 || vsync_high != 1600)
            $fatal(1, "Full-frame counts failed: visible=%0d requests=%0d H=%0d V=%0d", visible, requests, hsync_high, vsync_high);
        if (x != 0 || y != 0) $fatal(1, "Counters failed to wrap after 420000 clocks");

        // Reset during active video, without waiting for a clock edge.
        for (n = 0; n < 29100; n = n + 1) begin
            @(posedge vga_clk); advance_position; #1; check_outputs;
        end
        $dumpon; dumping = 1'b1;
        #5 sys_rst_n = 1'b0;
        x = 0; y = 0;
        #1; check_outputs;
        repeat (2) @(negedge vga_clk);
        #3 sys_rst_n = 1'b1;
        for (n = 0; n < 1603; n = n + 1) begin
            @(posedge vga_clk); advance_position; #1; check_outputs;
        end
        $display("PASS vga_ctrl_tb: %0d position checks; frame=800x525; visible=%0d requested=%0d H-high=%0d V-high=%0d; reset and line/frame wrap checked", checks, visible, requests, hsync_high, vsync_high);
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "vga_ctrl_tb timed out");
    end
endmodule
