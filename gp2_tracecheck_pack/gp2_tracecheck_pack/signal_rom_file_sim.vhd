library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

-- Simulation-only ROM that reads samples from input_samples.dec.
-- Same entity name as the Quartus signal_rom, so compile this INSTEAD of
-- signal_rom.vhd in Questa.
-- File format: one decimal 12-bit sample per line.
entity signal_rom is
    port (
        address : in  std_logic_vector(10 downto 0);
        clock   : in  std_logic;
        q       : out std_logic_vector(11 downto 0)
    );
end entity;

architecture sim of signal_rom is
    type rom_t is array (0 to 2047) of std_logic_vector(11 downto 0);

    impure function init_rom return rom_t is
        file f        : text open read_mode is "input_samples.dec";
        variable l    : line;
        variable v    : integer;
        variable idx  : integer := 0;
        variable mem  : rom_t := (others => (others => '0'));
    begin
        while not endfile(f) loop
            readline(f, l);
            read(l, v);
            if idx <= 2047 then
                if v < 0 then
                    mem(idx) := (others => '0');
                elsif v > 4095 then
                    mem(idx) := (others => '1');
                else
                    mem(idx) := std_logic_vector(to_unsigned(v, 12));
                end if;
            end if;
            idx := idx + 1;
        end loop;
        return mem;
    end function;

    constant rom : rom_t := init_rom;
    signal q_reg : std_logic_vector(11 downto 0) := (others => '0');
begin
    process(clock)
    begin
        if rising_edge(clock) then
            q_reg <= rom(to_integer(unsigned(address)));
        end if;
    end process;

    q <= q_reg;
end architecture;
