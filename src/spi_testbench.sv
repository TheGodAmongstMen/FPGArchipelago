/*******************************************************************************
*
* spi_testbench.sv
* 05/20/2026
*
* Maggie Michelsen
* Testing the spi fuctionality
*
*******************************************************************************/

module spi_testbench;

    // Signals
    reg         clk;
    reg         rst;
    reg         start;
    reg  [7:0]  tx_byte;
    reg         spi_miso;
    wire        busy;
    wire        done;
    wire [7:0]  rx_byte;
    wire        spi_clk;
    wire        spi_mosi;


    // DUT instantiation
    spi #(.CLK_DIV(4)) dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .tx_byte  (tx_byte),
        .spi_miso (spi_miso),
        .busy     (busy),
        .done     (done),
        .rx_byte  (rx_byte),
        .spi_clk  (spi_clk),
        .spi_mosi (spi_mosi)
    );

    // Clock generator 
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns


    // We put a value on MISO
    localparam MISO_BYTE = 8'h3c;
    int miso_idx = 7;

    always_ff @(negedge spi_clk) begin
        spi_miso <= MISO_BYTE[miso_idx];
        miso_idx <= miso_idx - 1;
        if(start)
            miso_idx <= 7;
    end

    // Now we test
    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_testbench);

        rst      = 1;
        start    = 0;
        tx_byte  = 8'h00;
        spi_miso = 0;

        #20 // wait
        rst = 0;

        /***********************************************************************
        * TEST #1: Reset state
        * Expected: busy=0, done=0, spi_clk=0, spi_mosi driven by shift_tx[7]
        * PSEUDOCODE:
        *   assert (busy == 0)  else $error("busy should be 0 after reset");
        *   assert (done == 0)  else $error("done should be 0 after reset");
        *   assert (spi_clk == 0) else $error("spi_clk should idle low");
        ***********************************************************************/

        if(busy != 0)
            $error("busy should be 0 after reset!");
        if(done != 0)
            $error("done should be 0 after reset!");
        if (spi_clk != 0)
            $error("spi_clk should be 0 after reset!");


        /***********************************************************************
        * PSEUDOCODE:
        * TEST #2 : Basic transfer: send 0xA5, expect to receive 0x3C
        *   tx_byte = 8'hA5;
        *   start   = 1;
        *   @(posedge clk);
        *   start   = 0;           // pulse start for one cycle
        *
        *   assert (busy == 1)  else $error("busy should go high on start");
        *   assert (spi_clk == 0) else $error("spi_clk should still be low at start");
        *
        *   // Let MISO model drive 0x3C bit-by-bit (see MISO model above)
        *
        *   // Wait for done to pulse
        *   @(posedge done);
        *
        *   assert (rx_byte == 8'h3C) else $error("rx_byte mismatch: got %h", rx_byte);
        *   assert (busy == 0)        else $error("busy should clear after done");
        ***********************************************************************/
        tx_byte = 8'hA5;
        start = 1;
        #1
        start = 0;

        if(busy != 1)
            $error("busy should be high on start!");
        if(spi_clk != 0)
            $error("spi_clk should be low at start!");

        


        // =====================================================================
        // TEST 3 — Verify MOSI shifts out 0xA5 MSB-first
        // PSEUDOCODE:
        //   For each bit i from 7 downto 0:
        //     on the rising edge of spi_clk for bit i,
        //     check: spi_mosi == tx_byte[i]
        //     i.e.   assert(spi_mosi == 8'hA5[i])
        //              else $error("MOSI bit %0d wrong: expected %b got %b", i, 8'hA5[i], spi_mosi);
        // =====================================================================

        // =====================================================================
        // TEST 4 — spi_clk idles low between transfers
        // PSEUDOCODE:
        //   after done pulses, wait a few cycles
        //   assert (spi_clk == 0) else $error("spi_clk should idle low between transfers");
        // =====================================================================

        // =====================================================================
        // TEST 5 — start ignored while busy
        // PSEUDOCODE:
        //   begin a new transfer (tx_byte = 8'hFF, start = 1 for one cycle)
        //   halfway through the transfer, assert start = 1 again with tx_byte = 8'h00
        //   after the transfer completes, check that rx_byte still reflects
        //   the original transfer, not the second start attempt
        // =====================================================================

        // =====================================================================
        // TEST 6 — back-to-back transfers
        // PSEUDOCODE:
        //   on the cycle that done goes high, immediately assert start with new tx_byte
        //   verify a second transfer begins cleanly (busy goes high, done fires again)
        // =====================================================================

        // --- End of simulation ---
        // PSEUDOCODE: #1000; $finish;

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog — kills sim if a transfer takes too long
    // PSEUDOCODE:
    //   initial begin
    //     #50000;
    //     $error("TIMEOUT: simulation did not finish in time");
    //     $finish;
    //   end
    // -------------------------------------------------------------------------

endmodule
