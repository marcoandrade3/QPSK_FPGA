
`timescale 1 ns / 1 ps

	module bram_rotater #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXIS
//		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line
        input wire clk,
        input wire rst,
        input wire [32 - 1: 0] data_from_BRAM,
        output wire [$clog2(32) - 1:0] addr,
        output wire [32 - 1:0] data_processed,
        output wire valid, 
        output wire tlast
//		// Ports of Axi Slave Bus Interface S00_AXIS
//		input wire  s00_axis_aclk,
//		input wire  s00_axis_aresetn,
//		output wire  s00_axis_tready,
//		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
//		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
//		input wire  s00_axis_tlast,
//		input wire  s00_axis_tvalid
	);
// Instantiation of Axi Bus Interface S00_AXIS
	bram_rotater_imp # ( 
		.BRAM_WIDTH(32),
		.BRAM_DATA_WIDTH(32)
	) imp (
		.clk(clk),
		.rst(rst),
		.data_from_BRAM(data_from_BRAM),
		.addr(addr),
		.data_processed(data_processed),
		.valid(valid),
		.tlast(tlast)
	);

	// Add user logic here

	// User logic ends

	endmodule
