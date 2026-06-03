library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gp2_packet_pkg.all;

entity tb_gp2_asp_chain_stub is
end entity;

architecture sim of tb_gp2_asp_chain_stub is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    signal clk        : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal tick_16khz : std_logic := '0';
    signal config_pkt : std_logic_vector(39 downto 0) := (others => '0');
    signal final_pkt  : std_logic_vector(39 downto 0);
    signal peak_irq   : std_logic;

    -- Config payload convention:
    -- bits 31..29 = next destination port
    -- bits 3..2   = moving-average window select: 00=4, 01=8, 10=16
    -- bit 1       = signal generator resolution mode: 0=10-bit, 1=8-bit
    -- bit 0       = enable
    signal conf_payload : std_logic_vector(31 downto 0) := (others => '0');

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.gp2_asp_chain_stub
        port map (
            clk        => clk,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            config_pkt => config_pkt,
            final_pkt  => final_pkt,
            peak_irq   => peak_irq
        );

    -- Make a 1-clock sample tick every 64 clocks.
    -- This is much faster than real 16 kHz, just to make simulation quick.
    tick_proc : process
    begin
        tick_16khz <= '0';
        wait until reset_n = '1';
        wait until rising_edge(clk);

        while true loop
            tick_16khz <= '1';
            wait until rising_edge(clk);
            tick_16khz <= '0';

            for i in 0 to 62 loop
                wait until rising_edge(clk);
            end loop;
        end loop;
    end process;

    stim_proc : process
    begin
        -- Reset
        reset_n <= '0';
        config_pkt <= (others => '0');
        wait for 200 ns;
        wait until rising_edge(clk);
        reset_n <= '1';

        -- Configure signal generator / chain start.
        -- Dest = 001 because config_pkt goes into ASP signal node.
        -- Payload next_dest = 010, enable = 1.
        -- The signal ASP reads payload(31 downto 29) as where its DATA goes next.
        conf_payload <= (others => '0');
        conf_payload(31 downto 29) <= "010";
        conf_payload(3 downto 2)   <= "00"; -- average window 4 if used by downstream ASPs
        conf_payload(1)            <= '0';  -- 10-bit mode
        conf_payload(0)            <= '1';  -- enable

        wait until rising_edge(clk);
        config_pkt <= make_packet(MSG_CONF, "001", conf_payload);

        wait until rising_edge(clk);
        config_pkt <= (others => '0');

        -- Run long enough for samples to move through all ASPs.
        wait for 2 ms;

        assert false report "Simulation finished. Check sig_to_avg, avg_to_sym, sym_to_peak, final_pkt, peak_irq." severity failure;
    end process;

end architecture;
