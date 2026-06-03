library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.recop_types.all;
use work.TdmaMinTypes.all;

entity recop_noc_wrapper is
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;  -- active-low reset from GP2 top

        -- External event from board/top-level. This is latched and then
        -- presented to ReCOP on SIP(0), so a short button press is not missed.
        button_event : in std_logic;

        send_port : out tdma_min_port;
        recv_port : in  tdma_min_port;

        -- Demo/debug outputs
        debug_button_latched : out std_logic;
        debug_tx_trigger_seen : out std_logic
    );
end entity recop_noc_wrapper;

architecture rtl of recop_noc_wrapper is

    signal reset : std_logic;

    -- Existing ReCOP external I/O/debug signals
    signal sip_s        : bit_16 := (others => '0');
    signal sop_s        : bit_16;
    signal dpcr_s       : bit_32;
    signal debug_bus_s  : bit_16;
    signal instr_done_s : bit_1;

    -- Exposed ReCOP data-memory bus
    signal cpu_addr  : bit_16;
    signal cpu_wdata : bit_16;
    signal cpu_rdata : bit_16 := (others => '0');
    signal cpu_wren  : bit_1;

    -- Memory-mapped NoC TX registers
    -- 0x3000 = destination address
    -- 0x3001 = packet data high word
    -- 0x3002 = packet data low word
    -- 0x3003 = trigger send
    signal reg_tx_addr    : tdma_min_addr := (others => '0');
    signal reg_tx_payload : std_logic_vector(31 downto 0) := (others => '0');

    -- Memory-mapped NoC RX/status registers
    -- 0x3004 = RX valid flag
    -- 0x3005 = RX packet high word
    -- 0x3006 = RX packet low word
    -- 0x3007 = clear RX valid flag
    signal rx_latched_addr    : tdma_min_addr := (others => '0');
    signal rx_latched_payload : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_valid           : std_logic := '0';

    -- Demo/event latch. KEY1 is asynchronous/human-speed; this makes it a
    -- stable polling flag for ReCOP. It is cleared when ReCOP actually sends.
    signal button_latched     : std_logic := '0';
    signal tx_trigger_seen    : std_logic := '0';

begin

    reset <= not reset_n;

    -- ReCOP polls SIP. Only SIP(0) is used here: 1 means button/event pending.
    sip_s <= (15 downto 1 => '0', 0 => button_latched);

    debug_button_latched  <= button_latched;
    debug_tx_trigger_seen <= tx_trigger_seen;

    --------------------------------------------------------------------
    -- ReCOP core. Program memory and normal data RAM remain inside the
    -- existing datapath. Only the high-address data-memory peripheral bus
    -- is exported to this wrapper.
    --------------------------------------------------------------------
    u_recop : entity work.recop_top
        port map (
            clk          => clk,
            reset        => reset,

            sip          => sip_s,
            sop          => sop_s,
            dpcr         => dpcr_s,

            dm_ext_addr  => cpu_addr,
            dm_ext_wdata => cpu_wdata,
            dm_ext_rdata => cpu_rdata,
            dm_ext_wren  => cpu_wren,

            debug_sel    => "1100",      -- PC on debug bus by default
            debug_bus    => debug_bus_s,
            instr_done   => instr_done_s
        );

    --------------------------------------------------------------------
    -- Read decoder for ReCOP loads from 0x3004-0x3006.
    --------------------------------------------------------------------
    process(cpu_addr, rx_valid, rx_latched_addr, rx_latched_payload)
    begin
        case cpu_addr is
            when x"3004" =>
                cpu_rdata <= (0 => rx_valid, others => '0');

            when x"3005" =>
                cpu_rdata <= rx_latched_payload(31 downto 16);

            when x"3006" =>
                cpu_rdata <= rx_latched_payload(15 downto 0);

            when others =>
                cpu_rdata <= (others => '0');
        end case;
    end process;

    --------------------------------------------------------------------
    -- NoC transmit/receive peripheral registers.
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_tx_addr     <= (others => '0');
            reg_tx_payload  <= (others => '0');
            send_port.addr  <= (others => '0');
            send_port.data  <= (others => '0');

            rx_latched_addr <= (others => '0');
            rx_latched_payload <= (others => '0');
            rx_valid        <= '0';

            button_latched  <= '0';
            tx_trigger_seen <= '0';

        elsif rising_edge(clk) then
            -- Default: no packet this cycle. A write to 0x3003 pulses valid data
            -- into the TDMA-MIN input for one clock cycle.
            send_port.addr <= (others => '0');
            send_port.data <= (others => '0');

            -- Latch external event until ReCOP consumes it by sending a packet.
            if button_event = '1' then
                button_latched <= '1';
            end if;

            -- Latch any packet routed back to ReCOP port 0.
            if recv_port.data(recv_port.data'high) = '1' then
                rx_latched_addr    <= recv_port.addr;
                rx_latched_payload <= recv_port.data(31 downto 0);
                rx_valid           <= '1';
            end if;

            -- Memory-mapped writes from ReCOP.
            if cpu_wren = '1' then
                case cpu_addr is
                    when x"3000" =>
                        reg_tx_addr <= cpu_wdata(7 downto 0);

                    when x"3001" =>
                        reg_tx_payload(31 downto 16) <= cpu_wdata;

                    when x"3002" =>
                        reg_tx_payload(15 downto 0) <= cpu_wdata;

                    when x"3003" =>
                        -- Only allow ReCOP to inject the NoC packet after the
                        -- external button event has actually been latched. This
                        -- makes the demo visibly button-controlled and prevents
                        -- any accidental start-up packet from running the chain.
                        if button_latched = '1' then
                            send_port.addr <= reg_tx_addr;
                            send_port.data <= '1' & reg_tx_payload;
                            tx_trigger_seen <= '1';
                            button_latched <= '0';
                        end if;

                    when x"3007" =>
                        rx_valid <= '0';

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
