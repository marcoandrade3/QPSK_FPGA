
`timescale 1 ns / 1 ps

	module packet_reader #
	(
		// Users to add parameters here

		// User parameters ends
		

		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_START_COUNT	= 32,
        parameter integer BRAM_BITDEPTH             = 5,
        parameter integer BRAM_BITWIDTH             = 32
	)
	(
		// Users to add ports here

		// User ports ends
        // Ports of BRAM
        output wire [BRAM_BITDEPTH - 1: 0] bram_addr,
        output wire bram_wea,
        output wire [BRAM_BITWIDTH - 1: 0] bram_dina,
        // we are actually never reading from the bram
        // input logic [BRAM_BITWIDTH - 1: 0] bram_douta

        // Input Registers
        input wire [31:0] allowed_error,
        input wire [31:0] allowed_phase_diff, // MUST BE IN FORM 64*value in radians
        input wire [31:0] expected_phase_diff,  // MUST BE IN FORM 64*value in radians
        input wire [31:0] allowed_calculated_phase_diff, // MUST BE IN FORM 64*value in radians
        input wire [31:0] num_samples,
        input wire [31:0] data_len,

        // Inout for Get Phase
        output wire [63:0] phase_tdata, 
        output wire get_phase_s00_valid, 
        input wire get_phase_m00_valid,
        input wire [31:0] phase,
        input wire get_phase_ready,

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
		input wire  m00_axis_tready,
		
		// debug ports
		output wire [2: 0] led
	);
// Instantiation of Axi Bus Interface S00_AXIS
	packet_reader_imp # ( 
		.C_S00_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
        .BRAM_BITDEPTH(32),
        .BRAM_BITWIDTH(2)
	) mud (
	   // AXIS ports
		.s00_axis_aclk(s00_axis_aclk),
		.s00_axis_aresetn(s00_axis_aresetn),
		.s00_axis_tready(s00_axis_tready),
		.s00_axis_tdata(s00_axis_tdata),
		.s00_axis_tstrb(s00_axis_tstrb),
		.s00_axis_tlast(s00_axis_tlast),
		.s00_axis_tvalid(s00_axis_tvalid),
        .m00_axis_aclk(m00_axis_aclk),
		.m00_axis_aresetn(m00_axis_aresetn),
		.m00_axis_tvalid(m00_axis_tvalid),
		.m00_axis_tdata(m00_axis_tdata),
		.m00_axis_tstrb(m00_axis_tstrb),
		.m00_axis_tlast(m00_axis_tlast),
		.m00_axis_tready(m00_axis_tready),
       
       // BRAM ports
       .bram_addr(bram_addr),
       .bram_wea(bram_wea),
       .bram_dina(bram_dina),
       
       // Input Registers
        .allowed_error(allowed_error),
        .allowed_phase_diff(allowed_phase_diff), // MUST BE IN FORM 64*value in radians
        .expected_phase_diff(expected_phase_diff),  // MUST BE IN FORM 64*value in radians
        .allowed_calculated_phase_diff(allowed_calculated_phase_diff), // MUST BE IN FORM 64*value in radians
        .num_samples(num_samples),
        .data_len(data_len),
        
        // Input for Get Phase
        .phase_tdata(phase_tdata), 
        .get_phase_s00_valid(get_phase_s00_valid), 
        .get_phase_m00_valid(get_phase_m00_valid),
        .phase(get_phase_m00_valid),
        .get_phase_ready(get_phase_ready),
        
        // debug port
        .led(led)
	);

	// Add user logic here

	// User logic ends

	endmodule
