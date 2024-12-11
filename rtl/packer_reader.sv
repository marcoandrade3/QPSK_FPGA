/*
Design Decisions
- this will output to a BRAM
    -65k depth 2bit width for now
    - NEED A BRAM READING MODULE THAT OUTPUTS TLAST
- this will have its own DMA to interface with so that we can keep graphing the ADC's output

Potential Issues
- ADC fifo depth being exceeded due to backpressure from calculations in this module
*/


module packet_reader #
	(
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
        parameter integer BRAM_BITDEPTH             = 16,
        parameter integer BRAM_BITWIDTH             = 2,
	)
	(
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
		output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb,

        // Ports of BRAM
        output logic [BRAM_BITDEPTH - 1: 0] bram_addr,
        output logic bram_wea,
        output logic [BRAM_BITWIDTH - 1: 0] bram_dina,
        // we are actually never reading from the bram
        // input logic [BRAM_BITWIDTH - 1: 0] bram_douta

        // Input Registers
        input logic [31:0] allowed_error,
        input logic [31:0] allowed_phase_diff,
        input logic [31:0] expected_phase_diff, 
        input logic [31:0] allowed_calculated_phase_diff,
        input logic [31:0] num_samples,
        input logic [31:0] data_len,

        // Inout for Get Phase
        output logic [63:0] phase_tdata, 
        output logic get_phase_s00_valid, 
        input wire get_phase_m00_valid,
        input wire [31:0] phase
	);
    // reference
    localparam p0_I = 32767;
    localparam p0_Q = 0; 

    logic [5:0] cos_1_domain; 
    logic [5:0] cos_2_domain; 

    logic [15:0] signed cos_1_range; 
    logic [15:0] signed cos_2_range;  

    cos_lut cos_lut_1(.domain(cos_1_domain), .range(cos_1_range));
    cos_lut cos_lut_2(.domain((cos_2_domain >= 16)? cos_2_domain - 16 ? cos_2_domain - 16 + 64), .range(cos_2_range));


    enum {P0, P1, P2, P3, ZERO_COUNT, PHASE, PHASE_SIGN_CALC, PHASE_SIGN_CHECK, DATA} state;

    // sample grabbing
    logic [31:0] p0;
    logic [31:0] p1;
    logic [31:0] p2;
    logic [31:0] p3;
    logic [31:0] z;

    // counters
    logic [31:0] counter; 
    logic [31:0] zero_count;
    logic [31:0] data_count;

    // rotation intermediates
    logic signed [15:0] positive_p0_1_rot;
    logic signed [15:0] positive_p0_2_rot;
    logic signed [15:0] negative_p0_1_rot;
    logic signed [15:0] negative_p0_2_rot;

    logic signed [31:0] p0_rotated;
    logic signed [31:0] p1_rotated;

    // latches
    logic got_phase, sent_phase, pos_or_neg_phase;
    logic [31:0] latched_phase, p1_phase_latch;
    always_ff @(posedge s00_axis_aclk) begin
        if (~s00_axis_aresetn || ~m00_axis_aresetn) begin
            // bram reset
            state <= P0;
            bram_addr <= 0;
            bram_wea <= 0;
            bram_dina <= 0;

            // state machine resets 
            counter <= 0;
            zero_count <= 0;
            data_count <= 0;

            // axi reset
            s00_axis_tready <= 0;
            m00_axis_tvalid <= 0;
            m00_axis_tdata <= 0;
            m00_axis_tlast <= 0;
            m00_axis_tstrb <= 15;

            // phase
            got_phase <= 0; 
        end
        else begin
            case (state)
                P0: begin 
                    bram_wea <= 0;
                    if (counter == 0) begin
                        p0 <= s00_axis_tdata;
                        counter <= counter + 1;
                    end else if (counter == NUM_SAMPLES - 1) begin 
                        state <= P1; 
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end 
                end 
                P1: begin 
                    if (counter == 0) begin 
                        p1 <= s00_axis_tdata; 
                        phase_tdata <= {p0, s00_axis_tdata};
                        get_phase_s00_valid <= 1;
                        s00_axis_tready <= 0;
                        counter <= 1;
                    end else if (got_phase) begin 
                        if (counter == NUM_SAMPLES - 1) begin
                            got_phase <= 0; 
                            counter <= 0;
                            let diff = (p1_phase_latch > (expected_phase_diff << 6)) ? p1_phase_latch - (expected_phase_diff << 6) : (expected_phase_diff << 6) - p1_phase_latch;  
                            if (diff < allowed_calculated_phase_diff) begin 
                                state <= P2; 
                            end else begin 
                                state <= P0;
                            end 
                        end else begin 
                        counter <= counter + 1;
                        end 
                    end else begin 
                        if (get_phase_m00_valid) begin 
                            got_phase <= 1; 
                            s00_axis_tready <= 1;
                            p1_phase_latch <= phase;
                        end                         
                    end 
                end 
                P2: begin 
                    if (counter == 0) begin 
                        p2 <= s00_axis_tdata; 
                        counter <= counter + 1;
                    end else if (counter == NUM_SAMPLES - 1) begin
                        counter <= 0;
                        if (($signed(p2[31:16]) - $signed(p0[31:16]) > 0) ?  $signed(p2[31:16]) - $signed(p0[31:16])  : $signed(p0[31:16]) - $signed(p2[31:16]) < allowed_error && 
                            (($signed(p2[15:0]) - $signed(p0[15:0] )> 0) ?  $signed(p2[15:0]) - $signed(p0[15:0] ) : $signed(p0[15:0] )- $signed(p2[15:0])) < allowed_error) 
                        begin 
                            state <= P3;
                        end else begin 
                            state <= P0;
                        end 
                    end else begin 
                        counter <= counter + 1;
                    end    
                end 
                P3: begin
                    if (counter == 0) begin 
                        p3 <= s00_axis_tdata; 
                        counter <= counter + 1;
                    end else if (counter == NUM_SAMPLES - 1) begin
                        counter <= 0;
                        if ((($signed(p3[31:16]) - $signed(p0[31:16]) > 0) ?  $signed(p3[31:16]) - $signed(p0[31:16])  : $signed(p0[31:16]) - $signed(p3[31:16])) < allowed_error && 
                            (($signed(p3[15:0] )- $signed(p0[15:0] )> 0) ?  $signed(p3[15:0] )- $signed(p0[15:0] ) : $signed(p0[15:0] )- $signed(p3[15:0])) < allowed_error) 
                        begin 
                            state <= Z;
                        end else begin 
                            state <= P0;
                        end 
                    end else begin 
                        counter <= counter + 1;
                    end    
                end
                ZERO_COUNT: begin
                    if (counter == 0) begin
                        z <= s00_axis_tdata;
                        counter <= counter + 1;
                    end
                    else if (counter == NUM_SAMPLES - 1) begin
                        counter <= 0;
                        if (((($signed(z[31:16]) > 0) ?  $signed(z[31:16]): -$signed(z[31:16])) < allowed_error) && ((($signed(z[15:0]) > 0) ?  $signed(z[15:0]): -$signed(z[15:0])) < allowed_error)) begin
                            if (zero_count == 2) begin
                                // success, go into phase determination
                                state <= PHASE;
                                sent_phase <= 0;
                                s00_axis_tready <= 0; // this state is irrelevant tothe state machine
                            end
                            else begin
                                zero_count <= zero_count + 1;
                            end
                        end
                        else begin
                            state <= P0;
                            zero_count <= 0;
                        end
                    end
                    else begin
                        counter <= counter + 1;
                    end
                end
                PHASE: begin
                    if (sent_phase == 0) begin
                        phase_tdata <= {p0, {16'h7FFF, 16'h0000}};
                        get_phase_s00_valid <= 1;
                        sent_phase <= 1;
                    end else begin 
                        get_phase_s00_valid <= 0;
                        if (get_phase_m00_valid) begin
                            state <= PHASE_SIGN_CALC; // rotate points now
                            sent_phase <= 0;
                            cos_1_domain <= phase;
                            cos_2_domain <= phase;
                            latched_phase <= phase;
                        end
                    end
                end
                PHASE_SIGN_CALC: begin 
                    negative_p0_1_rot <= p0_I*cos_1_range + p0_Q * cos_2_range;
                    negative_p0_2_rot <= $signed(-1*p0_cos_2_range) + p0_Q * cos_1_range;
                    positive_p0_1_rot <= p0_I*cos_1_range - p0_Q * cos_2_range;
                    positive_p0_2_rot <= p0_I*cos_2_range + p0_Q * cos_1_range;
                    state <= PHASE_SIGN_CHECK;
                end 
                PHASE_SIGN_CHECK: begin
                    if (
                        (((negative_p0_1_rot > $signed(p0_I)) ? (negative_p0_1_rot - $signed(p0_I)) : ($signed(p0_I) - negative_p0_1_rot)) +
                        ((negative_p0_2_rot > $signed(p0_Q)) ? (negative_p0_2_rot - $signed(p0_Q)) : ($signed(p0_Q) - negative_p0_2_rot))) >
                        (((positive_p0_1_rot > $signed(p0_I)) ? (positive_p0_1_rot - $signed(p0_I)) : ($signed(p0_I) - positive_p0_1_rot)) +
                        ((positive_p0_2_rot > $signed(p0_Q)) ? (positive_p0_2_rot - $signed(p0_Q)) : ($signed(p0_Q) - positive_p0_2_rot)))
                        ) 
                    begin
                        pos_or_neg_phase <= 1; // negative has more err, this is a pos phase    
                    end else
                    begin
                        pos_or_neg_phase <= 0; // neg phase
                    end
                    state <= DATA;
                end
                DATA: begin
                    // sample data for "data_len" number of samples
                    if (counter == 0) begin
                        bram_addr <= bram_addr + 1;
                        bram_wea <= 1;
                        if (pos_or_neg_phase) begin
                            // positive phase
                            // rotate I and Q
                            bram_dina <= {($signed(s00_axis_tdata[31:16])*cos_1_range - $signed(s00_axis_tdata[15:0]) * cos_2_range), 
                                          ($signed(s00_axis_tdata[31:16])*cos_2_range + $signed(s00_axis_tdata[15:0])* cos_1_range)};             
                        end
                        else begin
                            // negative phase
                            // rotate I and Q
                            bram_dina <= {($signed(s00_axis_tdata[31:16])*cos_1_range + $signed(s00_axis_tdata[15:0]) * cos_2_range), 
                                          (-$signed(s00_axis_tdata[31:16])*cos_2_range + $signed(s00_axis_tdata[15:0])* cos_1_range)};   
                        end
                        bram_dina <= s00_axis_tdata;
                        counter <= counter + 1;
                    end
                    else if (counter == NUM_SAMPLES - 1) begin
                        counter <= 0;
                        if (data_count == data_len) begin
                            state <= P0;
                            data_count <= 0;
                        end
                        else begin
                            data_count <= data_count + 1;
                        end
                    end
                    else begin
                        counter <= counter + 1;
                    end
                end
            endcase 
        end 
    end
endmodule


//6bit cos lookup, 8bit depth
// domain [-1, 1] split into 64 samples (thus its [-32, 32] roughly)
// range is 64*[pi, 0]
module cos_lut(input wire [5:0] domain, output logic[15:0] signed range);
    always_comb begin
        case(domain)
            6'd0: range<=64;
            6'd1: range<=63;
            6'd2: range<=62;
            6'd3: range<=61;
            6'd4: range<=59;
            6'd5: range<=56;
            6'd6: range<=53;
            6'd7: range<=49;
            6'd8: range<=45;
            6'd9: range<=40;
            6'd10: range<=35;
            6'd11: range<=30;
            6'd12: range<=24;
            6'd13: range<=18;
            6'd14: range<=12;
            6'd15: range<=6;
            6'd16: range<=0;
            6'd17: range<=-6;
            6'd18: range<=-12;
            6'd19: range<=-18;
            6'd20: range<=-24;
            6'd21: range<=-30;
            6'd22: range<=-35;
            6'd23: range<=-40;
            6'd24: range<=-45;
            6'd25: range<=-49;
            6'd26: range<=-53;
            6'd27: range<=-56;
            6'd28: range<=-59;
            6'd29: range<=-61;
            6'd30: range<=-62;
            6'd31: range<=-63;
            6'd32: range<=-64;
            6'd33: range<=-63;
            6'd34: range<=-62;
            6'd35: range<=-61;
            6'd36: range<=-59;
            6'd37: range<=-56;
            6'd38: range<=-53;
            6'd39: range<=-49;
            6'd40: range<=-45;
            6'd41: range<=-40;
            6'd42: range<=-35;
            6'd43: range<=-30;
            6'd44: range<=-24;
            6'd45: range<=-18;
            6'd46: range<=-12;
            6'd47: range<=-6;
            6'd48: range<=0;
            6'd49: range<=6;
            6'd50: range<=12;
            6'd51: range<=18;
            6'd52: range<=24;
            6'd53: range<=30;
            6'd54: range<=35;
            6'd55: range<=40;
            6'd56: range<=45;
            6'd57: range<=49;
            6'd58: range<=53;
            6'd59: range<=56;
            6'd60: range<=59;
            6'd61: range<=61;
            6'd62: range<=62;
            6'd63: range<=63;
        endcase 
    end 
endmodule 