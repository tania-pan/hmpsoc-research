library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library work;
use work.TdmaMinTypes.all;

entity AspExample is
    port (
        clock : in  std_logic;
        key   : in  std_logic_vector(3 downto 0);
        sw    : in  std_logic_vector(9 downto 0);
        ledr  : out std_logic_vector(9 downto 0);
        hex0, hex1, hex2, hex3, hex4, hex5 : out std_logic_vector(6 downto 0);
        send  : out tdma_min_port;
        recv  : in  tdma_min_port
    );
end entity;

architecture rtl of AspExample is
    signal hexn : unsigned(23 downto 0) := x"000000";
begin
    ledr <= sw;
    process(clock)
        variable edge  : std_logic;
        variable state : natural := 0;
    begin
        if rising_edge(clock) then
            if key(0) = '0' and edge = '1' then
                if state > 4 then state := 4; else state := 9; end if;
                hexn <= hexn + 1;
            end if;
            edge := key(0);

            -- Audio Forwarding with Mute Logic (Forwarding to DAC Port 1)
            if recv.data(31 downto 28) = "1000" and recv.data(16) = '0' and key(2) = '1' then
                send.addr <= x"01";
                send.data <= recv.data;
            elsif recv.data(31 downto 28) = "1000" and recv.data(16) = '1' and key(1) = '1' then
                send.addr <= x"01";
                send.data <= recv.data;
            else
                -- Config Logic
                case state is
                    when 9 => send.addr <= x"01"; send.data <= x"b1020000"; state := 8;
                    when 8 => send.addr <= x"01"; send.data <= x"b1030000"; state := 7;
                    when 7 => send.addr <= x"00"; send.data <= x"a0320000"; state := 6;
                    when 6 => send.addr <= x"00"; send.data <= x"a0330000"; state := 5;
                    when 4 => send.addr <= x"00"; send.data <= x"a0000000"; state := 3;
                    when 3 => send.addr <= x"00"; send.data <= x"a0010000"; state := 2;
                    when 2 => send.addr <= x"01"; send.data <= x"b1000000"; state := 1;
                    when 1 => send.addr <= x"01"; send.data <= x"b1010000"; state := 0;
                    when others => send.addr <= x"01"; send.data <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    hs6 : entity work.HexSeg6 port map (hexn => std_logic_vector(hexn), seg0=>hex0, seg1=>hex1, seg2=>hex2, seg3=>hex3, seg4=>hex4, seg5=>hex5);
end architecture;