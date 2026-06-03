library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gp2_asp_de1_top is
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

architecture rtl of gp2_asp_de1_top is

    signal reset_n      : std_logic;

    signal tick_16khz   : std_logic := '0';
    signal tick_counter : unsigned(11 downto 0) := (others => '0');

    signal config_pkt   : std_logic_vector(39 downto 0) := (others => '0');
    signal config_sent  : std_logic := '0';

    signal final_pkt    : std_logic_vector(39 downto 0);
    signal peak_irq     : std_logic;

    -- Debug/latch signals so tiny one-clock pulses stay visible
    signal latched_pkt      : std_logic_vector(39 downto 0) := (others => '0');
    signal latched_peak     : std_logic := '0';
    signal tick_seen        : std_logic := '0';
    signal final_seen       : std_logic := '0';
    signal heartbeat_counter: unsigned(25 downto 0) := (others => '0');

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

begin

    --------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------
    -- DE1-SoC KEY0:
    -- released = '1'
    -- pressed  = '0'
    --
    -- gp2_asp_chain_stub expects reset_n:
    -- reset_n = '1' means running
    -- reset_n = '0' means reset active
    --------------------------------------------------------------------
    reset_n <= KEY(0);

    --------------------------------------------------------------------
    -- Heartbeat counter: proves CLOCK_50/top-level is alive
    --------------------------------------------------------------------
    process(CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            heartbeat_counter <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            heartbeat_counter <= heartbeat_counter + 1;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Generate approx 16 kHz tick from 50 MHz clock
    -- 50 MHz / 3125 = 16 kHz
    --------------------------------------------------------------------
    process(CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            tick_counter <= (others => '0');
            tick_16khz   <= '0';
            tick_seen    <= '0';
        elsif rising_edge(CLOCK_50) then
            if tick_counter = 3124 then
                tick_counter <= (others => '0');
                tick_16khz   <= '1';
                tick_seen    <= '1';       -- latch so it stays visible
            else
                tick_counter <= tick_counter + 1;
                tick_16khz   <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Send one CONFIG packet after reset to enable the signal generator
    --------------------------------------------------------------------
    process(CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            config_pkt  <= (others => '0');
            config_sent <= '0';
        elsif rising_edge(CLOCK_50) then
            if config_sent = '0' then
                -- Packet format:
                -- bit 39      = valid = 1
                -- bits 38..35 = CONFIG = 1111
                -- bits 34..32 = destination = 001
                -- payload bits 31..29 = next destination = 010
                -- payload bit 0 = enable
                config_pkt  <= "1" & "1111" & "001" & x"40000001";
                config_sent <= '1';
            else
                config_pkt <= (others => '0');
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- ASP chain
    --------------------------------------------------------------------
    dut : entity work.gp2_asp_chain_stub
        port map (
            clk        => CLOCK_50,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            config_pkt => config_pkt,
            final_pkt  => final_pkt,
            peak_irq   => peak_irq
        );

    --------------------------------------------------------------------
    -- Latch final output so it stays visible on LEDs/HEX
    --------------------------------------------------------------------
    process(CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            latched_pkt  <= (others => '0');
            latched_peak <= '0';
            final_seen   <= '0';
        elsif rising_edge(CLOCK_50) then
            if final_pkt(39) = '1' then
                latched_pkt <= final_pkt;
                final_seen  <= '1';
            end if;

            if peak_irq = '1' then
                latched_peak <= '1';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- LED debug mux
    --
    -- SW0 = 0: dumb board/top-level debug
    -- SW0 = 1: ASP packet debug
    --------------------------------------------------------------------
    process(SW, KEY, reset_n, config_sent, tick_seen, final_seen, latched_peak, final_pkt, tick_16khz, heartbeat_counter, latched_pkt)
    begin
        if SW(0) = '0' then
            -- Dumb debug mode
            LEDR(0) <= KEY(0);                  -- changes with KEY0
            LEDR(1) <= reset_n;                 -- should be 1 when released
            LEDR(2) <= SW(1);                   -- proves switches/pins work
            LEDR(3) <= config_sent;             -- goes high after config sent
            LEDR(4) <= tick_seen;               -- goes high once tick runs
            LEDR(5) <= final_seen;              -- goes high if final packet ever produced
            LEDR(6) <= latched_peak;            -- goes high if peak IRQ ever happened
            LEDR(7) <= final_pkt(39);           -- live final valid, probably too fast
            LEDR(8) <= tick_16khz;              -- live tick, probably too fast
            LEDR(9) <= heartbeat_counter(25);   -- slow blink = clock alive
        else
            -- ASP packet debug mode
            LEDR(0) <= latched_pkt(39);              -- latched valid
            LEDR(1) <= latched_peak;                 -- latched peak IRQ
            LEDR(5 downto 2) <= latched_pkt(38 downto 35); -- packet type
            LEDR(8 downto 6) <= latched_pkt(34 downto 32); -- destination
            LEDR(9) <= heartbeat_counter(25);        -- heartbeat
        end if;
    end process;

    --------------------------------------------------------------------
    -- Show low 16 bits of latched output payload on HEX
    --------------------------------------------------------------------
    HEX0 <= hex7seg(latched_pkt(3 downto 0));
    HEX1 <= hex7seg(latched_pkt(7 downto 4));
    HEX2 <= hex7seg(latched_pkt(11 downto 8));
    HEX3 <= hex7seg(latched_pkt(15 downto 12));

end architecture;