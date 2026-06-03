library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asp_peak is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        
        noc_recv     : in  std_logic_vector(39 downto 0);
        noc_send     : out std_logic_vector(39 downto 0);
        noc_ready    : in  std_logic
    );
end entity;

architecture rtl of asp_peak is

    type state_type is (STATE_INIT, STATE_WAIT_DATA, STATE_PROCESS_CHECK, STATE_SEND_TIME, STATE_SEND_AMP);
    signal current_state : state_type := STATE_INIT;

    signal dest_addr_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal peak_enabled   : std_logic := '0';

    signal samp_n0 : unsigned(15 downto 0) := (others => '0'); -- newest sample arriving
    signal samp_n1 : unsigned(15 downto 0) := (others => '0'); -- middle sample under evaluation
    signal samp_n2 : unsigned(15 downto 0) := (others => '0'); -- oldest sample

    signal global_cycle_counter : unsigned(23 downto 0) := (others => '0');
    
    -- registers to hold the final peak data
    signal final_captured_count : std_logic_vector(23 downto 0) := (others => '0');
    signal final_captured_amp   : std_logic_vector(15 downto 0) := (others => '0');

begin
    process(clk, reset)
    begin
        if reset = '0' then
            current_state <= STATE_INIT;
            dest_addr_reg <= (others => '0');
            peak_enabled  <= '0';
            samp_n0       <= (others => '0');
            samp_n1       <= (others => '0');
            samp_n2       <= (others => '0');
            global_cycle_counter <= (others => '0');
            final_captured_count <= (others => '0');
            final_captured_amp   <= (others => '0');
            noc_send      <= (others => '0');
            
        elsif rising_edge(clk) then
            noc_send <= (others => '0');

            case current_state is
                when STATE_INIT =>
                    -- wake up when receiving a config packet (valid bit 39 = 1, config mode = "1111")
                    if noc_recv(39) = '1' and noc_recv(31 downto 28) = "1111" then
                        dest_addr_reg <= noc_recv(27 downto 20); -- save destination address
                        peak_enabled  <= '1';
                        current_state <= STATE_WAIT_DATA;
                    end if;

                when STATE_WAIT_DATA =>
					 
						  noc_send <= (others => '0');
						  
                    -- listen for incoming data packets (valid bit 39 = 1)
                    if noc_recv(39) = '1' and peak_enabled = '1' then	
                        samp_n2 <= samp_n1;
                        samp_n1 <= samp_n0;
                        samp_n0 <= unsigned(noc_recv(15 downto 0));
                        
                        global_cycle_counter <= global_cycle_counter + 1;
                        
                        -- need at least 3 samples to compare a peak
                        if global_cycle_counter > 1 then
                            current_state <= STATE_PROCESS_CHECK;
                        end if;
                    end if;

                when STATE_PROCESS_CHECK =>
                    -- check if the middle sample is greater than its neighbours
                    if (samp_n1 > samp_n2) and (samp_n1 > samp_n0) then
                        -- save the time index and the amplitude
                        final_captured_count <= std_logic_vector(global_cycle_counter - 1);
                        final_captured_amp   <= std_logic_vector(samp_n1);
                        current_state        <= STATE_SEND_TIME;
                    else
                        current_state        <= STATE_WAIT_DATA;
                    end if;

                when STATE_SEND_TIME =>
                    -- send time index
                    if noc_ready = '1' then
                        noc_send(39)           <= '1';           
                        noc_send(38 downto 32) <= (others => '0'); 
                        noc_send(31 downto 24) <= dest_addr_reg; 
                        noc_send(23 downto 0)  <= final_captured_count;
                        
                        current_state          <= STATE_SEND_AMP;
                    end if;
                    
                when STATE_SEND_AMP =>
                    -- send peak value
                    if noc_ready = '1' then
                        noc_send(39)           <= '1';           
                        noc_send(38 downto 32) <= (others => '0'); 
                        noc_send(31 downto 24) <= dest_addr_reg; 
                        noc_send(23 downto 16) <= (others => '0'); -- padding
                        noc_send(15 downto 0)  <= final_captured_amp;
                        
                        current_state          <= STATE_WAIT_DATA;
                    end if;

                when others =>
                    current_state <= STATE_INIT;
            end case;
        end if;
    end process;
end architecture;