library ieee;
use ieee.std_logic_1164.all;

package gp2_packet_pkg is
    -- Common 40-bit packet format used by the GP2 ASP wrappers:
    --
    -- bit  39      : valid
    -- bits 38..35 : message type
    -- bits 34..32 : destination port number, 0 to 7
    -- bits 31..0  : payload
    --
    -- Config payload convention used by these wrappers:
    -- bits 31..29 : next destination port
    -- bits  3..2  : moving-average window select, 00=L4, 01=L8, 10=L16
    -- bit      1  : signal generator resolution mode, 0=10-bit style, 1=8-bit style
    -- bit      0  : enable

    constant PKT_VALID_BIT : integer := 39;

    constant MSG_DATA  : std_logic_vector(3 downto 0) := "1000";
    constant MSG_CONF  : std_logic_vector(3 downto 0) := "1111";
    constant MSG_EVENT : std_logic_vector(3 downto 0) := "1100";

    function make_packet(
        msg_type : std_logic_vector(3 downto 0);
        dest     : std_logic_vector(2 downto 0);
        payload  : std_logic_vector(31 downto 0)
    ) return std_logic_vector;

end package;

package body gp2_packet_pkg is

    function make_packet(
        msg_type : std_logic_vector(3 downto 0);
        dest     : std_logic_vector(2 downto 0);
        payload  : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
        variable pkt : std_logic_vector(39 downto 0);
    begin
        pkt(39)           := '1';
        pkt(38 downto 35) := msg_type;
        pkt(34 downto 32) := dest;
        pkt(31 downto 0)  := payload;
        return pkt;
    end function;

end package body;
