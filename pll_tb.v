`timescale 1ns/1ps

module pll_tb;
    reg sys_clk = 1'b0;
    reg sys_rst_n = 1'b1;
    wire vga_clk;
    integer i;
    integer checks = 0;
    reg expected_clock = 1'b0;
    time previous_rise = 0;
    integer period_checks = 0;

    pll dut (.sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .vga_clk(vga_clk));
    always #10 sys_clk = ~sys_clk;

    always @(posedge vga_clk) begin
        if (sys_rst_n) begin
            if (previous_rise != 0) begin
                if (($time - previous_rise) != 40)
                    $fatal(1, "Pixel clock period was %0t, expected 40 ns", $time-previous_rise);
                period_checks = period_checks + 1;
            end
            previous_rise = $time;
        end
    end

    task check_cycles;
        input integer count;
        integer k;
        begin
            for (k = 0; k < count; k = k + 1) begin
                @(posedge sys_clk);
                expected_clock = ~expected_clock;
                #1;
                if (vga_clk !== expected_clock)
                    $fatal(1, "Divider phase mismatch at %0t", $time);
                checks = checks + 1;
                @(negedge sys_clk);
                #1;
                if (vga_clk !== expected_clock)
                    $fatal(1, "Divider changed on the falling system-clock edge");
                checks = checks + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("pll_tb.vcd");
        $dumpvars(0, pll_tb);
        #1 sys_rst_n = 1'b0;
        #1;
        if (vga_clk !== 1'b0) $fatal(1, "Clock was not zero during reset");
        #23 sys_rst_n = 1'b1;
        check_cycles(20);

        // Assert reset while the divided clock is high, between system edges.
        @(posedge vga_clk);
        #3 sys_rst_n = 1'b0;
        #1;
        if (vga_clk !== 1'b0) $fatal(1, "Asynchronous reset did not clear the clock");
        expected_clock = 1'b0;
        previous_rise = 0;
        repeat (2) @(negedge sys_clk);
        #3 sys_rst_n = 1'b1;
        check_cycles(20);
        if (period_checks < 15) $fatal(1, "Too few complete pixel-clock periods checked");
        $display("PASS pll_tb: %0d level checks, %0d complete 40 ns periods; asynchronous reset and restart checked", checks, period_checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "pll_tb timed out");
    end
endmodule
