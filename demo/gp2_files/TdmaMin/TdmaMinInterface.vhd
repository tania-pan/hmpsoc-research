library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library work;
use work.TdmaMinTypes.all;

entity TdmaMinInterface is
	generic (
		stages   : positive;
		identity : natural
	);
	port (
		clock : in  std_logic;
		slot  : in  std_logic_vector(stages-1 downto 0);
		push  : out tdma_min_data;
		pull  : in  tdma_min_data;

		send  : in  tdma_min_port;
		recv  : out tdma_min_port
	);
end entity;

architecture rtl of TdmaMinInterface is

	constant id : tdma_min_addr := std_logic_vector(to_unsigned(identity, tdma_min_addr'length));
	signal addr : tdma_min_addr;

	-- One-entry packet buffer for this node. The original Lab2 interface used
	-- data(data'high) as the enqueue/valid bit; this version keeps that behaviour
	-- but data is now 33 bits: valid + full 32-bit payload.
	signal pending_valid : std_logic := '0';
	signal pending_addr  : tdma_min_addr := (others => '0');
	signal pending_data  : tdma_min_data := (others => '0');
	signal ready         : boolean;

begin

	addr <= id xor (id'high downto stages => '0') & slot;
	ready <= pending_valid = '1' and pending_addr = addr;

	-- Next packet for network. The fabric carries valid+payload.
	push <= pending_data when ready else (others => '0');

	process(clock)
	begin
		if rising_edge(clock) then
			-- Remove packet once it has been injected during this node's slot.
			if ready then
				pending_valid <= '0';
				pending_addr  <= (others => '0');
				pending_data  <= (others => '0');
			end if;

			-- Capture a new outgoing packet when valid is asserted.
			-- GP2 packet traffic is rate-limited by the sample tick, so one pending
			-- packet per node is sufficient for this demo pipeline.
			if send.data(send.data'high) = '1' then
				pending_valid <= '1';
				pending_addr  <= send.addr;
				pending_data  <= send.data;
			end if;

			-- Receive interface connected to network.
			recv.addr  <= addr;
			recv.data <= pull;
		end if;
	end process;

end architecture;
