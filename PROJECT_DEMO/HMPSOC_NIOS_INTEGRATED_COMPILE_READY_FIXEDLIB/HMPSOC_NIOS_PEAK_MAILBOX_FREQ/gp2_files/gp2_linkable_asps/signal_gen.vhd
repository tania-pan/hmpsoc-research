library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_gen is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        tick_16khz  : in  std_logic;

        -- Live configuration from the signal ASP wrapper.
        -- 0 = normal address step, gives 40 Hz with the supplied period-400 MIF.
        -- 1 = double address step, gives 80 Hz from the same MIF.
        freq_mode   : in  std_logic;

        signal_out  : out std_logic_vector(11 downto 0);
        data_ready  : out std_logic
    );
end entity;

architecture rtl of signal_gen is

    component signal_rom is
        port (
            address : in  std_logic_vector(10 downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector(11 downto 0)
        );
    end component;

    signal rom_address : unsigned(10 downto 0) := (others => '0');
    signal valid_reg   : std_logic := '0';

begin

    my_rom : signal_rom
        port map (
            address => std_logic_vector(rom_address),
            clock   => clk,
            q       => signal_out
        );

    process(clk, reset)
    begin
        if reset = '0' then
            rom_address <= (others => '0');
            valid_reg   <= '0';

        elsif rising_edge(clk) then
            valid_reg <= '0';

            if tick_16khz = '1' then
                valid_reg <= '1';

                if freq_mode = '1' then
                    -- 80 Hz mode: read every second ROM sample.
                    -- The ROM contains a 400-sample sine period, so stepping by 2
                    -- makes the emitted period 200 output samples.
                    if rom_address >= to_unsigned(1598, 11) then
                        rom_address <= (others => '0');
                    else
                        rom_address <= rom_address + 2;
                    end if;
                else
                    -- 40 Hz mode: read every ROM sample.
                    if rom_address = to_unsigned(1599, 11) then
                        rom_address <= (others => '0');
                    else
                        rom_address <= rom_address + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    data_ready <= valid_reg;

end architecture;
