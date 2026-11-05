`timescale 1ns/1ps
module vga_screens_tb;
    reg sys_clk=0,sys_rst_n=1,key_in=1;
    wire hsync,vsync;
    wire [15:0] rgb;
    integer x=0,y=0;
    integer logical_model=0,display_model=0,next_state;
    reg previous_vsync=1;
    reg old_vsync,old_click;
    integer pulses=0,pixels_checked=0,frames=0,active_count=0;
    integer frame_mode=-1;
    integer frame_file=0,sync_file,event_file,result_file;
    integer captured[0:2];
    integer captured_pixels[0:2];
    integer mode,k;
    integer active;
    reg [15:0] expected;
    reg dumping=1,wanted_dump;
    integer trace_budget=0;
    integer white_pixels[0:2];
    time last_h_rise=0,last_v_rise=0;
    integer h_period_checks=0,v_period_checks=0;
    vga_screens #(.DEBOUNCE_CYCLES(500000)) dut(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.key_in(key_in),.hsync(hsync),.vsync(vsync),.rgb(rgb));
    always #10 sys_clk=~sys_clk;
    `include "expected_screen.vh"

    // The raster and controller models use only clock samples and observed events.
    // Internal counters are separately observed; they never supply expected pixels.
    always @(posedge dut.vga_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            x=0;y=0;logical_model=0;display_model=0;previous_vsync=1;
            frame_mode=-1;active_count=0;last_h_rise=0;last_v_rise=0;
            if(frame_file)begin $fclose(frame_file);frame_file=0;end
        end else begin
            old_vsync=vsync;old_click=dut.click_pulse;
            next_state=logical_model;
            if(old_click)next_state=(logical_model+1)%3;
            logical_model=next_state;
            if(old_vsync && !previous_vsync)display_model=next_state;
            previous_vsync=old_vsync;
            if(x==799)begin x=0;if(y==524)begin y=0;frames=frames+1;end else y=y+1;end else x=x+1;
            #1;
            if(hsync!==(x<96) || vsync!==(y<2))$fatal(1,"Top sync mismatch at%0t scan%0d,%0d",$time,x,y);
            if(dut.state_q!==logical_model[1:0] || dut.display_state_q!==display_model[1:0])
                $fatal(1,"State model mismatch at%0t logical%0d/%0d display%0d/%0d",$time,dut.state_q,logical_model,dut.display_state_q,display_model);
            active=(x>=144 && x<784 && y>=35 && y<515);
            expected=active?expected_pixel(display_model,x-144,y-35):16'h0000;
            if(rgb!==expected)$fatal(1,"Top RGB mismatch at%0t state%0d xy%0d,%0d got%04h expected%04h",$time,display_model,x,y,rgb,expected);
            pixels_checked=pixels_checked+1;
            // Active-image coherence: the visible selection must not change mid-frame.
            if(active)begin
                if(x==144 && y==35)begin
                    frame_mode=display_model;active_count=0;
                    if(!captured[display_model])begin
                        case(display_model)
                            0:frame_file=$fopen("top_bars.hex","w");
                            1:frame_file=$fopen("top_must.hex","w");
                            2:frame_file=$fopen("top_end.hex","w");
                        endcase
                    end
                end
                if(frame_mode!=display_model)$fatal(1,"Visible state changed during active frame");
                active_count=active_count+1;
                if(frame_file)begin
                    $fdisplay(frame_file,"%04h",rgb);
                    captured_pixels[display_model]=captured_pixels[display_model]+1;
                    if(rgb==16'hffff)white_pixels[display_model]=white_pixels[display_model]+1;
                end
                if(x==783 && y==514)begin
                    if(active_count!=307200)$fatal(1,"Incomplete active frame pixels%0d",active_count);
                    if(frame_file)begin $fclose(frame_file);frame_file=0;captured[display_model]=1;end
                end
            end
            // Detailed dump windows retain counter threshold values and line edges.
            wanted_dump=(trace_budget>0 || dut.button_click_inst.counter_q>=499992 || dut.click_pulse ||
                (x<16 && y<3) || ((y==35 || y==243 || y==514) && x>=138 && x<200));
            if(trace_budget>0)trace_budget=trace_budget-1;
            if(wanted_dump && !dumping)begin $dumpon;dumping=1;end
            if(!wanted_dump && dumping)begin $dumpoff;dumping=0;end
        end
    end
    always @(posedge dut.click_pulse)begin pulses=pulses+1;end
    always @(key_in or sys_rst_n) trace_budget=12;
    always @(key_in or sys_rst_n or dut.click_pulse or dut.state_q or dut.display_state_q or dut.button_click_inst.armed_q)begin
        #0.001;
        if(event_file)$fdisplay(event_file,"%0.3f,%0b,%0b,%0b,%0d,%0d,%0d,%0d",$realtime,sys_rst_n,key_in,dut.click_pulse,dut.state_q,dut.display_state_q,dut.button_click_inst.counter_q,dut.button_click_inst.armed_q);
    end
    always @(hsync or vsync or sys_rst_n)begin
        #0.001;
        if(sync_file)$fdisplay(sync_file,"%0.3f,%0b,%0b,%0b",$realtime,sys_rst_n,hsync,vsync);
    end
    always @(posedge hsync)if(sys_rst_n)begin
        if(last_h_rise!=0 && ($time-last_h_rise)!=32000)$fatal(1,"H period not32us");
        if(last_h_rise!=0)h_period_checks=h_period_checks+1;
        last_h_rise=$time;
    end
    always @(posedge vsync)if(sys_rst_n)begin
        if(last_v_rise!=0 && ($time-last_v_rise)!=16800000)$fatal(1,"V period not16.8ms");
        if(last_v_rise!=0)v_period_checks=v_period_checks+1;
        last_v_rise=$time;
    end
    task hold_ns;
        input integer duration;
        begin #(duration);end
    endtask
    task raw;
        input value;
        begin @(negedge sys_clk);#3;key_in=value;end
    endtask
    task check_state;
        input integer test_id,want_pulses,want_state;
        begin
            #100;
            if(pulses!=want_pulses || dut.state_q!==want_state[1:0])$fatal(1,"T%0d pulses/state got%0d/%0d expected%0d/%0d",test_id,pulses,dut.state_q,want_pulses,want_state);
            $fdisplay(result_file,"T%0d,%0d,%0d,%0d,%0d,PASS",test_id,want_pulses,pulses,want_state,dut.state_q);
        end
    endtask
    task clean_click;
        begin raw(0);hold_ns(25000000);raw(1);hold_ns(25000000);end
    endtask
    task reset_now;
        begin
            #7 sys_rst_n=0;#1;
            if(dut.state_q!==0 || dut.display_state_q!==0 || rgb!==0)$fatal(1,"Asynchronous reset did not override screen");
            #83 sys_rst_n=1;
        end
    endtask
    initial begin
        for(k=0;k<3;k=k+1)begin captured[k]=0;captured_pixels[k]=0;white_pixels[k]=0;end
        sync_file=$fopen("top_sync_edges.csv","w");$fdisplay(sync_file,"time_ns,reset_n,hsync,vsync");
        event_file=$fopen("top_control_events.csv","w");$fdisplay(event_file,"time_ns,reset_n,key_in,click_pulse,state,display_state,counter,armed");
        result_file=$fopen("top_case_results.csv","w");$fdisplay(result_file,"case,expected_pulses,actual_pulses,expected_state,actual_state,result");
        $dumpfile("vga_screens_tb.vcd");
        $dumpvars(0,sys_clk,sys_rst_n,key_in,hsync,vsync,rgb,dut.vga_clk,dut.click_pulse,dut.state_q,dut.display_state_q,
            dut.pix_x,dut.pix_y,dut.pix_data,dut.vga_ctrl_inst.cnt_h,dut.vga_ctrl_inst.cnt_v,dut.vga_ctrl_inst.rgb_valid,
            dut.vga_ctrl_inst.pix_data_req,dut.button_click_inst.sync_key,dut.button_click_inst.counter_q,dut.button_click_inst.armed_q);
        #1 sys_rst_n=0;#83 sys_rst_n=1;
        hold_ns(25000000);check_state(1,0,0);
        // Actual production 20ms debounce for three clean clicks; full cycle wraps.
        clean_click;check_state(2,1,1);
        clean_click;check_state(3,2,2);
        clean_click;check_state(4,3,0);
        // 8ms press bounce, then 25ms stable low: one transition, not the bounce edges.
        raw(0);hold_ns(2000000);raw(1);hold_ns(1000000);raw(0);hold_ns(3000000);raw(1);hold_ns(2000000);
        check_state(5,3,0);raw(0);hold_ns(25000000);check_state(6,4,1);
        // Keep held another60ms. No repeat is allowed.
        hold_ns(60000000);check_state(7,4,1);
        // Reset from MUST while switch is still held, keep hold30ms after reset.
        reset_now;hold_ns(30000000);check_state(8,4,0);
        // A noisy release cannot re-arm until high stays valid20ms.
        raw(1);hold_ns(5000000);raw(0);hold_ns(2000000);raw(1);hold_ns(3000000);raw(0);hold_ns(1000000);
        check_state(9,4,0);raw(1);hold_ns(25000000);
        clean_click;check_state(10,5,1); // new real click after release works.
        // Reset MUST again with switch released, then reach END and reset it.
        reset_now;hold_ns(25000000);check_state(11,5,0);
        clean_click;clean_click;check_state(12,7,2);
        reset_now;hold_ns(25000000);check_state(13,7,0);
        reset_now;hold_ns(25000000);check_state(14,7,0); // BARS reset is idempotent.
        // A short 5ms raw low cannot meet20ms acceptance.
        raw(0);hold_ns(5000000);raw(1);hold_ns(25000000);check_state(15,7,0);
        for(k=0;k<3;k=k+1)if(!captured[k] || captured_pixels[k]!=307200)$fatal(1,"Missing complete state%0d frame pixels=%0d",k,captured_pixels[k]);
        if(v_period_checks<10 || h_period_checks<10000)$fatal(1,"Insufficient continuous sync coverage");
        $display("PASS vga_screens_tb: productionN=500000; seven accepted clicks,15scenario checks, resets all3states+midhold,8msbounce,60mslonghold,releasebounce,shortpress; every pixel checked across %0d frames / %0d pixel clocks",frames,pixels_checked);
        $display("PASS three complete top frames:307200 each, white pixels BARS=%0d MUST=%0d END=%0d; Hperiod_checks=%0d Vperiod_checks=%0d",white_pixels[0],white_pixels[1],white_pixels[2],h_period_checks,v_period_checks);
        $fclose(sync_file);$fclose(event_file);$fclose(result_file);$finish;
    end
    initial begin #1200000000;$fatal(1,"Top integration timeout");end
endmodule
