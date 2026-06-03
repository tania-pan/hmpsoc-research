library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;

entity gp2_tdma_signal_test_top is
    generic (
        ports : positive := 4
    );
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(3 downto 0);
        SW       : in  std_logic_vector(9 downto 0);
        LEDR     : out std_logic_vector(9 downto 0);
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of gp2_tdma_signal_test_top is

    signal clock   : std_logic;
    signal reset_n : std_logic;

    signal send_port : tdma_min_ports(0 to ports-1);
    signal recv_port : tdma_min_ports(0 to ports-1);

    signal tick_16khz   : std_logic := '0';
    signal tick_counter : unsigned(11 downto 0) := (others => '0');

    signal config_pkt   : std_logic_vector(39 downto 0) := (others => '0');
    signal config_sent  : std_logic := '0';

    signal sig_send_pkt : std_logic_vector(39 downto 0);

    signal rx_seen      : std_logic := '0';
    signal latched_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal latched_data : std_logic_vector(31 downto 0) := (others => '0');

    signal heartbeat_counter : unsigned(25 downto 0) := (others => '0');

    function hex7seg(x : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case x is
            when "0000" => return "1000000"; -- 0
            when "0001" => return "1111001"; -- 1
            when "0010" => return "0100100"; -- 2
            when "0011" => return "0110000"; -- 3
            when "0100" => return "0011001"; -- 4
            when "0101" => return "0010010"; -- 5
            when "0110" => return "0000010"; -- 6
            when "0111" => return "1111000"; -- 7
            when "1000" => return "0000000"; -- 8
            when "1001" => return "0010000"; -- 9
            when "1010" => return "0001000"; -- A
            when "1011" => return "0000011"; -- b
            when "1100" => return "1000110"; -- C
            when "1101" => return "0100001"; -- d
            when "1110" => return "0000110"; -- E
            when others => return "0001110"; -- F
        end case;
    end function;

    function pkt_to_addr(pkt : std_logic_vector(39 downto 0)) return std_logic_vector is
        variable a : std_logic_vector(7 downto 0);
    begin
        a := (others => '0');
        a(2 downto 0) := pkt(34 downto 32); -- destination
        return a;
    end function;

    function pkt_to_data(pkt : std_logic_vector(39 downto 0)) return std_logic_vector is
        variable d : std_logic_vector(31 downto 0);
    begin
        d := (others => '0');

        -- Lab 2 NoC inserts packet when data(31) = 1
        d(31)           := pkt(39);           -- valid
        d(30 downto 27) := pkt(38 downto 35); -- packet type
        d(26 downto 0)  := pkt(26 downto 0);  -- payload lower bits

        return d;
    end function;

begin

    clock   <= CLOCK_50;
    reset_n <= KEY(0); -- KEY0 released = run, pressed = reset

    --------------------------------------------------------------------
    -- TDMA-MIN NoC
    --------------------------------------------------------------------
    tdma_min : entity work.TdmaMin
        generic map (
            ports => ports
        )
        port map (
            clock => clock,
            sends => send_port,
            recvs => recv_port
        );

    --------------------------------------------------------------------
    -- NoC send ports
    -- Port 1 is driven by the signal generator ASP.
    -- Other ports are idle.
    --------------------------------------------------------------------
    process(sig_send_pkt)
    begin
        for i in 0 to ports-1 loop
            send_port(i).addr <= (others => '0');
            send_port(i).data <= (others => '0');
        end loop;

        send_port(1).addr <= pkt_to_addr(sig_send_pkt);
        send_port(1).data <= pkt_to_data(sig_send_pkt);
    end process;

    --------------------------------------------------------------------
    -- 16 kHz tick from 50 MHz clock
    --------------------------------------------------------------------
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            tick_counter <= (others => '0');
            tick_16khz   <= '0';
        elsif rising_edge(clock) then
            if tick_counter = 3124 then
                tick_counter <= (others => '0');
                tick_16khz   <= '1';
            else
                tick_counter <= tick_counter + 1;
                tick_16khz   <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Send one config packet directly to the signal generator ASP
    --------------------------------------------------------------------
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            config_pkt  <= (others => '0');
            config_sent <= '0';
        elsif rising_edge(clock) then
            if config_sent = '0' then
                -- valid=1
                -- type=CONFIG 1111
                -- dest=001 signal ASP
                -- payload bit 0 = enable
                -- payload bits 31..29 = next destination 010
                config_pkt  <= "1" & "1111" & "001" & x"40000001";
                config_sent <= '1';
            else
                config_pkt <= (others => '0');
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Signal generator ASP
    --------------------------------------------------------------------
    u_signal : entity work.asp_signal_noc
        port map (
            clk        => clock,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            noc_recv   => config_pkt,
            noc_send   => sig_send_pkt,
            noc_ready  => '1'
        );

    --------------------------------------------------------------------
    -- Debug sink: latch anything received at NoC port 2
    --------------------------------------------------------------------
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            rx_seen <= '0';
            latched_addr <= (others => '0');
            latched_data <= (others => '0');
            heartbeat_counter <= (others => '0');
        elsif rising_edge(clock) then
            heartbeat_counter <= heartbeat_counter + 1;

            if recv_port(2).data(31) = '1' then
                rx_seen <= '1';
                latched_addr <= recv_port(2).addr;
                latched_data <= recv_port(2).data;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Debug outputs
    --------------------------------------------------------------------
    LEDR(0) <= reset_n;                    -- system running
    LEDR(1) <= config_sent;                -- config sent
    LEDR(2) <= sig_send_pkt(39);           -- live signal valid, may be too fast
    LEDR(3) <= rx_seen;                    -- NoC port 2 received packet
    LEDR(7 downto 4) <= latched_data(30 downto 27); -- packet type
    LEDR(8) <= latched_addr(0);            -- address bit
    LEDR(9) <= heartbeat_counter(25);      -- heartbeat

    HEX0 <= hex7seg(latched_data(3 downto 0));
    HEX1 <= hex7seg(latched_data(7 downto 4));
    HEX2 <= hex7seg(latched_data(11 downto 8));
    HEX3 <= hex7seg(latched_data(15 downto 12));

end architecture;