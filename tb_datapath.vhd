library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_data_mem is
end entity;

architecture sim of tb_data_mem is
    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal address  : std_logic_vector(11 downto 0) := (others => '0');
    signal data     : std_logic_vector(15 downto 0) := (others => '0');
    signal wren     : std_logic := '0';
    signal q        : std_logic_vector(15 downto 0);

    procedure step is
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
    end procedure;

begin
    dut : entity work.data_mem
        port map (
            address => address,
            clock   => clk,
            data    => data,
            wren    => wren,
            q       => q
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stim : process
    begin
        report "Starting data_mem TB";

        -- write 0x1234 to address 5
        address <= std_logic_vector(to_unsigned(5, 12));
        data    <= x"1234";
        wren    <= '1';
        wait for CLK_PERIOD;

        -- stop writing, read same address
        wren    <= '0';
        wait for CLK_PERIOD;

        assert q = x"1234"
            report "Readback from address 5 failed"
            severity error;

        -- write another value to another address
        address <= std_logic_vector(to_unsigned(12, 12));
        data    <= x"ABCD";
        wren    <= '1';
        wait for CLK_PERIOD;

        wren    <= '0';
        wait for CLK_PERIOD;
        assert q = x"ABCD"
            report "Readback from address 12 failed"
            severity error;

        -- re-read old address to ensure contents persist
        address <= std_logic_vector(to_unsigned(5, 12));
        wait for CLK_PERIOD;
        assert q = x"1234"
            report "Old address contents were corrupted"
            severity error;

        report "data_mem TB PASSED";
        wait;
    end process;
end architecture;