/*
*
SIGNED OPERATIONSSSSSSSSSSSSSSSSSS
a * b = |a||b|cos(theta)
need
arccos((a * b)/(|a||b|))
- need magnitude calculator
- need divider
*/


module get_phase #
	(
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 64,
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
	)
	(
    // ports of arccos LUT
    output logic [5:0] arccos_domain,
    input logic [16:0] arccos_range,

    // Ports of cordic square root
		output logic  cordic_in_a_tvalid,
		output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_a_input,

    output logic  cordic_in_b_tvalid,
		output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_b_input,

    input logic cordic_a_out_tvalid;
    input logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_a_out_tdata; 

    input logic cordic_b_out_tvalid;
    input logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_b_out_tdata; 

    // Ports of divider
    output logic signed [C_M00_AXIS_TDATA_WIDTH - 1: 0] divider_divisor,
    output logic signed [C_M00_AXIS_TDATA_WIDTH - 1 + 5: 0] divider_dividend, // plus 5 because we are shifting left by 5
    output logic divider_tvalid;

    input logic divider_out_tvalid;
    input logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] divider_out_tdata; 

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk, s00_axis_aresetn,
		input wire  s00_axis_tlast, s00_axis_tvalid,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1: 0] s00_axis_tstrb,
		output logic  s00_axis_tready,
 
		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk, m00_axis_aresetn,
		input wire  m00_axis_tready,
		output logic  m00_axis_tvalid, m00_axis_tlast,
		output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb
	);
 

  logic [31:0] a, b;
  logic [15:0] a_mag, b_mag;
  logic a_mag_done, b_mag_done;


  logic signed [15:0] a_I, a_Q, b_I, b_Q;
  assign a_I = $signed(a[31:16]);
  assign a_Q = $signed(a[15:0]);
  assign b_I = $signed(b[31:16]);
  assign b_Q = $signed(b[15:0]);
  arcos_lut lut_1(.domain(arccos_domain), .range(arccos_range));

  enum {IDLE, START_MAGNITUDE, WAIT_MAGNITUDE, START_DIVIDE, WAIT_DIVIDE, ARCCOS} state;
  always_ff @(posedge s00_axis_aclk) begin
    if (~s00_axis_aresetn) begin
      s00_axis_tready <= 1;
      state <= IDLE;
      cordic_in_a_tvalid <= 0;
      cordic_in_b_tvalid <= 0;
      b_mag <= 0;
      a_mag_done <= 0;
      b_mag_done <= 0;
      divider_tvalid <= 0;
      m00_axis_tvalid <= 0;
    end else begin
      case (state)
        IDLE: begin
            m00_axis_tvalid <= 0;
            s00_axis_tready <= 1;
            cordic_in_a_tvalid <= 0;
            cordic_in_b_tvalid <= 0;
            b_mag <= 0;
            a_mag_done <= 0;
            b_mag_done <= 0;
            divider_tvalid <= 0;
          if (s00_axis_tvalid) begin
            a <= s00_axis_tdata[63: 32];
            b <= s00_axis_tdata[31: 0];
            state <= START_MAGNITUDE;
            s00_axis_tready <= 0;
          end
        end
        START_MAGNITUDE: begin
          cordic_a_input <= a_I*a_I + a_Q*a_Q; // watch out for timing 
          cordic_b_input <= b_I*b_I + b_Q*b_Q;
          cordic_in_a_tvalid <= 1;
          cordic_in_b_tvalid <= 1;
          state <= WAIT_MAGNITUDE;
        end
        WAIT_MAGNITUDE: begin
          cordic_in_a_tvalid <= 0;
          cordic_in_b_tvalid <= 0;
          if (cordic_a_out_tvalid) begin 
            a_mag <= cordic_a_out_tdata;
            a_mag_done <= 1;
          end 
          if (cordic_b_out_tvalid) begin 
            b_mag <= cordic_b_out_tdata;
            b_mag_done <= 1;
          end 
          state <= (a_mag_done && b_mag_done)? START_DIVIDE : WAIT_MAGNITUDE; 
        end
        START_DIVIDE: begin 
          divider_dividend <=  (a_I*b_I + a_Q*b_Q) <<< 5; // left shift by 5 to multiply by 32 for arccos LUT purposes (32 bit output shifted left into a 37 bit?)
          divider_divisor <= a_mag * b_mag;
          divider_tvalid <= 1;
          state <= WAIT_DIVIDE;
        end 
        WAIT_DIVIDE: begin 
          divider_tvalid <= 0;
          state <= (divider_out_tvalid)? ARCCOS : WAIT_DIVIDE; 
          arccos_domain <= $unsigned(divider_out_tdata + 32); // should be in range [0, 63]
        end 
        ARCCOS: begin 
          m00_axis_tvalid <= 1; 
          m00_axis_tdata <= arccos_range;
          state <= IDLE;
          s00_axis_tready <= 1;
        end 
      endcase
    end
  end

endmodule




//6bit acos lookup, 8bit depth
// domain [-1, 1] split into 64 samples (thus its [-32, 32] roughly)
// range is 64*[pi, 0]
module arcos_lut(input wire [5:0] domain, output logic[15:0] range);
    always_comb begin
        case(domain)
        6'd0: range<=201;
        6'd1: range<=185;
        6'd2: range<=178;
        6'd3: range<=173;
        6'd4: range<=168;
        6'd5: range<=164;
        6'd6: range<=161;
        6'd7: range<=157;
        6'd8: range<=154;
        6'd9: range<=151;
        6'd10: range<=149;
        6'd11: range<=146;
        6'd12: range<=143;
        6'd13: range<=141;
        6'd14: range<=138;
        6'd15: range<=136;
        6'd16: range<=134;
        6'd17: range<=131;
        6'd18: range<=129;
        6'd19: range<=127;
        6'd20: range<=125;
        6'd21: range<=122;
        6'd22: range<=120;
        6'd23: range<=118;
        6'd24: range<=116;
        6'd25: range<=114;
        6'd26: range<=112;
        6'd27: range<=110;
        6'd28: range<=108;
        6'd29: range<=106;
        6'd30: range<=104;
        6'd31: range<=102;
        6'd32: range<=100;
        6'd33: range<=98;
        6'd34: range<=96;
        6'd35: range<=94;
        6'd36: range<=92;
        6'd37: range<=90;
        6'd38: range<=88;
        6'd39: range<=86;
        6'd40: range<=84;
        6'd41: range<=82;
        6'd42: range<=80;
        6'd43: range<=78;
        6'd44: range<=75;
        6'd45: range<=73;
        6'd46: range<=71;
        6'd47: range<=69;
        6'd48: range<=67;
        6'd49: range<=64;
        6'd50: range<=62;
        6'd51: range<=59;
        6'd52: range<=57;
        6'd53: range<=54;
        6'd54: range<=52;
        6'd55: range<=49;
        6'd56: range<=46;
        6'd57: range<=43;
        6'd58: range<=39;
        6'd59: range<=36;
        6'd60: range<=32;
        6'd61: range<=27;
        6'd62: range<=22;
        6'd63: range<=16;
     endcase
    end
endmodule