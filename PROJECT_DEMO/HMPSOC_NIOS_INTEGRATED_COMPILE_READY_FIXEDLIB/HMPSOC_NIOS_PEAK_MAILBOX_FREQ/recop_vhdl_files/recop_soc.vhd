-- hardware wrapper for DE1-SoC board

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- added for decimal conversion
use work.recop_types.all;

entity recop_soc is
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(3 downto 0); -- buttons
        SW       : in  std_logic_vector(9 downto 0); -- switches
        LEDR     : out std_logic_vector(9 downto 0); -- LEDs
        HEX0, HEX1, HEX2, HEX3 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of recop_soc is
    signal manual_clk  : std_logic := '0';
    signal final_clk   : std_logic;
    signal reset_n     : std_logic;
    signal debug_bus_s : bit_16;
    signal sop_s       : bit_16;
    signal instr_done  : bit_1;

    -- manual-step controller
    signal running      : std_logic := '0';
    signal key1_prev    : std_logic := '1';
    signal stop_pending : std_logic := '0';

    -- decimal digits for HEX display
    signal dec0, dec1, dec2, dec3 : std_logic_vector(3 downto 0);
begin

    -- SW(9) selects between 50MHz and manual step
    -- KEY(1) provides the clock pulse in manual mode
    reset_n <= not KEY(0); -- KEYs active-low, CPU usually wants active-high reset

    -- free-run uses 50 MHz directly, manual mode uses generated step clock
    final_clk <= CLOCK_50 when SW(9) = '1' else manual_clk;

    -- manual mode: one KEY(1) press executes one full instruction
    process(CLOCK_50, reset_n)
    begin
        if reset_n = '1' then
            manual_clk    <= '0';
            running       <= '0';
            key1_prev     <= '1';
            stop_pending  <= '0';
        elsif rising_edge(CLOCK_50) then
            key1_prev <= KEY(1);

            if SW(9) = '0' then
                if running = '0' then
                    manual_clk   <= '0';
                    stop_pending <= '0';

                    -- detect button press (KEY is active-low)
                    if key1_prev = '1' and KEY(1) = '0' then
                        running <= '1';
                    end if;
                else
                    -- generate clock pulses until current instruction finishes
                    if manual_clk = '0' then
                        -- if current CU state says instruction is done,
                        -- still issue one final rising edge so writes/PC update happen
                        if instr_done = '1' then
                            stop_pending <= '1';
                        end if;
                        manual_clk <= '1';
                    else
                        manual_clk <= '0';

                        if stop_pending = '1' then
                            running      <= '0';
                            stop_pending <= '0';
                        end if;
                    end if;
                end if;
            else
                -- free-running mode
                manual_clk   <= '0';
                running      <= '0';
                stop_pending <= '0';
            end if;
        end if;
    end process;

    -- convert debug bus to 4 decimal digits for HEX display
    process(debug_bus_s)
        variable val : integer;
    begin
        val := to_integer(unsigned(debug_bus_s));

        -- limit to 0..9999 so it fits on 4 decimal digits
        if val > 9999 then
            val := 9999;
        end if;

        dec0 <= std_logic_vector(to_unsigned(val mod 10, 4));
        dec1 <= std_logic_vector(to_unsigned((val / 10) mod 10, 4));
        dec2 <= std_logic_vector(to_unsigned((val / 100) mod 10, 4));
        dec3 <= std_logic_vector(to_unsigned((val / 1000) mod 10, 4));
    end process;

    -- instantiate processor
    processor_inst : entity work.recop_top
        port map (
            clk        => final_clk,
            reset      => reset_n,
            sip        => "000000" & SW(9 downto 0),
            sop        => sop_s,
            debug_sel  => SW(3 downto 0), -- use first 4 switches for debug select
            debug_bus  => debug_bus_s,
            instr_done => instr_done
        );

    -- map outputs
    LEDR <= sop_s(9 downto 0); -- display SOP on LEDs

    -- drive hex displays with decimal digits instead of hex nibbles
    h0: entity work.seven_seg_decoder port map(dec0, HEX0);
    h1: entity work.seven_seg_decoder port map(dec1, HEX1);
    h2: entity work.seven_seg_decoder port map(dec2, HEX2);
    h3: entity work.seven_seg_decoder port map(dec3, HEX3);

end architecture;