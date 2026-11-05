`timescale 1ns/1ps
module button_click_tb;
    localparam N = 500000;
    reg vga_clk=0, sys_rst_n=1, key_in=0;
    wire click_pulse;
    integer pulses=0;
    integer events_file;
    integer expected_pulses=0;
    integer i;
    reg previous_pulse=0;
    button_click #(.DEBOUNCE_CYCLES(N)) dut(
        .vga_clk(vga_clk),.sys_rst_n(sys_rst_n),.key_in(key_in),.click_pulse(click_pulse));
    always #20 vga_clk=~vga_clk;
    always @(posedge click_pulse) begin
        pulses=pulses+1;
        if (events_file) $fdisplay(events_file,"%0.3f,click,%0d,%0d,%0d",$realtime,pulses,dut.counter_q,dut.armed_q);
    end
    always @(posedge vga_clk) begin
        #1;
        if (sys_rst_n && previous_pulse && click_pulse) $fatal(1,"Click wider than one cycle");
        previous_pulse=click_pulse;
    end
    always @(key_in or sys_rst_n or dut.armed_q) begin
        #0.001;
        if (events_file) $fdisplay(events_file,"%0.3f,levels,%0d,%0d,%0d",$realtime,key_in,sys_rst_n,dut.armed_q);
    end
    task cycles;
        input integer count;
        integer k;
        begin for(k=0;k<count;k=k+1) begin @(posedge vga_clk); #1; end end
    endtask
    task drive;
        input value;
        begin @(negedge vga_clk); key_in=value; end
    endtask
    task expect_count;
        input integer want;
        begin if(pulses!=want) $fatal(1,"Pulse count got %0d expected %0d at %0t",pulses,want,$time); end
    endtask
    task qualify_release;
        begin
            drive(1); $dumpon; cycles(5); $dumpoff; cycles(N-12); $dumpon; cycles(9); $dumpoff;
            if(!dut.armed_q) $fatal(1,"Stable release did not arm");
        end
    endtask
    task qualified_press;
        begin
            drive(0); $dumpoff;
            cycles(N-7); $dumpon;
            cycles(8); // N+1 clocks after raw transition; only N-1 qualified low samples.
            if(click_pulse || dut.counter_q!=N-1) $fatal(1,"Early click / threshold counter at N+1: count=%0d pulse=%0b",dut.counter_q,click_pulse);
            cycles(1); expected_pulses=expected_pulses+1;
            if(!click_pulse || dut.armed_q) $fatal(1,"Threshold did not produce one disarming pulse");
            cycles(1); if(click_pulse) $fatal(1,"Pulse did not clear");
            expect_count(expected_pulses); $dumpoff;
        end
    endtask
    initial begin
        events_file=$fopen("button_events.csv","w");
        $fdisplay(events_file,"time_ns,event,value1,value2,value3");
        $dumpfile("button_click_tb.vcd");
        $dumpvars(0,vga_clk,sys_rst_n,key_in,click_pulse,dut.sync_meta,dut.sync_key,dut.counter_q,dut.armed_q);
        #1 sys_rst_n=0; #3 sys_rst_n=1;
        // Startup with switch already held: even a long hold must not count.
        cycles(8); $dumpoff; cycles(N+12); expect_count(0);
        if(dut.armed_q) $fatal(1,"Held startup key wrongly armed");
        qualify_release;
        // A sub-threshold 1ms press cannot advance the screen.
        drive(0); cycles(25000); drive(1); cycles(25002); expect_count(0);
        // Full production qualification and hold for another 40ms: exactly one.
        qualified_press; cycles(2*N); expect_count(1);
        // Release bounce: high 5ms, low 2ms, high 3ms, low 1ms.
        drive(1);cycles(125000);drive(0);cycles(50000);drive(1);cycles(75000);drive(0);cycles(25000);
        if(dut.armed_q) $fatal(1,"Release bounce re-armed early"); expect_count(1);
        qualify_release;
        // Press bounce: low 2ms/high1ms/low3ms/high1ms, then a real press.
        drive(0);cycles(50000);drive(1);cycles(25000);drive(0);cycles(75000);drive(1);cycles(25000);
        expect_count(1); qualified_press; cycles(N); expect_count(2);
        // Reset while held, then continue holding beyond debounce: no extra click.
        #7 sys_rst_n=0; #1;
        if(click_pulse || dut.armed_q || dut.counter_q!=0) $fatal(1,"Reset did not clear button state");
        #83 sys_rst_n=1; cycles(2*N); expect_count(2);
        if(dut.armed_q) $fatal(1,"Switch held through reset wrongly armed");
        qualify_release; qualified_press; cycles(N); expect_count(3);
        // A reset during an unfinished 10ms qualification cancels the candidate.
        qualify_release; drive(0); cycles(250000);
        #7 sys_rst_n=0; #83 sys_rst_n=1; cycles(N+20); expect_count(3);
        if(dut.armed_q) $fatal(1,"Mid-qualification reset rearmed held key");
        qualify_release; qualified_press; cycles(10); expect_count(4);
        $dumpon;
        $display("PASS button_click_tb: production N=500000 (20ms), exact threshold 499999, startup-held, short glitch, press/release bounce, 40ms hold, held-through-reset and reset during unfinished qualification; pulses=%0d",pulses);
        $fclose(events_file);$finish;
    end
    initial begin #1000000000; $fatal(1,"button_click_tb timeout");end
endmodule
