`timescale 1ns / 1ps
`default_nettype none

	module stream_combine #
	(
		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 16,

		// Parameters of Axi Slave Bus Interface S01_AXIS
		parameter integer C_S01_AXIS_TDATA_WIDTH	= 16,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,

        // Parameters of counter
        parameter integer LARGE_COUNT_BITS          = 18,
        parameter integer SMALL_COUNT_BITS          = 16
	)
	(
		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Slave Bus Interface S01_AXIS
		input wire  s01_axis_aclk,
		input wire  s01_axis_aresetn,
		output logic  s01_axis_tready,
		input wire [C_S01_AXIS_TDATA_WIDTH-1 : 0] s01_axis_tdata,
		input wire [(C_S01_AXIS_TDATA_WIDTH/8)-1 : 0] s01_axis_tstrb,
		input wire  s01_axis_tlast,
		input wire  s01_axis_tvalid,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output logic  m00_axis_tvalid,
		output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output logic  m00_axis_tlast,
		input wire  m00_axis_tready,

        // debugging IO
        input wire [3:0] switches,
        output logic [3:0] leds
	);

    logic [LARGE_COUNT_BITS - 1: 0] counter;

    initial begin
        counter = 0;
    end

	// Add user logic here
    assign s00_axis_tready = (m00_axis_tready);
    assign s01_axis_tready = (m00_axis_tready);
    assign m00_axis_tstrb  = 4'hF;


    always_ff @(posedge s00_axis_aclk ) begin
        if (~s00_axis_aresetn) begin
            m00_axis_tvalid <= 0;
            m00_axis_tdata <= 0;
            m00_axis_tlast <= 0;
            counter <= 0;
        end
        else begin
            m00_axis_tvalid <= (s00_axis_tvalid && s01_axis_tvalid);
            // tlast case
            case(switches)
                0: begin
                    m00_axis_tlast <= (counter == (262144 - 1));
                    counter <= counter + 1; // overflow takes care of clearing counter
                end
                default begin
                    if (counter == (65536 - 1)) begin
                        m00_axis_tlast <= 1;
                        counter <= 0;
                    end
                    else begin
                        m00_axis_tlast <= 0;
                        counter <= counter + 1;
                    end
                end
            endcase
            m00_axis_tdata <= {s00_axis_tdata, s01_axis_tdata}; 
        end
    end

	// User logic ends

	endmodule
`default_nettype wire