library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gp2_packet_pkg.all;

-- Linkable GP2 ASP wrapper/core for moving average.
-- It consumes MSG_DATA packets and outputs MSG_DATA packets.
entity moving_average_noc_asp is
    generic (
        DEFAULT_NEXT_DEST : std_logic_vector(2 downto 0) := "011"
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;

        noc_recv  : in  std_logic_vector(39 downto 0);
        noc_send  : out std_logic_vector(39 downto 0);
        noc_ready : in  std_logic
    );
end entity;

architecture rtl of moving_average_noc_asp is

    type sample_reg_t is array (0 to 14) of unsigned(11 downto 0);
    signal regs : sample_reg_t := (others => (others => '0'));

    signal enabled         : std_logic := '1';
    signal next_dest       : std_logic_vector(2 downto 0) := DEFAULT_NEXT_DEST;
    signal window_sel      : std_logic_vector(1 downto 0) := "00";

    signal pending_valid   : std_logic := '0';
    signal pending_payload : std_logic_vector(31 downto 0) := (others => '0');

begin

    process(clk, reset_n)
        variable sum_v       : unsigned(15 downto 0);
        variable avg_v       : unsigned(11 downto 0);
        variable shift_bits  : integer range 0 to 4;
        variable payload_v   : std_logic_vector(31 downto 0);
        variable sample_v    : unsigned(11 downto 0);
    begin
        if reset_n = '0' then
            regs            <= (others => (others => '0'));
            enabled         <= '1';
            next_dest       <= DEFAULT_NEXT_DEST;
            window_sel      <= "00";
            pending_valid   <= '0';
            pending_payload <= (others => '0');
            noc_send        <= (others => '0');

        elsif rising_edge(clk) then
            noc_send <= (others => '0');

            -- Configuration packet
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_CONF then
                next_dest  <= noc_recv(31 downto 29);
                window_sel <= noc_recv(3 downto 2);
                enabled    <= noc_recv(0);
            end if;

            -- Data packet. If output is still pending, apply backpressure by ignoring new data.
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_DATA and enabled = '1' and pending_valid = '0' then
                sample_v := unsigned(noc_recv(11 downto 0));

                case window_sel is
                    when "00" => -- L = 4
                        sum_v := resize(sample_v, 16) +
                                 resize(regs(0), 16) + resize(regs(1), 16) + resize(regs(2), 16);
                        shift_bits := 2;

                    when "01" => -- L = 8
                        sum_v := resize(sample_v, 16);
                        for i in 0 to 6 loop
                            sum_v := sum_v + resize(regs(i), 16);
                        end loop;
                        shift_bits := 3;

                    when "10" => -- L = 16
                        sum_v := resize(sample_v, 16);
                        for i in 0 to 14 loop
                            sum_v := sum_v + resize(regs(i), 16);
                        end loop;
                        shift_bits := 4;

                    when others =>
                        sum_v := resize(sample_v, 16) +
                                 resize(regs(0), 16) + resize(regs(1), 16) + resize(regs(2), 16);
                        shift_bits := 2;
                end case;

                regs <= sample_v & regs(0 to 13);

                avg_v := resize(shift_right(sum_v, shift_bits), 12);

                payload_v := noc_recv(31 downto 0);
                payload_v(11 downto 0) := std_logic_vector(avg_v);

                pending_payload <= payload_v;
                pending_valid   <= '1';
            end if;

            if pending_valid = '1' and noc_ready = '1' then
                noc_send      <= make_packet(MSG_DATA, next_dest, pending_payload);
                pending_valid <= '0';
            end if;
        end if;
    end process;

end architecture;
