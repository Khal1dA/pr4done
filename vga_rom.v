// VGA driver design
// File vga.v
// Generates VGA timing and data signals to drive a VGA monitor
//   in 640 x 480 mode
// Don M. Gruenbacher
// March 8, 2004




module vga_rom(aSign, bSign, bothSign, enter, x_in1 ,x_in2, x_in3,x_in4,Op, CLOCK_50, ar, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC, VGA_CLK);
   input CLOCK_50; // 50 MHz input clock
input enter;
input aSign, bSign, bothSign;
	input [3:0] x_in1	, x_in2, x_in3,x_in4, Op;
	input ar;  // Active low asynchronous reset
   output [7:0] VGA_R, VGA_G, VGA_B; // Red, green, and blue outputs
   output VGA_HS;   // Output horizontal synch
   output VGA_VS;   // Output vertical synch
	output VGA_BLANK, VGA_SYNC;
	output VGA_CLK;

   reg 	  r, g, b;
   reg    hsync, vsync;
	reg clk; // 25 MHz  clock
   


   reg [9:0] hcount, vcount;  // Counters used for creating the vsync and hsync signals

   reg 	     video_on_h, video_on_v;
   
	assign VGA_BLANK = 1'b1;
	assign VGA_SYNC = 1'b1;
	assign VGA_HS = hsync;
	assign VGA_VS = vsync;
	
	assign VGA_R = {{8{r}}}; //, 7'b0};
	assign VGA_G = {{8{g}}};// g, 7'b0};
	assign VGA_B = {{8{b}}};//b, 7'b0};
	
   parameter [9:0] h_max = 10'd799;
   parameter [9:0] v_max = 10'd524;
   

	
   
	// Instantiate the 256x8 Asynchronous ROM containing the fonts
	// Note:   the font file, tcgrom.mif, actually has 512 words, but we 
	//	will only readn in the first 256 words and store them in the ROM
	//	Each character is 8x8 pixels, so we are storing 32 characters
	
   parameter 	   LPM_FILE = "tcgrom.mif";
   
	     
   wire [8:0] 	   rom_addr;
   wire [7:0] 	   rom_q;

   reg [7:0] 	   shift_reg;
	
	reg [5:0] disp_char [3:0][8:0];   // Two-dimensional array that holds characters to be displayed
	reg [1:0] line;

	always @(negedge ar or posedge enter)
     if(~ar)
 begin
 integer i =0;
 integer j =0;
 line = 0;
     for( i =0; i<9; i=i+1)
 for( j =0; j<4; j=j+1)
  disp_char[j][i] = 6'o40;
 end
 
 else
       begin
case(Op)
2'b10: disp_char[line][2] = 6'o52;//*
2'b01: disp_char[line][2] = 6'o55;//+
2'b00: disp_char[line][2] = 6'o53;//-
default: disp_char[line][2] = 6'o52;//*
endcase
case(aSign)
2'b0: disp_char[line][0] = 6'o40;
2'b1: disp_char[line][0] = 6'o55;
default: disp_char[line][0] = 6'o40;
endcase
case(bSign)
2'b0: disp_char[line][3] = 6'o40;
2'b1: disp_char[line][3] = 6'o55;
default: disp_char[line][3] = 6'o40;
endcase
case(bothSign)
2'b0: disp_char[line][6] = 6'o40;
2'b1: disp_char[line][6] = 6'o55;
default: disp_char[line][6] = 6'o40;
endcase

disp_char[line][1] = {2'b11,x_in4};// first number
disp_char[line][4] = {2'b11,x_in1};//2nd number
disp_char[line][5] = 6'o42;//=
disp_char[line][7] = {2'b11,x_in2};//finals value[1]
disp_char[line][8] = {2'b11,x_in3}; //finals value[2]
line = line+1;
 

end
	
	
 	font_rom rom1(
	.address(rom_addr),
	.clock(clk),
	.q(rom_q));   
		
   assign rom_addr = {disp_char[vcount[4:3]][hcount[8:3]], vcount[2:0]};

	
// Implement the shift register that interfaces the ROM outputs to the VGA RGB outputs

   always @(negedge ar or posedge clk)
     if(~ar)
       shift_reg = 8'b0;
     
	  else
       begin
	 if (hcount[2:0] == 3'h7) // load the shift register on next clock
	   shift_reg = rom_q;
	 else
	   shift_reg = {shift_reg[6:0], 1'b0};
       end

   
   // Generate R,G,B outputs for a colorbar pattern (just use the hcount position)

   always @(negedge ar or posedge clk)
     if(~ar)
       begin
   
	  r = 1'b0;
	  g = 1'b0;
	  b = 1'b0;
       end
     else
       begin
	  if(video_on_v & video_on_h) // Allow non-zero RGB only within the 640x480 area
	    begin
	      if(hcount > 7 && hcount < 80)
				begin
					if(vcount > 7 && vcount < 32)
					begin
					r = shift_reg[7];
					g = r;
					b = g;
					end
					end
					else
				begin
				r = hcount[8];
				g = hcount[7];
				b = hcount[6];
				end
				 
	    end 
		 		 
	  else // Outside the VGA screen
	    begin
	       r = 1'b0;
	       g = 1'b0;
	       b = 1'b0;
	    end // else: !if(video_on_v & video_on_h)
	  
	  
       end // else: !if(~ar)
		 
   
   
	always @(negedge ar or posedge CLOCK_50)
     if(~ar)
			clk = 1'b0;
		else
			clk = ~clk;
		
	assign VGA_CLK = clk;
	
   // Generate the hcount & hsync

   always @(negedge ar or posedge clk)
     if(~ar)
       begin
	  hcount = 10'b0;
	  video_on_h  = 1'b0;
       end
   
     else
       begin
	  if(hcount >= h_max)
	    hcount = 10'b0;
	  else
	    hcount = hcount + 1;

	  
	  if(hcount <= 755 && hcount >= 659)
	    hsync = 1'b0;
	  else
	    hsync = 1'b1;

	  
	  if(hcount <= 639)
	    video_on_h = 1'b1;
	  else
	    video_on_h = 1'b0;

       end // else: !if(~ar)
   
  

   always @(negedge ar or posedge clk)
     if(~ar)
       begin
	  vcount = 10'b0;
	  video_on_v  = 1'b0;
       end
   
     else
       begin
	  if(vcount >= v_max)
	    vcount = 10'b0;
	  else
         if(hcount == 10'd699)
     	    vcount = vcount + 1;
	  
	      
	  if(vcount <= 494 && vcount >= 493)
	    vsync = 1'b0;
	  else
	    vsync = 1'b1;

	  
	  if(vcount <= 479)
	    video_on_v = 1'b1;
	  else
	    video_on_v = 1'b0;

       end // else: !if(~ar)
   



endmodule // vga
