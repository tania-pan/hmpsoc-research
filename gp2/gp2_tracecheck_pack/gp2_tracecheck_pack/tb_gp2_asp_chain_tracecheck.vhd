library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;
use work.gp2_packet_pkg.all;

entity tb_gp2_asp_chain_tracecheck is
end entity;

architecture sim of tb_gp2_asp_chain_tracecheck is
    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal tick_16khz : std_logic := '0';
    signal config_pkt : std_logic_vector(39 downto 0) := (others => '0');

    signal sig_to_avg  : std_logic_vector(39 downto 0);
    signal avg_to_sym  : std_logic_vector(39 downto 0);
    signal sym_to_peak : std_logic_vector(39 downto 0);
    signal peak_out    : std_logic_vector(39 downto 0);
    signal final_pkt   : std_logic_vector(39 downto 0);
    signal peak_irq    : std_logic;

    signal sig_count   : integer := 0;
    signal avg_count   : integer := 0;
    signal sym_count   : integer := 0;
    signal final_count : integer := 0;

    function is_data_to(pkt : std_logic_vector(39 downto 0); dest : std_logic_vector(2 downto 0)) return boolean is
    begin
        return pkt(39) = '1' and pkt(38 downto 35) = MSG_DATA and pkt(34 downto 32) = dest;
    end function;

begin
    clk <= not clk after CLK_PERIOD/2;

    dut : entity work.gp2_asp_chain_probe
        port map (
            clk         => clk,
            reset_n     => reset_n,
            tick_16khz  => tick_16khz,
            config_pkt  => config_pkt,
            sig_to_avg  => sig_to_avg,
            avg_to_sym  => avg_to_sym,
            sym_to_peak => sym_to_peak,
            peak_out    => peak_out,
            final_pkt   => final_pkt,
            peak_irq    => peak_irq
        );

    -- Main stimulus: reset, send config command, then produce deterministic sample ticks.
    stim_proc : process
        variable conf_payload : std_logic_vector(31 downto 0);
    begin
        report "GP2 ASP trace/check test starting" severity note;

        reset_n    <= '0';
        tick_16khz <= '0';
        config_pkt <= (others => '0');
        wait for 200 ns;

        reset_n <= '1';
        report "Reset released" severity note;
        wait for 100 ns;

        -- Enable signal generator. Payload bits 31..29 choose next dest = 010.
        -- Payload bit 1 = 0 means 10-bit style sample from ROM q(11 downto 2).
        -- Payload bit 0 = 1 means enable.
        conf_payload := (others => '0');
        conf_payload(31 downto 29) := "010";
        conf_payload(1) := '0';
        conf_payload(0) := '1';
        config_pkt <= make_packet(MSG_CONF, "000", conf_payload);
        wait for CLK_PERIOD;
        config_pkt <= (others => '0');
        report "Signal generator config pulse sent" severity note;

        -- Generate sample ticks. One tick is one sample entering the pipeline.
        for i in 0 to 31 loop
            wait until rising_edge(clk);
            tick_16khz <= '1';
            wait until rising_edge(clk);
            tick_16khz <= '0';

            -- Leave a few clocks between samples so the direct-chain packets are easy to see.
            for gap in 0 to 3 loop
                wait until rising_edge(clk);
            end loop;
        end loop;

        wait for 2 us;

        assert sig_count >= 24
            report "FAIL: not enough signal-generator packets. sig_count=" & integer'image(sig_count)
            severity failure;
        assert avg_count >= 24
            report "FAIL: not enough moving-average packets. avg_count=" & integer'image(avg_count)
            severity failure;
        assert sym_count >= 1
            report "FAIL: symmetry/correlation stage never produced output."
            severity failure;
        assert final_count >= 1
            report "FAIL: final/peak stage never produced output."
            severity failure;

        report "==============================================" severity note;
        report "TRACE CHECK PASSED" severity note;
        report "sig_count   = " & integer'image(sig_count) severity note;
        report "avg_count   = " & integer'image(avg_count) severity note;
        report "sym_count   = " & integer'image(sym_count) severity note;
        report "final_count = " & integer'image(final_count) severity note;
        report "==============================================" severity note;
        stop;
    end process;

    -- Monitor the pipeline. This is the useful part: it checks the actual expected
    -- moving-average values against what the ASP emits.
    monitor_proc : process
        type int_queue_t is array (0 to 255) of integer;
        variable exp_avg_q : int_queue_t := (others => 0);
        variable raw_q     : int_queue_t := (others => 0);
        variable q_head    : integer := 0;
        variable q_tail    : integer := 0;

        variable hist0     : integer := 0;
        variable hist1     : integer := 0;
        variable hist2     : integer := 0;

        variable raw_sample : integer;
        variable exp_avg    : integer;
        variable got_avg    : integer;
        variable got_sym    : integer;
        variable got_final  : integer;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;

        if reset_n = '0' then
            q_head := 0;
            q_tail := 0;
            hist0 := 0;
            hist1 := 0;
            hist2 := 0;
            sig_count   <= 0;
            avg_count   <= 0;
            sym_count   <= 0;
            final_count <= 0;
        else
            if is_data_to(sig_to_avg, "010") then
                raw_sample := to_integer(unsigned(sig_to_avg(11 downto 0)));

                -- moving_average_noc_asp default is window_sel=00, so L=4.
                -- It averages the new sample plus the previous three stored samples.
                exp_avg := (raw_sample + hist0 + hist1 + hist2) / 4;

                hist2 := hist1;
                hist1 := hist0;
                hist0 := raw_sample;

                exp_avg_q(q_tail) := exp_avg;
                raw_q(q_tail)     := raw_sample;
                q_tail := q_tail + 1;

                sig_count <= sig_count + 1;
                report "SIG  sample[" & integer'image(sig_count + 1) & "] raw_payload=" & integer'image(raw_sample) severity note;
            end if;

            if is_data_to(avg_to_sym, "011") then
                got_avg := to_integer(unsigned(avg_to_sym(11 downto 0)));

                assert q_head < q_tail
                    report "FAIL: AVG packet arrived before matching SIG packet."
                    severity failure;

                exp_avg := exp_avg_q(q_head);
                raw_sample := raw_q(q_head);
                q_head := q_head + 1;

                report "AVG  sample[" & integer'image(avg_count + 1) & "] raw=" & integer'image(raw_sample) &
                       " expected_avg=" & integer'image(exp_avg) & " got_avg=" & integer'image(got_avg) severity note;

                assert got_avg = exp_avg
                    report "FAIL: moving average mismatch. raw=" & integer'image(raw_sample) &
                           " expected=" & integer'image(exp_avg) & " got=" & integer'image(got_avg)
                    severity failure;

                avg_count <= avg_count + 1;
            end if;

            if is_data_to(sym_to_peak, "100") then
                got_sym := to_integer(unsigned(sym_to_peak(31 downto 0)));
                sym_count <= sym_count + 1;
                report "SYM  output[" & integer'image(sym_count + 1) & "] corr_payload=" & integer'image(got_sym) severity note;
            end if;

            if peak_out(39) = '1' and peak_out(34 downto 32) = "101" then
                got_final := to_integer(unsigned(peak_out(31 downto 0)));
                final_count <= final_count + 1;
                report "PEAK output[" & integer'image(final_count + 1) & "] type=" & to_hstring(peak_out(38 downto 35)) &
                       " payload=" & integer'image(got_final) severity note;
            end if;
        end if;
    end process;

end architecture;
