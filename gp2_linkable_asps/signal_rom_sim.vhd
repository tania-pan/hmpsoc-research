library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_rom is
    port (
        address : in  std_logic_vector(10 downto 0);
        clock   : in  std_logic;
        q       : out std_logic_vector(11 downto 0)
    );
end entity;

architecture sim of signal_rom is
    signal q_reg : std_logic_vector(11 downto 0) := (others => '0');
begin

    -- Simple simulation-only waveform source.
    -- This replaces the Quartus altsyncram ROM for ModelSim/Questa.
    process(clock)
        variable addr_int : integer;
        variable sample   : integer;
    begin
        if rising_edge(clock) then
            addr_int := to_integer(unsigned(address));

            -- Repeating ramp/triangle-ish test pattern within 12 bits.
            if (addr_int mod 512) < 256 then
                sample := 2048 + (addr_int mod 256);
            else
                sample := 2048 - (addr_int mod 256);
            end if;

            q_reg <= std_logic_vector(to_unsigned(sample, 12));
        end if;
    end process;

    q <= q_reg;

end architecture;