`timescale 1ns/1ps
module screen_ctrl_tb;
    reg vga_clk=0,sys_rst_n=1,click_pulse=0,vsync=0;
    wire [1:0] state_q,display_state_q;
    integer checks=0;
    screen_ctrl dut(.vga_clk(vga_clk),.sys_rst_n(sys_rst_n),.click_pulse(click_pulse),.vsync(vsync),.state_q(state_q),.display_state_q(display_state_q));
    always #20 vga_clk=~vga_clk;
    task step;
        input click;input sync;
        begin @(negedge vga_clk);click_pulse=click;vsync=sync;@(posedge vga_clk);#1;end
    endtask
    task verify;
        input [1:0] want_state,want_display;
        begin
            if(state_q!==want_state || display_state_q!==want_display)
                $fatal(1,"State mismatch: state=%0d/display=%0d expected=%0d/%0d at%0t",state_q,display_state_q,want_state,want_display,$time);
            checks=checks+1;
        end
    endtask
    initial begin
        $dumpfile("screen_ctrl_tb.vcd");$dumpvars(0,screen_ctrl_tb);
        #1 sys_rst_n=0;#1;verify(0,0);#3 sys_rst_n=1;
        step(1,0);verify(1,0); // click during active video requests MUST, holds BARS.
        step(0,0);verify(1,0);
        step(0,1);verify(1,1); // first blanking VSYNC edge commits.
        step(1,1);verify(2,1); // high VSYNC level alone must not re-commit.
        step(0,1);verify(2,1);
        step(0,0);verify(2,1);
        step(1,1);verify(0,0); // click+frame edge simultaneously commits next state.
        step(0,0);verify(0,0);
        step(1,0);verify(1,0);
        #7 sys_rst_n=0;#1;verify(0,0);#83 sys_rst_n=1; // reset from MUST.
        step(0,0);step(1,0);step(0,0);step(1,0);verify(2,0);
        step(0,1);verify(2,2);
        #7 sys_rst_n=0;#1;verify(0,0);#83 sys_rst_n=1; // reset from END.
        step(0,0);verify(0,0);
        $display("PASS screen_ctrl_tb: %0d exact logical/display-state checks, wrap, frame-edge commit, no high-level repeated commit, simultaneous click/frame and asynchronous reset",checks);$finish;
    end
    initial begin #10000;$fatal(1,"screen_ctrl_tb timeout");end
endmodule
