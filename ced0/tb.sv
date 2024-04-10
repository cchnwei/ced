`timescale 1ns/10ps
`define PERIOD      10.0          	  
`define End_CYCLE  100000000             
`define PatternPATH "./pattern/"

`define size_width 128
`define size_pic `size_width*`size_width
`define offset 54
`define PatNum 2

module tb;

reg [7:0] header_126 [`offset-1:0];
reg [7:0] header_128 [`offset-1:0];
integer ofile, ifile;

reg	[12:0]	mag_exp	[0:15875];
reg	[12:0]	angle_exp	[0:15875];
reg	[12:0]	mag_mem	[0:15875];
reg	[12:0]	angle_mem	[0:15875];

reg	[12:0]	non_max_exp	[0:15875];
reg	[12:0]	non_max_mem	[0:15875];

reg	[12:0]	final_exp	[0:15875];
reg	[12:0]	final_mem	[0:15875];

reg		rst = 0;
reg		clk = 0;
reg		enable = 0;

// layer 0
wire		cwr_mag_0;
wire		crd_mag_0;
wire	[12:0]	cdata_mag_wr0;
wire	[12:0]	cdata_mag_rd0;
wire	[13:0]	caddr_mag_0;
wire		cwr_ang_0;
wire		crd_ang_0;
wire	[12:0]	cdata_ang_wr0;
wire	[12:0]	cdata_ang_rd0;
wire	[13:0]	caddr_ang_0;

// layer 1
wire		cwr1;
wire		crd1;
wire	[12:0]	cdata_wr1;
wire	[12:0]	cdata_rd1;
wire	[13:0]	caddr_1;

// layer 2
wire		cwr2;
wire	[12:0]	cdata_wr2;
wire	[13:0]	caddr_2;

wire ird;
wire	[13:0]	iaddr;
wire	[7:0]	idata;

reg [13:0] a;
integer		p0, p1, p3, p4, p2, i;
integer		err00, err01, err1, err2, pass00, pass01,  pass1, pass2, score;

integer		pat_num;

integer idx;
string s_idx, s_i;


CED CED(
			.clk(clk),
			.rst(rst),
			.done(done),	
			.enable(enable),	
			.ird(ird),
			.iaddr(iaddr),
			.idata(idata),
			.cwr_mag_0(cwr_mag_0),
			.cdata_mag_wr0(cdata_mag_wr0),
			.crd_mag_0(crd_mag_0),
			.cdata_mag_rd0(cdata_mag_rd0),
			.caddr_mag_0(caddr_mag_0),
			.cwr_ang_0(cwr_ang_0),
			.cdata_ang_wr0(cdata_ang_wr0),
			.crd_ang_0(crd_ang_0),
			.cdata_ang_rd0(cdata_ang_rd0),
			.caddr_ang_0(caddr_ang_0),
			.cwr1(cwr1),
			.caddr_1(caddr_1),
			.cdata_wr1(cdata_wr1),
			.crd1(crd1),
			.cdata_rd1(cdata_rd1),
			.cwr2(cwr2),
			.caddr_2(caddr_2),
			.cdata_wr2(cdata_wr2)
);
			
RAM_8 #(.depth(16384)) Grayscale_RAM(
  .CK(clk     ), 
  .A (iaddr ), 
  .WE(1'd0), 
  .OE(ird), 
  .D (8'd0 ), 
  .Q (idata )
);

RAM_13 #(.depth(15876)) L0_Magnitude_RAM(
  .CK(clk     ), 
  .A (caddr_mag_0 ), 
  .WE(cwr_mag_0), 
  .OE(crd_mag_0), 
  .D (cdata_mag_wr0 ), 
  .Q (cdata_mag_rd0)
);

RAM_13 #(.depth(15876)) L0_Angle_RAM(
  .CK(clk     ), 
  .A (caddr_ang_0 ), 
  .WE(cwr_ang_0), 
  .OE(crd_ang_0), 
  .D (cdata_ang_wr0 ), 
  .Q (cdata_ang_rd0)
);

RAM_13 #(.depth(15876)) L1_RAM(
  .CK(clk     ), 
  .A (caddr_1 ), 
  .WE(cwr1), 
  .OE(crd1), 
  .D (cdata_wr1 ), 
  .Q (cdata_rd1)
);

RAM_13 #(.depth(15876)) L2_RAM(
  .CK(clk     ), 
  .A (caddr_2 ), 
  .WE(cwr2), 
  .OE(1'd0), 
  .D (cdata_wr2 ), 
  .Q ()
);


always begin #(`PERIOD/2) clk = ~clk; end


initial begin
  $readmemh({`PatternPATH, "bmp_header_128.txt"} , header_128);
  $readmemh({`PatternPATH, "bmp_header_126.txt"} , header_126);
end


initial begin  // global control
	$display("********************************");
	$display("**      Simulation Start      **");
	$display("********************************");
	$display("\n");
	@(negedge clk); #1; rst = 1'b1;  
   	#(`PERIOD*3);  #1;   rst = 1'b0;
	pass00=0;
	pass01=0;
	pass1=0;
	pass2=0;
	for(idx=0;idx<`PatNum;idx++)begin
		a=14'd0;
		s_idx.itoa(idx+1);
		@(posedge clk);
		$readmemh({`PatternPATH, "pattern",s_idx,"_init.txt" },Grayscale_RAM.memory);
		$readmemh({`PatternPATH, "pattern",s_idx,"_L0_mag_golden.txt" }, mag_exp);
		$readmemh({`PatternPATH , "pattern",s_idx,"_L0_angle_golden.txt" }, angle_exp);
		$readmemh({`PatternPATH , "pattern",s_idx,"_L1_golden.txt" }, non_max_exp);
		$readmemh({`PatternPATH, "pattern",s_idx,"_L2_golden.txt" }, final_exp);
		#(`PERIOD / 2.0)enable = 1;
		#(`PERIOD)enable = 0;
		wait(done == 1);
		
		//layer 0
		err00 = 0;
		for (p1=0; p1<=15875; p1=p1+1) begin
			if (L0_Magnitude_RAM.memory[p1] == mag_exp[p1]) ;
			else begin
				err00 = err00 + 1;
				begin 
					$display("Pattern %1d, Layer 0(Mag) is wrong! output=%h, but expect=%h at Pixel %d",idx, L0_Magnitude_RAM.memory[p1], mag_exp[p1], p1);
					break;
				end
			end
		end
		if (err00 == 0) begin
			$display("Pattern %1d, Layer 0(Mag) is pass!",idx);
			pass00 = pass00 + 1;
		end
		err01 = 0;
		for (p1=0; p1<=15875; p1=p1+1) begin
			if (L0_Angle_RAM.memory[p1] == angle_exp[p1]) ;
			else begin
				err01 = err01 + 1;
				begin 
					$display("Pattern %1d, Layer 0(Ang) is wrong! output=%h, but expect=%h at Pixel %d", idx, L0_Angle_RAM.memory[p1], angle_exp[p1],p1);
					break;
				end
			end
		end
		if (err01 == 0) begin
			$display("Pattern %1d, Layer 0(Ang) is pass!",idx);
			pass01 = pass01 + 1;
		end
		// layer 1
		err1 = 0;
		for (p2=0; p2<=15875; p2=p2+1) begin
			if (L1_RAM.memory[p2] == non_max_exp[p2]) ;
			else begin
				err1 = err1 + 1;
				begin 
					$display("Pattern %1d, Layer 1      is wrong! output=%h, but expect=%h at Pixel %d",idx, L1_RAM.memory[p2], non_max_exp[p2], p2);
					break;
				end
			end
		end
		if (err1 == 0) begin
			$display("Pattern %1d, Layer 1      is pass!",idx);
			pass1 = pass1 + 1;
		end
		// layer 2
		err2 = 0;
		for (p2=0; p2<=15875; p2=p2+1) begin
			if (L2_RAM.memory[p2] == final_exp[p2]) ;
			else begin
				err2 = err2 + 1;
				begin 
					$display("Pattern %1d, Layer 2      is wrong! output=%h, but expect=%h at Pixel %d",idx, L2_RAM.memory[p2], final_exp[p2], p2);
					break;
				end
			end
		end
		if (err2 == 0) begin
			$display("Pattern %1d, Layer 2      is pass!",idx);
			pass2 = pass2 + 1;
		end
		// write data for image
		ifile = $fopen({"input_image", s_idx, ".bmp"}, "wb");
		ofile = $fopen({"your_result", s_idx, ".bmp"}, "wb");
		// write header
		for (int i = 0; i < `offset; i++) begin
			$fwrite(ifile, "%c", header_128[i]);
			$fwrite(ofile, "%c", header_126[i]);
		end
		for(int i=0;i<`size_pic;i++) begin
			automatic int y = (`size_pic-1-i) / 128;
			automatic int x = (`size_pic-1-i) % 128;
			automatic int newAddr = y * 128 + (127-x);
			for(int rgb=0;rgb<3;rgb++) begin
				$fwrite(ifile, "%c", Grayscale_RAM.memory[newAddr]);
			end
		end
		for(int i=0;i<`size_pic;i++) begin
			if (i < 128 || i >= (`size_pic-128) || i % 128 < 1 || i % 128 >= (128 - 1))begin
				for(int rgb=0;rgb<3;rgb++) begin
					$fwrite(ofile, "%c", 8'd0);
				end
			end
			else begin
				automatic int y = (126*126-1-a) / 126;
				automatic int x = (126*126-1-a) % 126;
				automatic int newAddr = y * 126 + (125-x);
				for(int rgb=0;rgb<3;rgb++) begin
					$fwrite(ofile, "%c", L2_RAM.memory[newAddr]);
				end
				a=a+14'd1;
			end
		end
		$fclose(ifile); 
		$fclose(ofile);
		if(err00==1'd0 && err01==1'd0 && err1==1'd0 && err2==1'd0) begin
			$display(" ****************************               ");
			$display(" **                        **       |\__||  ");
			$display(" **  Congratulations !!    **      / O.O  | ");
			$display(" **                        **    /_____   | ");
			$display(" **  Pattern %1d All Pass    **   /^ ^ ^ \\  |", idx);
			$display(" **                        **  |^ ^ ^ ^ |w| ");
			$display(" ****************************   \\m___m__|_|");
		end
		else begin
			 $display(" ****************************               ");
			 $display(" **                        **       |\__||  ");
			 $display(" **  OOPS!!                **      / X,X  | ");
			 $display(" **                        **    /_____   | ");
			 $display(" **  Pattern %1d Failed      **   /^ ^ ^ \\  |", idx);
			 $display(" **                        **  |^ ^ ^ ^ |w| ");
			 $display(" ****************************   \\m___m__|_|");
		end
		if(idx == 1) begin
			$display("\n");
			if(pass00==2) begin
				if(pass01==2) begin
					if(pass1==2) begin
						if(pass2==2) begin
							score=80;
						end
						else score=50;
					end
					else score=25;
				end
				else score=12;
			end
			else score=0;
			$display("Your score = %1d",score);
			$display("\n");
			$finish;
		end
		else begin
			$display("------------------------------------------------------------------------------------\n");
			resetTask();
		end
	end
end

task resetTask;
begin
  rst = 1;
  repeat(3)@(posedge clk)rst = 1;
  rst = 0;
end
endtask


initial  begin
 #`End_CYCLE ;
    $display("*************************************");
	$display("                                     ");
	$display(" OOPS, simulation can not finish...  ");
	$display("                                     ");
	$display("*************************************");
 	$finish;
end

endmodule


module RAM_8 #(parameter depth=65536)(CK, A, WE, OE, D, Q);

  input                                  CK;
  input  [$clog2(depth)-1:0]              A;
  input                                  WE;
  input                                  OE;
  input  [7:0]                            D;
  output [7:0]                            Q;

  reg    [7:0]                            Q;
  reg    [$clog2(depth)-1:0]      latched_A;
  reg    [$clog2(depth)-1:0]  latched_A_neg;
  reg    [7:0] memory           [depth-1:0];

  always @(posedge CK) begin
    if (WE) begin
      memory[A] <= D;
    end
		latched_A <= A;
  end
  
  always@(negedge CK) begin
    latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (OE) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 8'hzz;
    end
  end
  
endmodule

module RAM_13 #(parameter depth=65536)(CK, A, WE, OE, D, Q);

  input                                  CK;
  input  [$clog2(depth)-1:0]              A;
  input                                  WE;
  input                                  OE;
  input  [12:0]                            D;
  output [12:0]                            Q;

  reg    [12:0]                            Q;
  reg    [$clog2(depth)-1:0]      latched_A;
  reg    [$clog2(depth)-1:0]  latched_A_neg;
  reg    [12:0] memory           [depth-1:0];

  always @(posedge CK) begin
    if (WE) begin
      memory[A] <= D;
    end
		latched_A <= A;
  end
  
  always@(negedge CK) begin
    latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (OE) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 17'h0zzzz;
    end
  end
  
endmodule


