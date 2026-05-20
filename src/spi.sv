/*******************************************************************************
*
* spi.sv
* 05/14/2026
*
* Maggie Michelsen
* Instantiates SPI functionality 
*
*******************************************************************************/

module spi #(
	parameter CLK_DIV = 50
	)
	(
		input logic clk,
		input logic rst,
		input logic start,
		input logic [7:0] tx_byte,
		input logic spi_miso,
		output logic busy,
		output logic done,
		output logic [7:0] rx_byte,
		output logic spi_clk,
		output logic spi_mosi
	);

	// Internal logic
	logic [$clog2(CLK_DIV)-1:0] clk_cnt;
	logic spi_clk_r;
	logic clk_edge;
	logic [2:0] bit_cnt;
	logic [7:0] shift_tx;
	logic [7:0] shift_rx;
	 
	// State enum
	typedef enum {IDLE, TRANSFER, DONE} state_t;
	state_t state;

	
	always_ff @(posedge clk) begin
		// registers initial state
		if (rst) begin
			state       <= IDLE;
			clk_cnt     <= 0;
			spi_clk_r   <= 0;
			bit_cnt     <= 7;
			shift_tx    <= 8'hFF;
			shift_rx    <= 8'h00;
			done        <= 0;
			busy        <= 0;
		end

		// Clock divider
		clk_edge <= 0;
		if (clk_cnt == CLK_DIV - 1) begin
			clk_cnt   <= 0;
			spi_clk_r <= ~spi_clk_r;
			clk_edge  <= 1;        // pulse once per SPI clock edge
		end
		else
			clk_cnt <= clk_cnt + 1;

	// SPI shift machine 
		done = 0;                 // default: not done

		case (state)
			IDLE: begin
				busy = 0;
				if (start) begin
					shift_tx <= tx_byte;
					bit_cnt  <= 7;
					busy     <= 1;
					state    <= TRANSFER;
				end
			end
			TRANSFER: begin
				if (clk_edge) begin
					if (spi_clk_r == 0)         // rising SPI edge → sample MISO
						shift_rx <= { shift_rx[6:0], spi_miso };

					else begin                        // falling SPI edge → drive MOSI
						if (bit_cnt == 0)
							state <= DONE;
						else begin
							shift_tx <= { shift_tx[6:0], 1'b1 };
							bit_cnt <= bit_cnt - 1;
						end
					end
				end
			end

			DONE: begin
				rx_byte <= shift_rx;
				done    <= 1;
				busy    <= 0;
				state   <= IDLE;
			end
		endcase
	end

	// Continuous assignments
	assign spi_mosi = shift_tx[7];                      // always output MSB
	assign spi_clk  = spi_clk_r & (state == TRANSFER);  // clock only during transfer
	
endmodule