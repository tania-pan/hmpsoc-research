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

    signal reset        : std_logic;
    signal final_pkt    : std_logic_vector(39 downto 0);
    signal final_payload: std_logic_vector(31 downto 0);
    signal final_valid  : std_logic;
    signal peak_irq     : std_logic;

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

    -- KEY0 is active-low on DE1-SoC
    reset <= not KEY(0);

    dut : entity work.gp2_asp_chain_stub
        port map (
            clk           => CLOCK_50,
            reset         => reset,
            final_pkt     => final_pkt,
            final_payload => final_payload,
            final_valid   => final_valid,
            peak_irq      => peak_irq
        );

    LEDR(0) <= final_valid;
    LEDR(1) <= peak_irq;
    LEDR(9 downto 2) <= final_pkt(39 downto 32);

    HEX0 <= hex7seg(final_payload(3 downto 0));
    HEX1 <= hex7seg(final_payload(7 downto 4));
    HEX2 <= hex7seg(final_payload(11 downto 8));
    HEX3 <= hex7seg(final_payload(15 downto 12));

end architecture;