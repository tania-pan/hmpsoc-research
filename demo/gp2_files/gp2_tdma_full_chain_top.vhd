library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;
use work.gp2_packet_pkg.all;

entity gp2_tdma_full_chain_top is
    generic (
        ports : positive := 8
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

architecture rtl of gp2_tdma_full_chain_top is

    signal clock        : std_logic;
    signal reset_n      : std_logic;
    signal button_start : std_logic;

    signal debug_button_latched  : std_logic := '0';
    signal debug_tx_trigger_seen : std_logic := '0';

    signal send_port : tdma_min_ports(0 to ports-1);
    signal recv_port : tdma_min_ports(0 to ports-1);

    signal tick_16khz   : std_logic := '0';
    signal tick_counter : unsigned(11 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- RECOP NoC adapter signals
    --
    -- Port mapping:
    -- port 0 = ReCOP processor wrapper
    -- port 1 = signal generator ASP
    -- port 2 = moving average ASP
    -- port 3 = symmetry/correlation ASP
    -- port 4 = peak detector ASP
    -- port 5 = debug sink
    --------------------------------------------------------------------
    signal recop_send : tdma_min_port;
    signal recop_recv : tdma_min_port;

    signal sig_recv_pkt  : std_logic_vector(39 downto 0);
    signal sig_send_pkt  : std_logic_vector(39 downto 0);
    signal avg_recv_pkt  : std_logic_vector(39 downto 0);
    signal avg_send_pkt  : std_logic_vector(39 downto 0);
    signal sym_recv_pkt  : std_logic_vector(39 downto 0);
    signal sym_send_pkt  : std_logic_vector(39 downto 0);
    signal peak_recv_pkt : std_logic_vector(39 downto 0);
    signal peak_send_pkt : std_logic_vector(39 downto 0);

    signal rx_seen      : std_logic := '0';
    signal latched_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal latched_data : std_logic_vector(31 downto 0) := (others => '0');

    -- Latched payloads at each pipeline boundary for demo/HEX debug.
    -- Select with SW(2 downto 0). SW(9)=0 shows low 16 bits, SW(9)=1 shows high 16 bits.
    -- SW(8)=1 freezes these debug payload registers so values can be read on HEX.
    signal dbg_cfg_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- ReCOP -> signal ASP, expected 0x40000001
    signal dbg_sig_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- signal -> moving average, first low16 approx 0x03F7
    signal dbg_avg_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- moving average -> symmetry, first low16 approx 0x00FD
    signal dbg_sym_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- symmetry -> peak, correlation result
    signal dbg_peak_payload : std_logic_vector(31 downto 0) := (others => '0'); -- peak -> debug sink, final/event value
    signal display_word     : std_logic_vector(15 downto 0) := (others => '0');

    signal recop_seen : std_logic := '0';
    signal sig_seen   : std_logic := '0';
    signal avg_seen   : std_logic := '0';
    signal sym_seen   : std_logic := '0';
    signal peak_seen  : std_logic := '0';

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

    --------------------------------------------------------------------
    -- Convert GP2 40-bit ASP packet to Lab2 TDMA-MIN address.
    --------------------------------------------------------------------
    function pkt_to_addr(pkt : std_logic_vector(39 downto 0)) return std_logic_vector is
        variable a : std_logic_vector(7 downto 0);
    begin
        a := (others => '0');
        a(2 downto 0) := pkt(34 downto 32); -- destination
        return a;
    end function;

    --------------------------------------------------------------------
    -- Convert GP2 40-bit ASP packet to TDMA-MIN format.
    -- TDMA-MIN carries destination separately in addr, and carries
    -- valid + full 32-bit payload in data. No payload bits are lost.
    --------------------------------------------------------------------
    function pkt_to_data(pkt : std_logic_vector(39 downto 0)) return tdma_min_data is
        variable d : tdma_min_data;
    begin
        d := (others => '0');
        d(d'high)          := pkt(39);          -- valid / packet-present
        d(31 downto 0)     := pkt(31 downto 0); -- full 32-bit payload
        return d;
    end function;

    --------------------------------------------------------------------
    -- Convert TDMA-MIN receive word back into the ASP 40-bit packet used
    -- inside the GP2 wrappers. The packet type is supplied by the top-level
    -- because this demo pipeline has fixed roles: ReCOP->signal is CONFIG,
    -- and ASP->ASP traffic is DATA.
    --------------------------------------------------------------------
    function data_to_pkt(
        data       : tdma_min_data;
        local_dest : std_logic_vector(2 downto 0);
        msg_type   : std_logic_vector(3 downto 0)
    ) return std_logic_vector is
        variable p : std_logic_vector(39 downto 0);
    begin
        p := (others => '0');
        p(39)           := data(data'high);
        p(38 downto 35) := msg_type;
        p(34 downto 32) := local_dest;
        p(31 downto 0)  := data(31 downto 0);
        return p;
    end function;

begin

    clock        <= CLOCK_50;
    reset_n      <= KEY(0);      -- KEY0 released = run, pressed = reset
    button_start <= not KEY(1);  -- KEY1 pressed = event/start request

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
    -- ReCOP wrapper on NoC port 0
    --
    -- ReCOP writes to its memory-mapped TX registers:
    -- 0x3000 = target NoC address
    -- 0x3001 = payload high word
    -- 0x3002 = payload low word
    -- 0x3003 = trigger send
    --
    -- To start the GP2 chain, ReCOP should send a CONFIG packet to port 1.
    -- ReCOP sends destination addr=1 and 32-bit payload=x40000001.
    -- The top-level reconstructs this as a CONFIG packet for signal ASP.
    --------------------------------------------------------------------
    u_recop : entity work.recop_noc_wrapper
        port map (
            clk                   => clock,
            reset_n               => reset_n,
            button_event          => button_start,
            send_port             => recop_send,
            recv_port             => recop_recv,
            debug_button_latched  => debug_button_latched,
            debug_tx_trigger_seen => debug_tx_trigger_seen
        );

    recop_recv <= recv_port(0);

    --------------------------------------------------------------------
    -- Convert NoC receive ports into ASP receive packets
    --------------------------------------------------------------------
    sig_recv_pkt  <= data_to_pkt(recv_port(1).data, "001", MSG_CONF);
    avg_recv_pkt  <= data_to_pkt(recv_port(2).data, "010", MSG_DATA);
    sym_recv_pkt  <= data_to_pkt(recv_port(3).data, "011", MSG_DATA);
    peak_recv_pkt <= data_to_pkt(recv_port(4).data, "100", MSG_DATA);

    --------------------------------------------------------------------
    -- NoC send ports
    --------------------------------------------------------------------
    process(recop_send, sig_send_pkt, avg_send_pkt, sym_send_pkt, peak_send_pkt)
    begin
        for i in 0 to ports-1 loop
            send_port(i).addr <= (others => '0');
            send_port(i).data <= (others => '0');
        end loop;

        -- ReCOP sends directly using the Lab2 TDMA-MIN port format
        send_port(0).addr <= recop_send.addr;
        send_port(0).data <= recop_send.data;

        -- Signal ASP sends to moving average at port 2
        send_port(1).addr <= pkt_to_addr(sig_send_pkt);
        send_port(1).data <= pkt_to_data(sig_send_pkt);

        -- Moving average ASP sends to symmetry at port 3
        send_port(2).addr <= pkt_to_addr(avg_send_pkt);
        send_port(2).data <= pkt_to_data(avg_send_pkt);

        -- Symmetry ASP sends to peak at port 4
        send_port(3).addr <= pkt_to_addr(sym_send_pkt);
        send_port(3).data <= pkt_to_data(sym_send_pkt);

        -- Peak ASP sends to debug sink at port 5
        send_port(4).addr <= pkt_to_addr(peak_send_pkt);
        send_port(4).data <= pkt_to_data(peak_send_pkt);
    end process;

    --------------------------------------------------------------------
    -- 16 kHz sample tick from 50 MHz clock
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
    -- Signal generator ASP
    --------------------------------------------------------------------
    u_signal : entity work.asp_signal_noc
        port map (
            clk        => clock,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            noc_recv   => sig_recv_pkt,
            noc_send   => sig_send_pkt,
            noc_ready  => '1'
        );

    --------------------------------------------------------------------
    -- Moving average ASP
    --------------------------------------------------------------------
    u_avg : entity work.moving_average_noc_asp
        port map (
            clk       => clock,
            reset_n   => reset_n,
            noc_recv  => avg_recv_pkt,
            noc_send  => avg_send_pkt,
            noc_ready => '1'
        );

    --------------------------------------------------------------------
    -- Symmetry / correlation ASP
    --------------------------------------------------------------------
    u_sym : entity work.symmetry_noc_asp
        port map (
            clk       => clock,
            reset_n   => reset_n,
            noc_recv  => sym_recv_pkt,
            noc_send  => sym_send_pkt,
            noc_ready => '1'
        );

    --------------------------------------------------------------------
    -- Peak detector ASP
    --------------------------------------------------------------------
    u_peak : entity work.peak_detector_noc_asp
        port map (
            clk       => clock,
            reset_n   => reset_n,
            noc_recv  => peak_recv_pkt,
            noc_send  => peak_send_pkt,
            noc_ready => '1'
        );

    --------------------------------------------------------------------
    -- Debug sink: latch final output at NoC port 5
    --------------------------------------------------------------------
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            rx_seen <= '0';
            recop_seen <= '0';
            sig_seen <= '0';
            avg_seen <= '0';
            sym_seen <= '0';
            peak_seen <= '0';

            latched_addr <= (others => '0');
            latched_data <= (others => '0');

            dbg_cfg_payload  <= (others => '0');
            dbg_sig_payload  <= (others => '0');
            dbg_avg_payload  <= (others => '0');
            dbg_sym_payload  <= (others => '0');
            dbg_peak_payload <= (others => '0');

            heartbeat_counter <= (others => '0');
        elsif rising_edge(clock) then
            heartbeat_counter <= heartbeat_counter + 1;

            -- Progress flags and demo payload latches.
            -- SW(8)=0: live update. SW(8)=1: freeze current displayed stage payloads.
            if SW(8) = '0' then
                if recv_port(1).data(recv_port(1).data'high) = '1' then
                    recop_seen <= '1';
                    dbg_cfg_payload <= recv_port(1).data(31 downto 0);
                end if;

                if recv_port(2).data(recv_port(2).data'high) = '1' then
                    sig_seen <= '1';
                    dbg_sig_payload <= recv_port(2).data(31 downto 0);
                end if;

                if recv_port(3).data(recv_port(3).data'high) = '1' then
                    avg_seen <= '1';
                    dbg_avg_payload <= recv_port(3).data(31 downto 0);
                end if;

                if recv_port(4).data(recv_port(4).data'high) = '1' then
                    sym_seen <= '1';
                    dbg_sym_payload <= recv_port(4).data(31 downto 0);
                end if;

                if recv_port(5).data(recv_port(5).data'high) = '1' then
                    peak_seen <= '1';
                    rx_seen <= '1';
                    latched_addr <= recv_port(5).addr;
                    latched_data <= recv_port(5).data(31 downto 0);
                    dbg_peak_payload <= recv_port(5).data(31 downto 0);
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Debug LEDs
    --------------------------------------------------------------------
    LEDR(0) <= reset_n;               -- running
    LEDR(1) <= debug_button_latched;  -- KEY1 event latched for ReCOP polling
    LEDR(2) <= debug_tx_trigger_seen; -- ReCOP wrote 0x3003, wrapper injected NoC packet
    LEDR(3) <= recop_seen;            -- ReCOP/config packet reached signal ASP port
    LEDR(4) <= sig_seen;              -- signal packet reached moving average port
    LEDR(5) <= avg_seen;              -- average packet reached symmetry port
    LEDR(6) <= sym_seen;              -- symmetry packet reached peak port
    LEDR(7) <= peak_seen;             -- peak/final packet reached debug port
    LEDR(8) <= rx_seen;               -- final received/latch updated
    LEDR(9) <= heartbeat_counter(25); -- heartbeat

    --------------------------------------------------------------------
    -- HEX debug display
    -- SW(8)=0 live updates payload latches. SW(8)=1 freezes them for reading.
    -- SW(2 downto 0) selects which pipeline payload to view:
    --   000 = ReCOP config at signal ASP. Expected: high=4000, low=0001
    --   001 = signal generator output at moving average. First low ~= 03F7
    --   010 = moving average output at symmetry. First low ~= 00FD
    --   011 = symmetry/correlation output at peak detector
    --   100 = peak detector/final event at debug sink
    -- SW(9)=0 shows low 16 bits. SW(9)=1 shows high 16 bits.
    --------------------------------------------------------------------
    process(SW, dbg_cfg_payload, dbg_sig_payload, dbg_avg_payload, dbg_sym_payload, dbg_peak_payload, latched_data)
        variable selected_payload : std_logic_vector(31 downto 0);
    begin
        case SW(2 downto 0) is
            when "000" => selected_payload := dbg_cfg_payload;
            when "001" => selected_payload := dbg_sig_payload;
            when "010" => selected_payload := dbg_avg_payload;
            when "011" => selected_payload := dbg_sym_payload;
            when "100" => selected_payload := dbg_peak_payload;
            when others => selected_payload := latched_data;
        end case;

        if SW(9) = '1' then
            display_word <= selected_payload(31 downto 16);
        else
            display_word <= selected_payload(15 downto 0);
        end if;
    end process;

    HEX0 <= hex7seg(display_word(3 downto 0));
    HEX1 <= hex7seg(display_word(7 downto 4));
    HEX2 <= hex7seg(display_word(11 downto 8));
    HEX3 <= hex7seg(display_word(15 downto 12));

end architecture;
