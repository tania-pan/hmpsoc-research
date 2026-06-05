library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;
use work.gp2_packet_pkg.all;

library Nios_V1;

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
    -- port 5 = debug sink (unused in Nios-mailbox demo)
    -- port 6 = Nios peak mailbox
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
    signal peak_detected_s : std_logic := '0';

    -- Nios mailbox signals. In a full Platform Designer system these would
    -- connect to PIO/Avalon-MM registers read by Nios software.
    signal nios_peak_valid      : std_logic := '0';
    signal nios_peak_payload    : std_logic_vector(31 downto 0) := (others => '0');
    signal nios_peak_count      : std_logic_vector(31 downto 0) := (others => '0');
    signal nios_mailbox_overflow: std_logic := '0';
    signal nios_packet_pulse    : std_logic := '0';
    signal nios_clear           : std_logic := '0';
    signal nios_clear_from_cpu  : std_logic := '0';
    signal nios_leds            : std_logic_vector(7 downto 0) := (others => '0');

    signal rx_seen      : std_logic := '0';
    signal latched_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal latched_data : std_logic_vector(31 downto 0) := (others => '0');

    -- Latched payloads at each pipeline boundary for demo/HEX debug.
    -- Simplified display controls:
    --   no stage switch = ReCOP config packet
    --   SW0 = moving average output
    --   SW1 = symmetry/correlation output
    --   SW2 = peak detector output
    --   SW3 = signal generator output
    --   SW8 = manual freeze of live values
    --   SW9 = high/low 16-bit word select
    signal dbg_cfg_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- ReCOP -> signal ASP, expected 0x40000001
    signal dbg_sig_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- signal -> moving average, first low16 approx 0x03F7
    signal dbg_avg_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- moving average -> symmetry, first low16 approx 0x00FD
    signal dbg_sym_payload  : std_logic_vector(31 downto 0) := (others => '0'); -- symmetry -> peak, correlation result
    signal dbg_peak_payload : std_logic_vector(31 downto 0) := (others => '0'); -- peak -> debug sink, final/event value
    signal display_word     : std_logic_vector(15 downto 0) := (others => '0');

    -- Peak-triggered debug snapshot.
    -- SW(7) low->high arms snapshot-on-next-peak. KEY2 clears/re-arms the snapshot.
    signal snap_valid        : std_logic := '0';
    signal snap_cfg_payload  : std_logic_vector(31 downto 0) := (others => '0');
    signal snap_sig_payload  : std_logic_vector(31 downto 0) := (others => '0');
    signal snap_avg_payload  : std_logic_vector(31 downto 0) := (others => '0');
    signal snap_sym_payload  : std_logic_vector(31 downto 0) := (others => '0');
    signal snap_peak_payload : std_logic_vector(31 downto 0) := (others => '0');

    -- Snapshot arm logic. SW7 is edge-detected so holding SW7 high during
    -- reset does not immediately take an arbitrary snapshot. Toggle SW7
    -- low->high after the pipeline is running to arm capture of the next
    -- peak-detector output packet.
    signal snap_armed : std_logic := '0';
    signal sw7_prev   : std_logic := '0';

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
            mode_select           => SW(4), -- SW4: 0=40 Hz, 1=80 Hz live signal mode
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
        generic map (
            DEFAULT_NEXT_DEST => "110"  -- peak detector sends event packets to Nios mailbox at NoC port 6
        )
        port map (
            clk       => clock,
            reset_n   => reset_n,
            noc_recv       => peak_recv_pkt,
            noc_send       => peak_send_pkt,
            noc_ready      => '1',
            peak_detected => peak_detected_s
        );



    --------------------------------------------------------------------
    -- Nios peak mailbox on NoC port 6
    --
    -- Peak detector packets are routed here. The mailbox latches the most
    -- recent peak payload and holds peak_valid high until cleared. This is
    -- the clean interface for Nios polling.
    --
    -- Nios clears the mailbox through peak_clear_pio. KEY2 is kept as a
    -- manual board-level clear so the demo still works without running
    -- the Nios software.
    --------------------------------------------------------------------
    nios_clear <= nios_clear_from_cpu or (not KEY(2));

    u_nios_mailbox : entity work.nios_noc_mailbox
        port map (
            clk            => clock,
            reset_n        => reset_n,
            recv_port      => recv_port(6),
            peak_clear_i   => nios_clear,
            peak_valid_o   => nios_peak_valid,
            peak_payload_o => nios_peak_payload,
            peak_count_o   => nios_peak_count,
            overflow_o     => nios_mailbox_overflow,
            packet_pulse_o => nios_packet_pulse
        );

    --------------------------------------------------------------------
    -- Nios II Platform Designer system
    --
    -- Nios reads the peak mailbox through exported PIOs:
    --   peak_valid  : 1-bit input PIO
    --   peak_payload: 32-bit input PIO
    --   peak_clear  : 1-bit output PIO
    --
    -- The Nios C program polls peak_valid, reads peak_payload, calculates
    -- frequency = 16000 / (2 * (payload + 1)), then pulses peak_clear.
    --------------------------------------------------------------------
    u_nios : entity Nios_V1.Nios_V1
        port map (
            clk_clk                                     => clock,
            reset_reset_n                               => reset_n,
            peak_valid_pio_external_connection_export   => nios_peak_valid,
            peak_payload_pio_external_connection_export => nios_peak_payload,
            peak_clear_pio_external_connection_export   => nios_clear_from_cpu,
            pio_0_external_connection_export            => nios_leds
        );


    --------------------------------------------------------------------
    -- Debug/Nios sink: latch final output at NoC port 6
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

            snap_valid        <= '0';
            snap_cfg_payload  <= (others => '0');
            snap_sig_payload  <= (others => '0');
            snap_avg_payload  <= (others => '0');
            snap_sym_payload  <= (others => '0');
            snap_peak_payload <= (others => '0');
            snap_armed        <= '0';
            sw7_prev          <= SW(7);

            heartbeat_counter <= (others => '0');
        elsif rising_edge(clock) then
            heartbeat_counter <= heartbeat_counter + 1;

            -- Progress flags and demo payload latches.
            -- SW(8)=0: live update. SW(8)=1: manual freeze of live debug registers.
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

                if recv_port(6).data(recv_port(6).data'high) = '1' then
                    peak_seen <= '1';
                    rx_seen <= '1';
                    latched_addr <= recv_port(6).addr;
                    latched_data <= recv_port(6).data(31 downto 0);
                    dbg_peak_payload <= recv_port(6).data(31 downto 0);
                end if;
            end if;

            -- KEY2 clears the peak snapshot and disarms capture.
            if KEY(2) = '0' then
                snap_valid <= '0';
                snap_armed <= '0';

            -- SW7 is an ARM switch, not a level-sensitive freeze.
            -- Toggle SW7 low->high after the pipeline is running. This arms
            -- capture of the next peak-detector output packet only.
            elsif SW(7) = '1' and sw7_prev = '0' then
                snap_valid <= '0';
                snap_armed <= '1';

            -- Once armed, capture exactly one peak-detector output packet.
            -- recv_port(6) only receives the peak detector's event packets,
            -- so this freezes a meaningful peak event rather than an arbitrary
            -- live value. The real pipeline continues running.
            elsif snap_armed = '1' and recv_port(6).data(recv_port(6).data'high) = '1' then
                snap_cfg_payload  <= dbg_cfg_payload;
                snap_sig_payload  <= dbg_sig_payload;
                snap_avg_payload  <= dbg_avg_payload;
                snap_sym_payload  <= dbg_sym_payload;
                snap_peak_payload <= recv_port(6).data(31 downto 0);
                snap_valid        <= '1';
                snap_armed        <= '0';
            end if;

            sw7_prev <= SW(7);
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
    LEDR(7) <= peak_seen;             -- peak packet reached Nios mailbox port
    LEDR(8) <= snap_armed or snap_valid or nios_peak_valid; -- snapshot/mailbox valid
    LEDR(9) <= heartbeat_counter(25); -- heartbeat

    --------------------------------------------------------------------
    -- HEX debug display
    -- Simple display controls:
    --   all SW0..SW3 off = ReCOP config packet. Expected: high=4000, low=0001
    --   SW0 = moving average output
    --   SW1 = symmetry/correlation output
    --   SW2 = peak detector output. For period-400 sine, expected low word ~= 00C7
    --   SW3 = signal generator output
    --   SW7 = arm snapshot on next peak event
    --   SW8 = manual freeze of live payload latches
    --   SW9 = 0 low 16 bits, SW9 = 1 high 16 bits
    -- If multiple SW0..SW3 are on, highest priority is SW2, then SW1, SW0, SW3.
    --------------------------------------------------------------------
    process(SW, snap_valid,
            dbg_cfg_payload, dbg_sig_payload, dbg_avg_payload, dbg_sym_payload, dbg_peak_payload,
            snap_cfg_payload, snap_sig_payload, snap_avg_payload, snap_sym_payload, snap_peak_payload)
        variable selected_payload : std_logic_vector(31 downto 0);
    begin
        if snap_valid = '1' then
            -- Frozen peak snapshot values
            if SW(2) = '1' then
                selected_payload := snap_peak_payload;
            elsif SW(1) = '1' then
                selected_payload := snap_sym_payload;
            elsif SW(0) = '1' then
                selected_payload := snap_avg_payload;
            elsif SW(3) = '1' then
                selected_payload := snap_sig_payload;
            else
                selected_payload := snap_cfg_payload;
            end if;
        else
            -- Live/latest values
            if SW(2) = '1' then
                selected_payload := dbg_peak_payload;
            elsif SW(1) = '1' then
                selected_payload := dbg_sym_payload;
            elsif SW(0) = '1' then
                selected_payload := dbg_avg_payload;
            elsif SW(3) = '1' then
                selected_payload := dbg_sig_payload;
            else
                selected_payload := dbg_cfg_payload;
            end if;
        end if;

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
