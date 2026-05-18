library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_symmetry_core is
end entity;

architecture sim of tb_symmetry_core is

    -- Testbench signals connected to the DUT
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';

    signal sample_valid : std_logic := '0';
    signal sample_in    : std_logic_vector(11 downto 0) := (others => '0');

    signal corr_done    : std_logic;
    signal corr_out     : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

begin

    dut : entity work.symmetry_core
        port map (
            clk          => clk,
            reset        => reset,
            sample_valid => sample_valid,
            sample_in    => sample_in,
            corr_done    => corr_done,
            corr_out     => corr_out
        );

    -- Free-running simulation clock
    clk <= not clk after CLK_PERIOD / 2;

    process

        procedure do_reset is
        begin
            reset <= '1';
            sample_valid <= '0';
            sample_in <= (others => '0');

            wait for 100 ns;

            reset <= '0';

            wait for 50 ns;
        end procedure;


        procedure feed_sample(value : integer) is
        begin
            sample_in <= std_logic_vector(to_unsigned(value, 12));
            sample_valid <= '1';
            wait for CLK_PERIOD;

            sample_valid <= '0';

            -- This testbench feeds samples slowly so each correlation can finish.
            -- The core can still accept samples through sample_valid as normal.
            wait for 2000 ns;
        end procedure;


        procedure check_corr(
            expected_value : integer;
            test_name      : string
        ) is
        begin
            wait for 100 ns;

            report test_name & " corr_out = " &
                   integer'image(to_integer(unsigned(corr_out)));

            assert unsigned(corr_out) = to_unsigned(expected_value, 32)
                report test_name & " FAILED: Expected " &
                       integer'image(expected_value)
                severity error;

            report test_name & " PASSED";
        end procedure;


    begin

        -- Test 1 checks the easiest case first.
        -- Every mirrored pair is 100*100, so the result should be:
        -- 16 * 100 * 100 = 160000
        do_reset;

        report "TEST 1: Feeding 32 samples of value 100";

        for i in 0 to 31 loop
            feed_sample(100);
        end loop;

        check_corr(160000, "TEST 1");


        -- Test 2 uses one full 32-sample window:
        -- 0, 1, 2, ..., 31
        --
        -- The centre split is between 15 and 16, so the pairs are:
        -- 16*15, 17*14, 18*13, ..., 31*0
        do_reset;

        report "TEST 2: Feeding ramp samples 0 to 31";

        for i in 0 to 31 loop
            feed_sample(i);
        end loop;

        check_corr(2480, "TEST 2");


        -- Test 3 forces the circular buffer to wrap.
        -- Because all samples are still 100, the expected result should not change.
        do_reset;

        report "TEST 3: Feeding 70 samples of value 100 to test wrap-around";

        for i in 0 to 69 loop
            feed_sample(100);
        end loop;

        check_corr(160000, "TEST 3");
        

        -- Test 4 also wraps the buffer, but now the data changes.
        -- After 70 samples, the latest 32-sample window should be:
        -- 38, 39, 40, ..., 69
        --
        -- Expected mirror pairs:
        -- 54*53, 55*52, 56*51, ..., 69*38
        do_reset;

        report "TEST 4: Feeding ramp samples 0 to 69 to test wrap-around with changing data";

        for i in 0 to 69 loop
            feed_sample(i);
        end loop;

        check_corr(44432, "TEST 4");


        report "ALL TESTS PASSED";
        wait;

    end process;

end architecture;