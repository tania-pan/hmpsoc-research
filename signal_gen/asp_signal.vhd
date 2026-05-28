library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asp_signal is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        tick_16khz   : in  std_logic;
        
        noc_recv     : in  std_logic_vector(39 downto 0);
        noc_send     : out std_logic_vector(39 downto 0);
        noc_ready    : in  std_logic
    );
end entity;

architecture rtl of asp_signal is

    component signal_gen is
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            tick_16khz  : in  std_logic;
            signal_out  : out std_logic_vector(11 downto 0);
            data_ready  : out std_logic
        );
    end component;

    type state_type is (STATE_INIT, STATE_WAIT_ADC, STATE_SEND_PACKET);
    signal current_state : state_type := STATE_INIT;

    signal dest_addr_reg : std_logic_vector(7 downto 0) := (others => '0'); 
    signal mode_10_8_reg : std_logic := '0';                               
    signal adc_enabled   : std_logic := '0';                               

    signal core_signal_out : std_logic_vector(11 downto 0);
    signal core_data_ready : std_logic;
    signal sampled_data    : std_logic_vector(15 downto 0) := (others => '0');

begin

    adc_core : signal_gen
        port map (
            clk         => clk,
            reset       => reset,
            tick_16khz  => tick_16khz,
            signal_out  => core_signal_out,
            data_ready  => core_data_ready
        );

    process(clk, reset)
    begin
        if reset = '0' then
            current_state <= STATE_INIT;
            dest_addr_reg <= (others => '0');
            mode_10_8_reg <= '0';
            adc_enabled   <= '0';
            noc_send      <= (others => '0');
            sampled_data  <= (others => '0');
            
        elsif rising_edge(clk) then
            noc_send(39) <= '0'; 

            if noc_recv(39) = '1' and noc_recv(31 downto 28) = "1111" then 
                dest_addr_reg <= noc_recv(23 downto 16);
                mode_10_8_reg <= noc_recv(0);            
                adc_enabled   <= '1';                    
            end if;

            case current_state is
                
                when STATE_INIT =>
                    if adc_enabled = '1' then
                        current_state <= STATE_WAIT_ADC;
                    end if;

                when STATE_WAIT_ADC =>
                    if core_data_ready = '1' and adc_enabled = '1' then
                        
                        if mode_10_8_reg = '1' then
                            sampled_data <= "00000000" & core_signal_out(11 downto 4);
                        else
                            sampled_data <= "000000" & core_signal_out(11 downto 2);
                        end if;
                        
                        current_state <= STATE_SEND_PACKET;
                    end if;

                when STATE_SEND_PACKET =>
                    if noc_ready = '1' then
                        noc_send(39)           <= '1';           
                        noc_send(38 downto 32) <= (others => '0'); 
                        noc_send(31 downto 24) <= dest_addr_reg; 
                        
                        noc_send(23)           <= '1'; 
                        noc_send(22)           <= '0';
                        noc_send(21 downto 20) <= "00";
                        noc_send(19 downto 16) <= (others => '0');
                        
                        noc_send(15 downto 0)  <= sampled_data;
                        
                        current_state <= STATE_WAIT_ADC; 
                    end if;

                when others =>
                    current_state <= STATE_INIT;
            end case;
        end if;
    end process;

end architecture;