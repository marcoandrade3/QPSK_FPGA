
`timescale 1 ns / 1 ps

	module get_phase #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 64,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here
    
        // Ports of cordic square root
            output wire  cordic_in_a_tvalid,
            output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_a_input,
    
        output wire  cordic_in_b_tvalid,
        output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] cordic_b_input,
    
        input wire cordic_a_out_tvalid,
        input wire [16-1 : 0] cordic_a_out_tdata,
    
        input wire cordic_b_out_tvalid,
        input wire [16-1 : 0] cordic_b_out_tdata,
    
        // Ports of divider
        output wire signed [C_M00_AXIS_TDATA_WIDTH - 1: 0] divider_divisor,
        output wire signed [C_M00_AXIS_TDATA_WIDTH - 1 + 5: 0] divider_dividend, // plus 5 because we are shifting left by 5
        output wire divider_tvalid,
    
        input wire divider_out_tvalid,
        input wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] divider_out_tdata,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready
	);
// Instantiation of Axi Bus Interface S00_AXIS
	get_phase_imp # ( 
		.C_S00_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
	) imp (
	   // axi
        .m00_axis_aclk(m00_axis_aclk),
		.m00_axis_aresetn(m00_axis_aresetn),
		.m00_axis_tvalid(m00_axis_tvalid),
		.m00_axis_tdata(m00_axis_tdata),
		.m00_axis_tstrb(m00_axis_tstrb),
		.m00_axis_tlast(m00_axis_tlast),
		.m00_axis_tready(m00_axis_tready),
		.s00_axis_aclk(s00_axis_aclk),
		.s00_axis_aresetn(s00_axis_aresetn),
		.s00_axis_tready(s00_axis_tready),
		.s00_axis_tdata(s00_axis_tdata),
		.s00_axis_tstrb(s00_axis_tstrb),
		.s00_axis_tlast(s00_axis_tlast),
		.s00_axis_tvalid(s00_axis_tvalid),
      // other
        // Ports of cordic square root
        .cordic_in_a_tvalid(cordic_in_a_tvalid),
        .cordic_a_input(cordic_a_input),
    
        .cordic_in_b_tvalid(cordic_in_b_tvalid),
        .cordic_b_input(cordic_b_input),
    
        .cordic_a_out_tvalid(cordic_a_out_tvalid),
        .cordic_a_out_tdata(cordic_a_out_tdata),
    
        .cordic_b_out_tvalid(cordic_b_out_tvalid),
        .cordic_b_out_tdata(cordic_b_out_tdata),
    
        // Ports of divider
        .divider_divisor(divider_divisor),
        .divider_dividend(divider_dividend), // plus 5 because we are shifting left by 5
        .divider_tvalid(divider_tvalid),
    
        .divider_out_tvalid(divider_out_tvalid),
        .divider_out_tdata(divider_out_tdata)
	);
	// Add user logic here

	// User logic ends

	endmodule
