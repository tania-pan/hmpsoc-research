library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package TdmaMinTypes is

	subtype tdma_min_addr is std_logic_vector(7 downto 0);
	-- TDMA-MIN payload format used by GP2:
	-- data(32)          = valid / packet-present bit
	-- data(31 downto 0) = full 32-bit ASP payload or ReCOP control word
	--
	-- The destination remains separate in addr(7 downto 0). This preserves
	-- the full 32-bit data word instead of stealing payload bits for valid/type.
	subtype tdma_min_data is std_logic_vector(32 downto 0);
	subtype tdma_min_fifo is std_logic_vector(40 downto 0);

	type tdma_min_port is record
		addr : tdma_min_addr;
		data : tdma_min_data;
	end record;

	type tdma_min_datas is array (natural range <>) of tdma_min_data;
	type tdma_min_ports is array (natural range <>) of tdma_min_port;

	function log2Ceil (x : positive) return natural;

end package;

package body TdmaMinTypes is

	function log2Ceil (x : positive) return natural is
		variable i : natural := 0;
	begin
		while (2**i < x) and i < 31 loop
			i := i + 1;
		end loop;
		return i;
	end function;

end package body;
