`timescale 1ns/1ps
module screen_pixels_tb;
    reg vga_clk=0,sys_rst_n=1;
    reg [9:0] pix_x=1023,pix_y=1023;
    reg [1:0] display_state=0;
    wire [15:0] pix_data;
    integer mode,x,y,checks=0,frame_file,pixel_file;
    reg [15:0] expected;
    screen_pixels dut(.vga_clk(vga_clk),.sys_rst_n(sys_rst_n),.pix_x(pix_x),.pix_y(pix_y),.display_state(display_state),.pix_data(pix_data));
    always #20 vga_clk=~vga_clk;
    `include "expected_screen.vh"
    task verify;
        input integer cx,cy;
        begin
            @(negedge vga_clk);pix_x=cx;pix_y=cy;expected=expected_pixel(display_state,cx,cy);
            @(posedge vga_clk);#1;
            if(pix_data!==expected)$fatal(1,"Pixel mode%0d (%0d,%0d) got%04h expected%04h",display_state,cx,cy,pix_data,expected);
            checks=checks+1;
        end
    endtask
    initial begin
        $dumpfile("screen_pixels_tb.vcd");$dumpvars(0,vga_clk,sys_rst_n,pix_x,pix_y,display_state,pix_data);
        pixel_file=$fopen("pixel_probes.csv","w");$fdisplay(pixel_file,"state,x,y,expected_rgb565,actual_rgb565");
        #1 sys_rst_n=0;#1;if(pix_data!==0)$fatal(1,"Pixel async reset failed");#3 sys_rst_n=1;
        for(mode=0;mode<3;mode=mode+1)begin
            display_state=mode;
            if(mode==0)frame_file=$fopen("pixels_bars.hex","w");
            if(mode==1)frame_file=$fopen("pixels_must.hex","w");
            if(mode==2)frame_file=$fopen("pixels_end.hex","w");
            for(y=0;y<480;y=y+1)begin
                if(y==208 || y==271)$dumpon;else $dumpoff;
                for(x=0;x<640;x=x+1)begin
                    verify(x,y);$fdisplay(frame_file,"%04h",pix_data);
                    if((y==0 && (x%80==0 || x%80==79)) || (y==208 && (x%8==0)) || (y==271 && (x%16==0)))
                        $fdisplay(pixel_file,"%0d,%0d,%0d,%04h,%04h",mode,x,y,expected,pix_data);
                end
            end
            $fclose(frame_file);
            $dumpon;verify(1023,1023);verify(640,0);verify(0,480);
        end
        display_state=3;verify(200,208);if(pix_data!==0)$fatal(1,"Invalid screen did not render black");
        #7 sys_rst_n=0;#1;if(pix_data!==0)$fatal(1,"Async reset failed from text");
        $fclose(pixel_file);
        $display("PASS screen_pixels_tb: %0d checks including every active pixel of all3 states (921600), invalid coordinates/state and reset",checks);$finish;
    end
    initial begin #40000000;$fatal(1,"screen_pixels_tb timeout");end
endmodule
