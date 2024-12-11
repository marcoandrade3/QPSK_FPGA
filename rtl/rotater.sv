
module bram_rotater #
	(
        parameter integer BRAM_WIDTH = 32,
        parameter integer BRAM_DATA_WIDTH = 32
	)
	(
        input logic clk,
        input logic rst,
        input logic [BRAM_DATA_WIDTH - 1: 0] data_from_BRAM,
        output wire [$clog2(DATA_WIDTH) - 1:0] addr,
        output wire [BRAM_DATA_WIDTH - 1:0] data_processed  
        output wire tlast
    );
    
    assign tlast = (state == WAIT_TWO_2)? 1 : 0;
    assign data_processed = data_from_BRAM;
    enum {ITERATE, WAIT_TWO_1, WAIT_TWO_2} state;
    always_ff @(posedge clk) begin
        if (~rst) begin
            addr <= 0;
            data <= 0;
            tlast <= 0;
            state <= ITERATE; 
        end else begin 
            case (state) 
                ITERATE: begin 
                    addr <= addr + 1; 

                    if (addr == BRAM_WIDTH - 1) begin 
                        state <= WAIT_TWO_1; 
                    end 
                end 
                WAIT_TWO_1: begin 
                    state <= WAIT_TWO_2;
                end 
                WAIT_TWO_2: begin 
                    state <= ITERATE; 
                end     
            endcase 
        end 
    end

endmodule