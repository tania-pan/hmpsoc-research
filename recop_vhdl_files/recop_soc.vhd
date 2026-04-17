-- hardware wrapper for DE1-SoC board

library ieee;
use ieee.std_logic_1164.all;
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
    signal manual_clk : std_logic;
    signal final_clk  : std_logic;
    signal reset_n    : std_logic;
    signal debug_bus_s : bit_16;
    signal sop_s       : bit_16;
begin

    -- SW(9) selects between 50MHz and manual step
    -- KEY(1) provides the clock pulse in manual mode
    reset_n <= not KEY(0); -- KEYs active-low, CPU usually wants active-high reset
    
    process(CLOCK_50)
    begin
        if SW(9) = '1' then
            final_clk <= CLOCK_50;
        else
            final_clk <= KEY(1); 
        end if;
    end process;

    -- instantiate processor
    processor_inst : entity work.recop_top
        port map (
            clk       => final_clk,
            reset     => reset_n,
            sip       => "000000" & SW(9 downto 0),
            sop       => sop_s,
            debug_sel => SW(3 downto 0), -- use first 4 switches for debug select
            debug_bus => debug_bus_s
        );

    -- map outputs
    LEDR <= sop_s(9 downto 0); -- display SOP on LEDs

    -- drive hex displays for debug bus
    h0: entity work.seven_seg_decoder port map(debug_bus_s(3 downto 0), HEX0);
    h1: entity work.seven_seg_decoder port map(debug_bus_s(7 downto 4), HEX1);
    h2: entity work.seven_seg_decoder port map(debug_bus_s(11 downto 8), HEX2);
    h3: entity work.seven_seg_decoder port map(debug_bus_s(15 downto 12), HEX3);

end architecture;