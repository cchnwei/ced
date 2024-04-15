`timescale 1ns/10ps

module  CED(
  input  clk,
  input  rst,
  input  enable,
  output reg ird,
  input  [7:0] idata,	
  output reg [13:0] iaddr,
  output reg cwr_mag_0,
  output reg [12:0] cdata_mag_wr0,
  output reg crd_mag_0,
  input  [12:0] cdata_mag_rd0,
  output reg [13:0] caddr_mag_0,
  output reg cwr_ang_0,
  output reg [12:0] cdata_ang_wr0,
  output reg crd_ang_0,
  input  [12:0] cdata_ang_rd0,
  output reg [13:0] caddr_ang_0,
  output reg cwr1,
  output reg [12:0] cdata_wr1,
  output reg crd1,
  input  [12:0] cdata_rd1,
  output reg [13:0] caddr_1,
  output reg cwr2,
  output reg [12:0] cdata_wr2,
  output reg [13:0] caddr_2,
  output done
);

  // top-level state
  parameter INITIAL = 2'd0;
  parameter LAYER0  = 2'd1;
  parameter LAYER1  = 2'd2;
  parameter LAYER2  = 2'd3;
  //

  // inner state
  parameter READ    = 2'd0;
  parameter EXECUTE = 2'd1;
  parameter WRITE   = 2'd2;
  //

  // define reg or wire
  reg  [2:0]  top_cs;
  reg  [2:0]  top_ns;
  reg  [2:0]  inner_cs;
  reg  [2:0]  inner_ns;
  reg  [13:0] p0_addr; // layer0
  reg  [13:0] p1_addr; // layer1
  reg  [12:0] gx_pixel;
  reg  [12:0] gy_pixel;
  reg  [5:0]  read0_cnt;
  reg  [2:0]  read1_cnt;
  reg  [3:0]  read2_cnt;
  reg  [7:0]  row_cnt;
  reg  [7:0]  column_cnt;
  reg         boundary0;
  wire        boundary;
  reg  [12:0] hys_data;
  wire        read_enable;
  wire        jump_to_write;
  wire        jump_to_write0;
  wire        jump_to_write1;
  wire        jump_to_write2;
  //

  // done
  wire layer0_done;
  wire layer1_done;
  wire layer2_done;
  wire read0_done;
  wire read1_done;
  wire read2_done;
  wire read_done;
  //

  // logic
  assign read0_done = (read0_cnt==6'd41);
  assign read1_done = (read1_cnt==3'd6);
  assign read2_done = (read2_cnt==4'd12);
  assign layer0_done = (top_cs==LAYER0 && row_cnt==8'd126);
  assign layer1_done = (top_cs==LAYER1 && row_cnt==8'd126);
  assign layer2_done = (top_cs==LAYER2 && row_cnt==8'd126);
  assign read_enable = (crd_ang_0||crd_mag_0);
  assign boundary = (boundary0 & column_cnt!=0);
  assign read_done = (read0_done||read1_done||read2_done);
  assign jump_to_write0 = (read2_cnt==3 && hys_data>=13'd100); // if current pixel>=100，jump to WRITE state
  assign jump_to_write1 = (read2_cnt==3 && hys_data<13'd50);   // if current pixel<50，jump to WRITE state
  assign jump_to_write2 = (read2_cnt>=4 && read2_cnt<=12 && hys_data>=13'd100);   // if pixel around the current pixel>=100，jump to WRITE state
  assign jump_to_write  = (jump_to_write0||jump_to_write1||jump_to_write2);
  assign done = layer2_done;
  //

  // top-level state transition
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      top_cs <= INITIAL;
    end else begin
      top_cs <= top_ns;
    end
  end

  always @(*) begin
    top_ns=top_cs;
      case (top_cs)
        INITIAL:
          begin
            if (enable) begin
              top_ns=LAYER0;
            end
          end
        LAYER0:
          begin
            if (layer0_done) begin
              top_ns=LAYER1;
            end
          end
        LAYER1:
          begin
            if (layer1_done) begin
              top_ns=LAYER2;
            end
          end
        LAYER2:
          begin

          end
      endcase
  end
  //

  // inner state transition
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      inner_cs <= READ;
    end else begin
      inner_cs <= inner_ns;
    end
  end

  always @(*) begin
    inner_ns=inner_cs;
      case (inner_cs)
        READ:
          begin
            if (boundary0||jump_to_write) begin
              inner_ns=WRITE;
            end else if (read_done) begin
              inner_ns=EXECUTE;
            end
          end
        EXECUTE:
          begin
            inner_ns=WRITE;
          end
        WRITE:
          begin
            inner_ns=READ;
            if (boundary||layer1_done) begin
              inner_ns=WRITE;
            end
          end
      endcase
  end
  //

  // layer0 control signal
  always @(*) begin
    ird=0;
    cwr_ang_0=0;
    cwr_mag_0=0;
    if (top_cs==LAYER0) begin
      case (inner_cs)
        READ:
          begin
            ird=1;
          end
        EXECUTE:
          begin
            ird=1;
          end
        WRITE:
          begin
            ird=1;
            cwr_ang_0=1;
            cwr_mag_0=1;
          end
      endcase
    end
  end
  //

  // layer1 control signal
  always @(*) begin
    cwr1=0;
    crd_ang_0=0;
    crd_mag_0=0;
    if (top_cs==LAYER1) begin
      case (inner_cs)
        READ:
          begin
            crd_ang_0=1;
            crd_mag_0=1;
          end
        EXECUTE:
          begin

          end
        WRITE:
          begin
            cwr1=1;
          end
      endcase
    end
  end
  //

  // layer2 control signal
  always @(*) begin
    crd1=0;
    cwr2=0;
    if (top_cs==LAYER2) begin
      case (inner_cs)
        READ:
          begin
            crd1=1;
          end
        EXECUTE:
          begin

          end
        WRITE:
          begin
            cwr2=1;
          end
      endcase
    end
  end
  //

  // column counter
  wire [7:0] column_cnt_up;
  assign column_cnt_up = column_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      column_cnt <= 0;
    end else begin
      if (layer1_done) begin
        column_cnt <= 0;
      end else if (column_cnt!=8'd125 && inner_cs==WRITE) begin
        column_cnt <= column_cnt_up;
      end else if (column_cnt==8'd125 && inner_cs==WRITE) begin
        column_cnt <= 0;
      end
    end
  end
  //

  // row counter
  wire [7:0] row_cnt_up;
  assign row_cnt_up = row_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      row_cnt <= 0;
    end else begin
      if (layer0_done||layer1_done) begin
        row_cnt <= 0;
      end else if (column_cnt!=8'd125 && inner_cs==WRITE) begin 
        row_cnt <= row_cnt;
      end else if (column_cnt==8'd125 && inner_cs==WRITE) begin
        row_cnt <= row_cnt_up;
      end
    end
  end
  //

  // read0 counter
  wire [5:0] read0_cnt_up;
  assign read0_cnt_up = read0_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      read0_cnt <= 0;
    end else begin
      if (ird && read0_cnt!=6'd41) begin
        read0_cnt <= read0_cnt_up;
      end else if (ird && read0_cnt==6'd41) begin
        read0_cnt <= 0;
      end
    end
  end
  //

  // read1 counter
  wire [2:0] read1_cnt_up;
  assign read1_cnt_up = read1_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      read1_cnt <= 0;
    end else begin
      if (read_enable && read1_cnt!=3'd6) begin
        read1_cnt <= read1_cnt_up;
      end else if (read_enable && read1_cnt==3'd6) begin
        read1_cnt <= 0;
      end
    end
  end
  //

  // read2 counter
  wire [3:0] read2_cnt_up;
  assign read2_cnt_up = read2_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      read2_cnt <= 0;
    end else begin
      if (jump_to_write) begin
        read2_cnt <= 0;
      end else begin
        if (crd1 && read2_cnt!=4'd12) begin
          read2_cnt <= read2_cnt_up;
        end else if (crd1 && read2_cnt==4'd12) begin
          read2_cnt <= 0;
        end
      end
    end
  end
  //

  // p0_addr
  wire [13:0] p0_addr_cnt_up; 
  wire [13:0] p0_addr_cnt_up3;
  assign p0_addr_cnt_up  = p0_addr+1;
  assign p0_addr_cnt_up3 = p0_addr+3;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      p0_addr <= 14'd129;
    end else begin
      if (read0_cnt==6'd8 && column_cnt!=8'd125) begin
        p0_addr <= p0_addr_cnt_up;
      end else if (read0_cnt==6'd8 && column_cnt==8'd125) begin
        p0_addr <= p0_addr_cnt_up3;
      end
    end
  end
  //

  // p1 address
  wire [13:0] p1_addr_cnt_up; 
  assign p1_addr_cnt_up  = p1_addr+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      p1_addr <= 14'd126;
    end else begin
      if (layer1_done) begin
        p1_addr <= 14'd126;
      end else if (top_cs>=LAYER1 && inner_cs==WRITE && row_cnt>=8'd1) begin
        p1_addr <= p1_addr_cnt_up;
      end
    end
  end
  //

  // p0 address logic
  reg  [13:0] p0_addr1; 

  always @(*) begin
    p0_addr1 = 0;
    case (read0_cnt)
      0: // p0_addr
        begin
          p0_addr1=p0_addr-14'd129;
        end
      1: // p1_addr
        begin
          p0_addr1=p0_addr-14'd128;
        end
      2: // p2_addr
        begin
          p0_addr1=p0_addr-14'd127;
        end
      3: // p3_addr
        begin
          p0_addr1=p0_addr-14'd1;
        end
      4: // p4_addr
        begin
          p0_addr1=p0_addr;
        end
      5: // p5_addr
        begin
          p0_addr1=p0_addr+14'd1;
        end
      6: // p6_addr
        begin
          p0_addr1=p0_addr+14'd127;
        end
      7: // p7_addr
        begin
          p0_addr1=p0_addr+14'd128;
        end
      8: // p8_addr
        begin
          p0_addr1=p0_addr+14'd129;
        end
    endcase
  end
  //

  // p1 address logic
  reg  [13:0] p1_addr1; 

  always @(*) begin
    p1_addr1 = p1_addr;
    case (read1_cnt)
      3:
        begin
          if (cdata_ang_rd0==13'd0) begin
            p1_addr1=p1_addr-14'd1;
          end else if (cdata_ang_rd0==13'd135) begin
            p1_addr1=p1_addr-14'd127;
          end else if (cdata_ang_rd0==13'd90) begin
            p1_addr1=p1_addr-14'd126;
          end else begin // 45
            p1_addr1=p1_addr-14'd125;
          end
        end
      4:
        begin
          if (cdata_ang_rd0==13'd0) begin
            p1_addr1=p1_addr+14'd1;
          end else if (cdata_ang_rd0==13'd135) begin
            p1_addr1=p1_addr+14'd127;
          end else if (cdata_ang_rd0==13'd90) begin
            p1_addr1=p1_addr+14'd126;
          end else begin // 45
            p1_addr1=p1_addr+14'd125;
          end
        end
    endcase
    if (hys_data>=13'd50 && hys_data<13'd100) begin
      case (read2_cnt)
        3: 
          begin
            p1_addr1=p1_addr-14'd127;
          end
        4: 
          begin
            p1_addr1=p1_addr-14'd126;
          end
        5: 
          begin
            p1_addr1=p1_addr-14'd125;
          end
        6: 
          begin
            p1_addr1=p1_addr-14'd1;
          end
        7: 
          begin
            p1_addr1=p1_addr+14'd1;
          end
        8: 
          begin
            p1_addr1=p1_addr+14'd125;
          end
        9: 
          begin
            p1_addr1=p1_addr+14'd126;
          end
        10: 
          begin
            p1_addr1=p1_addr+14'd127;
          end
      endcase
    end
  end
  //

  // iaddr
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      iaddr<=0;
    end else begin
      if (ird) begin
        case (read0_cnt)
          0:
            begin
              iaddr<=p0_addr1;
            end
          1: 
            begin
              iaddr<=p0_addr1;
            end
          2:
            begin
              iaddr<=p0_addr1;
            end
          3:
            begin
              iaddr<=p0_addr1;
            end
          4:
            begin
              iaddr<=p0_addr1;
            end
          5:
            begin
              iaddr<=p0_addr1;
            end
          6:
            begin
              iaddr<=p0_addr1;
            end
          7:
            begin
              iaddr<=p0_addr1;
            end
          8:
            begin
              iaddr<=p0_addr1;
            end 
        endcase
      end
    end
  end
  //

  // gx conv output
  reg  [9:0] idata_buffer_x; // cannot define reg [8:0] idata_buffer_x, must have one more signed-bit [9:0]
  wire [8:0] idata_mul2;
  assign idata_mul2 = idata<<1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      idata_buffer_x <= 0;
    end else begin
      if (layer0_done) begin
        idata_buffer_x <= 0;
      end else if (ird) begin
        case (read0_cnt)
          2:
            begin
              idata_buffer_x <= -idata;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b111);
            end
          3:
            begin
              idata_buffer_x <= 0;
            end
          4:
            begin
              idata_buffer_x <= idata;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b001);
            end
          5:
            begin
              idata_buffer_x <= -idata_mul2;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b110);
            end
          6:
            begin
              idata_buffer_x <= 0;
            end
          7:
            begin
              idata_buffer_x <= idata_mul2;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b010);
            end
          8:
            begin
              idata_buffer_x <= -idata;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b111);
            end
          9:
            begin
              idata_buffer_x <= 0;
            end 
          10:
            begin
              idata_buffer_x <= idata;
              // idata_buffer_x <= $signed({1'b0, idata})*$signed(3'b001);
            end 
        endcase
      end
    end
  end
  //

  // gy conv output
  reg  [9:0] idata_buffer_y; // cannot define reg [8:0] idata_buffer_y, must have one more signed-bit [9:0]

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      idata_buffer_y <= 0;
    end else begin
      if (layer0_done) begin
        idata_buffer_y <= 0;
      end else if (ird) begin
        case (read0_cnt)
          2:
            begin
              idata_buffer_y <= -idata;
            end
          3:
            begin
              idata_buffer_y <= -idata_mul2;
            end
          4:
            begin
              idata_buffer_y <= -idata;
            end
          5:
            begin
              idata_buffer_y <= 0;
            end
          6:
            begin
              idata_buffer_y <= 0;
            end
          7:
            begin
              idata_buffer_y <= 0;
            end
          8:
            begin
              idata_buffer_y <= idata;
            end
          9:
            begin
              idata_buffer_y <= idata_mul2;
            end 
          10:
            begin
              idata_buffer_y <= idata;
            end 
        endcase
      end
    end
  end
  //

  // gx conv
  wire [12:0] gx_pixel_sum; // accumulate gx_pixel
  assign gx_pixel_sum = $signed(gx_pixel)+$signed(idata_buffer_x);

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      gx_pixel <= 0;
    end else begin
      if (read0_cnt>=6'd3) begin
        gx_pixel <= gx_pixel_sum;
      end else begin
        gx_pixel <= 0;
      end
    end
  end
  //

  // gy conv
  wire [12:0] gy_pixel_sum; // accumulate gy_pixel
  assign gy_pixel_sum = $signed(gy_pixel)+$signed(idata_buffer_y);

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      gy_pixel <= 0;
    end else begin
      if (read0_cnt>=6'd3) begin
        gy_pixel <= gy_pixel_sum;
      end else begin
        gy_pixel <= 0;
      end
    end
  end
  //

  // |gx|+|gy|
  reg  [12:0] mag0;
  wire [12:0] absolute_gx;
  wire [12:0] absolute_gy;
  wire [12:0] absolute_sum;
  assign absolute_gx = (gx_pixel_sum[12]==1)?(~gx_pixel_sum)+1:gx_pixel_sum; 
  assign absolute_gy = (gy_pixel_sum[12]==1)?(~gy_pixel_sum)+1:gy_pixel_sum; 
  assign absolute_sum = absolute_gx + absolute_gy;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      mag0 <= 0;
    end else begin
      mag0 <= absolute_sum;
    end
  end
  //

  // mag0 data
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      cdata_mag_wr0 <= 0;
    end else begin
      if (read0_cnt==12) begin
        cdata_mag_wr0 <= mag0;
      end
    end
  end
  //

  // mag0 addr
  wire [13:0] caddr_mag_0_cnt_up;
  assign caddr_mag_0_cnt_up = caddr_mag_0+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      caddr_mag_0 <= 0;
    end else begin
      if (cwr_mag_0) begin
        caddr_mag_0 <= caddr_mag_0_cnt_up;
      end else if (crd_mag_0) begin
        caddr_mag_0 <= p1_addr1;
      end
    end
  end
  //

  // divider
  wire [28:0] gy_pixel_sum_shf16 = gy_pixel_sum<<16;
  wire [28:0] div_out;
  
  divider2 div(
    .clk(clk),
    .rst(rst),
    .dividend(gy_pixel_sum_shf16),
    .divisor(gx_pixel_sum),
    .read0_cnt(read0_cnt),
    .out(div_out)
  );
  //

  // temp_result
  reg  [28:0] temp_result;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      temp_result <= 0;
    end else begin
      if (read0_cnt==6'd41) begin
        temp_result <= div_out;
      end
    end
  end
  //

  // ang_is_0 &　ang_is_90
  reg ang_is_0;
  reg ang_is_90;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      ang_is_0 <= 0;
    end else begin
      if (read0_cnt==11) begin
        if (gy_pixel_sum==0 && gx_pixel_sum==0) begin
          ang_is_0 <= 1;
        end else begin
          ang_is_0 <= 0;
        end
      end
    end
  end

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      ang_is_90 <= 0;
    end else begin
      if (read0_cnt==11) begin
        if (gy_pixel_sum!=0 && gx_pixel_sum==0) begin
          ang_is_90 <= 1;
        end else begin
          ang_is_90 <= 0;
        end
      end
    end
  end
  //

  // ang
  reg  [12:0] ang;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      ang <= 13'd0;
    end else begin
      if (ang_is_0) begin
        ang <= 13'd0;
      end else if (ang_is_90) begin
        ang <= 13'd90;
      end else begin
        if ($signed(temp_result)<$signed(29'h00006A09)&&$signed(temp_result)>$signed(29'h1FFF95F7)) begin
          ang <= 13'd0;
        end else if ($signed(temp_result)>$signed(29'h00006A09)&&$signed(temp_result)<$signed(29'h00026A09)) begin
          ang <= 13'd45;
        end else if ($signed(temp_result)>$signed(29'h00026A09)||$signed(temp_result)<$signed(29'h1FFD95F7)) begin
          ang <= 13'd90;
        end else if ($signed(temp_result)<$signed(29'h1FFF95F7)&&$signed(temp_result)>$signed(29'h1FFD95F7)) begin
          ang <= 13'd135;
        end
      end
    end
  end
  //

  // ang address
  always @(*) begin
    cdata_ang_wr0 = ang;
  end

  wire [13:0] caddr_ang_0_cnt_up;
  assign caddr_ang_0_cnt_up = caddr_ang_0+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      caddr_ang_0 <= 0;
    end else begin
      if (cwr_ang_0) begin
        caddr_ang_0 <= caddr_ang_0_cnt_up;
      end else if (crd_ang_0) begin
        caddr_ang_0 <= p1_addr;
      end
    end
  end
  //

  // read data from L0_mag ram
  reg [12:0] mag1_0;
  reg [12:0] mag1_1;
  reg [12:0] mag1_2;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      mag1_0 <= 0;
    end else begin
      if (read1_cnt==3'd4) begin
        mag1_0 <= cdata_mag_rd0;
      end
    end
  end

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      mag1_1 <= 0;
    end else begin
      if (read1_cnt==3'd5) begin
        mag1_1 <= cdata_mag_rd0;
      end
    end
  end

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      mag1_2 <= 0;
    end else begin
      if (read1_cnt==3'd6) begin
        mag1_2 <= cdata_mag_rd0;
      end
    end
  end
  //

  // detect boundary0 
  always @(*) begin
    boundary0 = 0;
    if (top_cs>=LAYER1) begin
      if (row_cnt==0||row_cnt==8'd125||column_cnt==0||column_cnt==8'd125) begin
        boundary0 = 1;
      end
    end
  end
  //

  // write data to L1_RAM
  always @(*) begin
    cdata_wr1 = 0;
    if (boundary0) begin
      cdata_wr1 = 0;
    end else begin
      if (mag1_0>=mag1_1 && mag1_0>=mag1_2) begin
        cdata_wr1 = mag1_0;
      end
    end
  end
  //

  // address for L1_RAM
  wire [13:0] caddr_1_cnt_up;
  assign caddr_1_cnt_up = caddr_1+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      caddr_1 <= 0;
    end else begin
      if (cwr1) begin
        caddr_1 <= caddr_1_cnt_up;
      end else if (crd1) begin
        caddr_1 <= p1_addr1;
      end 
    end
  end
  //

  // read data from L1_RAM
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      hys_data <= 0;
    end else begin
      if (read2_cnt>=3'd2) begin
        if (cdata_rd1>=hys_data) begin
          hys_data <= cdata_rd1;
        end
      end else if (read2_cnt==3'd1) begin
        hys_data <= 0;
      end
    end
  end
  // 

  // write data to L2_RAM
  always @(*) begin
    cdata_wr2 = 0;
    if (boundary0) begin
      cdata_wr2 = 0;
    end else begin
      if (hys_data>=13'd100) begin
        cdata_wr2 = 13'd255;
      end else if (hys_data<13'd50) begin
        cdata_wr2 = 0;
      end 
    end
  end
  //

  // address for L2_RAM
  wire [13:0] caddr_2_cnt_up;
  assign caddr_2_cnt_up = caddr_2+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      caddr_2 <= 0;
    end else begin
      if (cwr2) begin
        caddr_2 <= caddr_2_cnt_up;
      end
    end
  end
  //

endmodule

module divider2 (
  input                clk,
  input                rst,
  input      [28:0]    dividend,  // gy
  input      [12:0]    divisor,   // gx
  input      [5:0]     read0_cnt,
  output reg [28:0]    out
);

  // state
  parameter S0  = 0;
  parameter S1  = 1;
  parameter S2  = 2;
  parameter S3  = 3;
  parameter S4  = 4;
  parameter S5  = 5;
  parameter S6  = 6;
  parameter S7  = 7;
  parameter S8  = 8;
  parameter S9  = 9;
  parameter S10 = 10;
  parameter S11 = 11;
  parameter S12 = 12;
  parameter S13 = 13;
  parameter S14 = 14;
  parameter S15 = 15;
  parameter S16 = 16;
  parameter S17 = 17;
  parameter S18 = 18;
  parameter S19 = 19;
  parameter S20 = 20;
  parameter S21 = 21;
  parameter S22 = 22;
  parameter S23 = 23;
  parameter S24 = 24;
  parameter S25 = 25;
  parameter S26 = 26;
  parameter S27 = 27;
  parameter S28 = 28;
  //

  // define reg or wire
  reg [4:0]  div_cs;
  reg [4:0]  div_ns;
  reg        sign;
  reg [28:0] udividend; // unsigned dividend
  reg [12:0] udivisor;  // unsigned divisor
  reg [13:0] udividend_reg;
  reg [28:0] merchant;
  reg [12:0] remainder;
  //

  // state transition
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      div_cs <= S0;
    end else begin
      if (read0_cnt>=12 && read0_cnt<41) begin
        div_cs <= div_ns;
      end else begin
        div_cs <= S0;
      end
    end
  end

  always @(*) begin
    div_ns = div_cs;
    case (div_cs)
      S0:
        begin
          div_ns = S1;
        end
      S1:
        begin
          div_ns = S2;
        end
      S2:
        begin
          div_ns = S3;
        end
      S3:
        begin
          div_ns = S4;
        end
      S4:
        begin
          div_ns = S5;
        end
      S5:
        begin
          div_ns = S6;
        end
      S6:
        begin
          div_ns = S7;
        end
      S7:
        begin
          div_ns = S8;
        end
      S8:
        begin
          div_ns = S9;
        end
      S9:
        begin
          div_ns = S10;
        end
      S10:
        begin
          div_ns = S11;
        end
      S11:
        begin
          div_ns = S12;
        end
      S12:
        begin
          div_ns = S13;
        end
      S13:
        begin
          div_ns = S14;
        end
      S14:
        begin
          div_ns = S15;
        end
      S15:
        begin
          div_ns = S16;
        end
      S16:
        begin
          div_ns = S17;
        end
      S17:
        begin
          div_ns = S18;
        end
      S18:
        begin
          div_ns = S19;
        end
      S19:
        begin
          div_ns = S20;
        end
      S20:
        begin
          div_ns = S21;
        end
      S21:
        begin
          div_ns = S22;
        end
      S22:
        begin
          div_ns = S23;
        end
      S23:
        begin
          div_ns = S24;
        end
      S24:
        begin
          div_ns = S25;
        end
      S25:
        begin
          div_ns = S26;
        end
      S26:
        begin
          div_ns = S27;
        end
      S27:
        begin
          div_ns = S28;
        end
      S28:
        begin
          div_ns = S0;
        end
    endcase
  end
  //

  // convert to positive value
  reg [28:0] udividend0;
  reg [12:0] udivisor0;

  always @(*) begin
    udividend0 = (dividend[28]==1) ? ~(dividend)+1 : dividend;
    udivisor0 = (divisor[12]==1)  ? ~(divisor)+1  : divisor;  
  end

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      udividend <= 0;
      udivisor  <= 0;
    end else begin
      if (read0_cnt==11) begin
        udividend <= udividend0;
        udivisor  <= udivisor0;
      end
    end
  end
  //

  // udividend_reg
  always @(*) begin
    udividend_reg = 0;
    case (div_cs)
      S0:
        begin
          udividend_reg = udividend[28];
        end
      S1:
        begin
          udividend_reg = {remainder, udividend[27]};
        end
      S2:
        begin
          udividend_reg = {remainder, udividend[26]};
        end
      S3:
        begin
          udividend_reg = {remainder, udividend[25]};
        end
      S4:
        begin
          udividend_reg = {remainder, udividend[24]};
        end
      S5:
        begin
          udividend_reg = {remainder, udividend[23]};
        end
      S6:
        begin
          udividend_reg = {remainder, udividend[22]};
        end
      S7:
        begin
          udividend_reg = {remainder, udividend[21]};
        end
      S8:
        begin
          udividend_reg = {remainder, udividend[20]};
        end
      S9:
        begin
          udividend_reg = {remainder, udividend[19]};
        end
      S10:
        begin
          udividend_reg = {remainder, udividend[18]};
        end
      S11:
        begin
          udividend_reg = {remainder, udividend[17]};
        end
      S12:
        begin
          udividend_reg = {remainder, udividend[16]};
        end
      S13:
        begin
          udividend_reg = {remainder, udividend[15]};
        end
      S14:
        begin
          udividend_reg = {remainder, udividend[14]};
        end
      S15:
        begin
          udividend_reg = {remainder, udividend[13]};
        end
      S16:
        begin
          udividend_reg = {remainder, udividend[12]};
        end
      S17:
        begin
          udividend_reg = {remainder, udividend[11]};
        end
      S18:
        begin
          udividend_reg = {remainder, udividend[10]};
        end
      S19:
        begin
          udividend_reg = {remainder, udividend[9]};
        end
      S20:
        begin
          udividend_reg = {remainder, udividend[8]};
        end
      S21:
        begin
          udividend_reg = {remainder, udividend[7]};
        end
      S22:
        begin
          udividend_reg = {remainder, udividend[6]};
        end
      S23:
        begin
          udividend_reg = {remainder, udividend[5]};
        end
      S24:
        begin
          udividend_reg = {remainder, udividend[4]};
        end
      S25:
        begin
          udividend_reg = {remainder, udividend[3]};
        end
      S26:
        begin
          udividend_reg = {remainder, udividend[2]};
        end
      S27:
        begin
          udividend_reg = {remainder, udividend[1]};
        end
      S28:
        begin
          udividend_reg = {remainder, udividend[0]};
        end
    endcase
  end
  //

  // merchant
  wire [28:0] merchant_shf;
  wire [28:0] merchant_shf_up;
  assign merchant_shf = (merchant<<1);
  assign merchant_shf_up = (merchant<<1)+1;


  always @(posedge clk, posedge rst) begin
    if (rst) begin
      merchant <= 0;
    end else begin
      if (read0_cnt==41) begin
        merchant <= 0;
      end else begin
        if (udividend_reg>=udivisor && read0_cnt>=12) begin
          merchant <= merchant_shf_up;  // merchant is 1
        end else begin
          merchant <= merchant_shf;     // merchant is 0
        end
      end
    end
  end
  //

  // remainder
  wire [12:0] remainder0;
  assign remainder0 = udividend_reg-udivisor;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      remainder <= 0;
    end else begin
      remainder <= udividend_reg;
      if (udividend_reg>=udivisor) begin
        remainder <= remainder0; // find the remainder
      end
    end
  end
  //

  // sign
  wire sign_bit = dividend[28]^divisor[12];

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      sign <= 0;
    end else begin
      if (read0_cnt==11) begin
        sign <= sign_bit;
      end
    end
  end
  //

  // output
  always @(*) begin
    out = (sign==1) ? (~merchant)+1 : merchant;
  end
  //

endmodule