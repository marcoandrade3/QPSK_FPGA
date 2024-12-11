module packet_packer_module #
	(
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
        parameter integer NUM_SAMPLES               = 100,
        parameter integer NUM_DATA                  = 64,
        parameter shortint p0_I = 32767,
        parameter shortint p0_Q = 0,
        parameter shortint p1_I = 0,
        parameter shortint p1_Q = 32767
	)
	(
        // debug ports
        output wire [2: 0] led,
		
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
        
        logic even_or_odd; 
        logic [2:0] sync_counter; 
        logic [31:0] transmission_counter; 
        logic [31:0] data_counter;
        logic [NUM_DATA - 1:0] [31:0] data_holder;
        enum {IDLE, SYNC, PAD_PRE, PACKET, PAD_POST} transmission;
        assign led = transmission;
        always_ff @(posedge s00_axis_aclk) begin
            if (~s00_axis_aresetn || ~m00_axis_aresetn) begin
                data_counter <= 0; 
                transmission <= IDLE; 
                s00_axis_tready <= 1; 
                m00_axis_tvalid <= 0; 
                transmission_counter <= 0;
                even_or_odd <= 0; 
            end else begin 
                case(transmission) 
                    IDLE: begin 
                        if (s00_axis_tvalid) begin 
                            data_counter <= data_counter + 1; 
                            data_holder[data_counter] <= s00_axis_tdata; 
                            if (data_counter == NUM_DATA -1) begin
                                transmission <= SYNC; 
                                s00_axis_tready <= 0; 
                                transmission_counter <= 0;
                                even_or_odd <= 0;
                                sync_counter <= 0;
                            end 
                        end
                        else begin
                            m00_axis_tvalid <= 0;
                        end
                    end 
                    SYNC: begin 
                        if (transmission_counter < NUM_SAMPLES - 1) begin 
                            m00_axis_tvalid <= 1; 
                            if (~even_or_odd) begin 
                                m00_axis_tdata <= {p0_I, p0_Q};
                            end else begin
                                m00_axis_tdata <= {p1_I, p1_Q};
                            end 
                            transmission_counter <= transmission_counter + 1;
                        end else if (transmission_counter == NUM_SAMPLES - 1) begin
                            if (~even_or_odd) begin 
                                m00_axis_tdata <= {p0_I, p0_Q};
                            end else begin
                                m00_axis_tdata <= {p1_I, p1_Q};
                            end 
                            transmission_counter <= 0;
                            if (sync_counter == 3) begin 
                                transmission <= PAD_PRE;
                                sync_counter <= 0;
                            end else begin 
                                even_or_odd <= ~even_or_odd;
                                sync_counter <= sync_counter + 1;
                            end 
                        end    
                    end 
                    PAD_PRE: begin
                        if (transmission_counter < NUM_SAMPLES - 1) begin 
                            m00_axis_tdata <= 0;
                            transmission_counter <= transmission_counter + 1;
                        end else if (transmission_counter == NUM_SAMPLES - 1) begin 
                            transmission_counter <= 0;
                            m00_axis_tdata <= 0;
                            if (sync_counter == 3) begin
                                transmission <= PACKET; 
                                sync_counter <= 0;
                                data_counter <= 0;
                            end else begin 
                                sync_counter <= sync_counter + 1;
                            end
                        end    
                    end
                    PACKET: begin
                        if (transmission_counter < NUM_SAMPLES -1) begin
                            m00_axis_tdata <= data_holder[data_counter]; 
                            transmission_counter <= transmission_counter + 1;
                        end else if (transmission_counter == NUM_SAMPLES - 1) begin
                            transmission_counter <= 0;
                            m00_axis_tdata <= data_holder[data_counter]; 
                            if (data_counter == NUM_DATA - 1) begin
                                transmission <= PAD_POST;
                                data_counter <= 0;
                            end else begin 
                                data_counter <= data_counter + 1;
                            end 
                        end 
                    end 
                    PAD_POST: begin
                        if (transmission_counter < NUM_SAMPLES - 1) begin 
                            m00_axis_tdata <= 0;
                            transmission_counter <= transmission_counter + 1;
                        end else if (transmission_counter == NUM_SAMPLES - 1) begin 
                            transmission_counter <= 0;
                            m00_axis_tdata <= 0;
                            if (sync_counter == 3) begin
                                transmission <= IDLE; 
                                s00_axis_tready <= 1;
                                sync_counter <= 0;
                                data_counter <= 0;
                                m00_axis_tvalid <= 0;
                            end else begin 
                                sync_counter <= sync_counter + 1;
                            end
                        end   
                    end 
                endcase 
            end 
        end
 
endmodule
 