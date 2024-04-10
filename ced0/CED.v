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
  reg  [3:0]  read0_cnt;
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
  wire write_done;
  //

  // logic
  assign read0_done = (read0_cnt==4'd10);
  assign read1_done = (read1_cnt==3'd6);
  assign read2_done = (read2_cnt==4'd12);
  assign layer0_done = (top_cs==LAYER0 && row_cnt==8'd126);
  assign layer1_done = (top_cs==LAYER1 && row_cnt==8'd126);
  assign layer2_done = (top_cs==LAYER2 && row_cnt==8'd126);
  assign read_enable = (crd_ang_0||crd_mag_0);
  assign boundary = (boundary0 & column_cnt!=0);
  assign read_done = (read0_done||read1_done||read2_done);
  assign jump_to_write0 = (read2_cnt==3 && hys_data>=13'd100); // 如果current pixel>=100，直接跳WRITE state
  assign jump_to_write1 = (read2_cnt==3 && hys_data<13'd50);   // 如果current pixel<50，直接跳WRITE state
  assign jump_to_write2 = (read2_cnt>=4 && read2_cnt<=12 && hys_data>=13'd100);   // 如果pixel around the current pixel>=100，直接跳WRITE state
  assign jump_to_write  = (jump_to_write0||jump_to_write1||jump_to_write2);
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
    crd1 = 0;
    cwr2 = 0;
    if (top_cs==LAYER2) begin
      case (inner_cs)
        READ:
          begin
            crd1 = 1;
          end
        EXECUTE:
          begin

          end
        WRITE:
          begin
            cwr2 = 1;
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
      end else if (column_cnt!=8'd125 && inner_cs==WRITE) begin // 如果寫(column_cnt!=8'd125 && cwr_mag_0)的話在其他top-level的state不能用，因為cwr_mag_0只有在layer0才有，所以要改成inner_cs==WRITE才可以在每一個top-level的state使用
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
  wire [3:0] read0_cnt_up;
  assign read0_cnt_up = read0_cnt+1;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      read0_cnt <= 0;
    end else begin
      if (ird && read0_cnt!=4'd10) begin
        read0_cnt <= read0_cnt_up;
      end else if (ird && read0_cnt==4'd10) begin
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
      if (read0_cnt==4'd8 && column_cnt!=8'd125) begin
        p0_addr <= p0_addr_cnt_up;
      end else if (read0_cnt==4'd8 && column_cnt==8'd125) begin
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
  reg  [9:0] idata_buffer_x; // 不能 define reg [8:0] idata_buffer_x, 必須[9:0]多一個signed-bit
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
  reg  [9:0] idata_buffer_y; // 不能 define reg [8:0] idata_buffer_y, 必須[9:0]多一個signed-bit

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
  wire [12:0] gx_pixel_sum; // 每次的idata跟上次存進gx_pixel的值的加總，加完存進gx_pixel，下一次再把idata跟gx_pixel抓出來做加總
  assign gx_pixel_sum = $signed(gx_pixel)+$signed(idata_buffer_x);

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      gx_pixel <= 0;
    end else begin
      if (read0_cnt>=4'd3) begin
        gx_pixel <= gx_pixel_sum;
      end else begin
        gx_pixel <= 0;
      end
    end
  end
  //

  // gy conv
  wire [12:0] gy_pixel_sum; // gy_pixel的加總
  assign gy_pixel_sum = $signed(gy_pixel)+$signed(idata_buffer_y);

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      gy_pixel <= 0;
    end else begin
      if (read0_cnt>=4'd3) begin
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

  // mag0 address
  always @(*) begin
    cdata_mag_wr0 = mag0;
  end

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

  // (gy<<16)/gx
  reg  [28:0] temp_result;
  reg  [12:0] ang;
  wire [28:0] gy_pixel_sum_shf16 = gy_pixel_sum<<16;

  always @(*) begin
    temp_result = $signed(gy_pixel_sum_shf16)/$signed(gx_pixel_sum);
  end

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      ang <= 13'd0;
    end else begin
      if (gy_pixel_sum==0 && gx_pixel_sum==0) begin
        ang <= 13'd0;
      end else begin
        if (gy_pixel_sum!=0 && gx_pixel_sum==0) begin
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

  // done
  assign done = layer2_done;
  //

endmodule