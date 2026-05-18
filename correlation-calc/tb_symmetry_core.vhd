library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_symmetry_core is
end entity;

architecture sim of tb_symmetry_core is

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';

    signal sample_valid : std_logic := '0';
    signal sample_in    : std_logic_vector(11 downto 0) := (others => '0');

    signal corr_done    : std_logic;
    signal corr_out     : std_logic_vector(35 downto 0);

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

begin

    --------------------------------------------------------------------
    -- Instantiate DUT
    --------------------------------------------------------------------
    dut : entity work.symmetry_core
        port map (
            clk          => clk,
            reset        => reset,
            sample_valid => sample_valid,
            sample_in    => sample_in,
            corr_done    => corr_done,
            corr_out     => corr_out
        );

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    --------------------------------------------------------------------
    -- Main stimulus process
    --------------------------------------------------------------------
    process

        ----------------------------------------------------------------
        -- Reset DUT
        ----------------------------------------------------------------
        procedure do_reset is
        begin
            reset <= '1';
            sample_valid <= '0';
            sample_in <= (others => '0');

            wait for 100 ns;

            reset <= '0';

            wait for 50 ns;
        end procedure;


        ----------------------------------------------------------------
        -- Feed one sample into DUT
        --
        -- sample_valid is pulsed for one clock.
        -- Then we wait long enough for the correlation core to finish.
        --
        -- Important:
        -- The DUT auto-starts correlation after enough samples exist.
        -- So corr_done may happen during this wait time.
        ----------------------------------------------------------------
        procedure feed_sample(value : integer) is
        begin
            sample_in <= std_logic_vector(to_unsigned(value, 12));
            sample_valid <= '1';
            wait for CLK_PERIOD;

            sample_valid <= '0';

            -- Wait long enough for correlation to finish before next sample.
            -- This keeps the first simulation simple.
            wait for 2000 ns;
        end procedure;


        ----------------------------------------------------------------
        -- Check corr_out value
        ----------------------------------------------------------------
        procedure check_corr(
            expected_value : integer;
            test_name      : string
        ) is
        begin
            wait for 100 ns;

            report test_name & " corr_out = " &
                   integer'image(to_integer(unsigned(corr_out)));

            assert unsigned(corr_out) = to_unsigned(expected_value, 36)
                report test_name & " FAILED: Expected " &
                       integer'image(expected_value)
                severity error;

            report test_name & " PASSED";
        end procedure;


    begin

        ----------------------------------------------------------------
        -- TEST 1: Constant input
        --
        -- Input:
        --   32 samples, all 100
        --
        -- Expected:
        --   16 pairs x 100 x 100 = 160000
        ----------------------------------------------------------------
        do_reset;

        report "TEST 1: Feeding 32 samples of value 100";

        for i in 0 to 31 loop
            feed_sample(100);
        end loop;

        check_corr(160000, "TEST 1");


        ----------------------------------------------------------------
        -- TEST 2: Ramp input
        --
        -- Input:
        --   0, 1, 2, 3, ..., 31
        --
        -- Expected address pairs:
        --   16x15 + 17x14 + 18x13 + ... + 31x0
        --
        -- Expected result:
        --   2480
        ----------------------------------------------------------------
        do_reset;

        report "TEST 2: Feeding ramp samples 0 to 31";

        for i in 0 to 31 loop
            feed_sample(i);
        end loop;

        check_corr(2480, "TEST 2");


        ----------------------------------------------------------------
        -- TEST 3: Circular buffer wrap-around
        --
        -- Input:
        --   70 samples, all 100
        --
        -- Why this test matters:
        --   The 64-deep RAM write pointer wraps around after sample 64.
        --   Since all samples are 100, the correlation should still be:
        --
        --   16 pairs x 100 x 100 = 160000
        ----------------------------------------------------------------
        do_reset;

        report "TEST 3: Feeding 70 samples of value 100 to test wrap-around";

        for i in 0 to 69 loop
            feed_sample(100);
        end loop;

        check_corr(160000, "TEST 3");


        ----------------------------------------------------------------
        -- Finished
        ----------------------------------------------------------------
        report "ALL TESTS PASSED";
        wait;

    end process;

end architecture;

