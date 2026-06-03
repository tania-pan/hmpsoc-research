library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Import the new GP-2 TDMA-MIN Network Types
library work;
use work.TdmaMinTypes.all;

entity recop_noc_wrapper is
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;  -- Active-low reset as seen in gp2_tdma_full_chain_top
        
        -- New TDMA-MIN Structured Ports
        send_port    : out tdma_min_port;
        recv_port    : in  tdma_min_port
    );
end entity recop_noc_wrapper;

architecture rtl of recop_noc_wrapper is

    -- =========================================================
    -- COMPONENT DECLARATIONS (Ensure these match your GP-1 files)
    -- =========================================================
    component recop_top is
        port (
            clk              : in  std_logic;
            reset            : in  std_logic;
            data_address     : out std_logic_vector(15 downto 0);
            data_out_bus     : out std_logic_vector(15 downto 0);
            data_in_bus      : in  std_logic_vector(15 downto 0);
            wren             : out std_logic;
            pm_address       : out std_logic_vector(15 downto 0);
            pm_data          : in  std_logic_vector(15 downto 0)
        );
    end component;

    component data_mem is
        port (
            address : in  std_logic_vector(11 downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(15 downto 0);
            wren    : in  std_logic;
            q       : out std_logic_vector(15 downto 0)
        );
    end component;
    
    -- Optional: If your instruction memory is external to recop_top
    component prog_mem is
        port (
            address : in  std_logic_vector(15 downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector(15 downto 0)
        );
    end component;

    -- =========================================================
    -- SIGNAL DECLARATIONS
    -- =========================================================
    -- CPU buses
    signal cpu_data_addr : std_logic_vector(15 downto 0);
    signal cpu_data_out  : std_logic_vector(15 downto 0);
    signal cpu_data_in   : std_logic_vector(15 downto 0);
    signal cpu_wren      : std_logic;
    
    signal cpu_pm_addr   : std_logic_vector(15 downto 0);
    signal cpu_pm_data   : std_logic_vector(15 downto 0);

    -- Data Memory Signals
    signal ram_data_out  : std_logic_vector(15 downto 0);
    signal ram_wren      : std_logic;

    -- TX (Transmit) Registers (Mapped to $0x3000 - $0x3003)
    signal reg_tx_addr   : tdma_min_addr := (others => '0');
    signal reg_tx_data   : tdma_min_data := (others => '0');
    
    -- RX (Receive) Latch Registers (Mapped to $0x3004 - $0x3007)
    signal rx_latched_addr : tdma_min_addr := (others => '0');
    signal rx_latched_data : tdma_min_data := (others => '0');
    signal rx_valid        : std_logic := '0';

begin

    -- =========================================================
    -- PROCESSOR & MEMORY INSTANTIATION
    -- =========================================================
    cpu_inst : recop_top
        port map (
            clk          => clk,
            reset        => reset_n, -- Note: Connect to reset_n
            data_address => cpu_data_addr,
            data_out_bus => cpu_data_out,
            data_in_bus  => cpu_data_in,
            wren         => cpu_wren,
            pm_address   => cpu_pm_addr, 
            pm_data      => cpu_pm_data 
        );

    -- Instruction Memory (Assuming it contains your instructions.mif)
    pm_inst : prog_mem
        port map (
            address => cpu_pm_addr,
            clock   => clk,
            q       => cpu_pm_data
        );

    -- Base RAM writes: Only enable if address is in standard memory bounds (e.g. 0x0000 - 0x0FFF)
    ram_wren <= cpu_wren when cpu_data_addr(15 downto 12) = x"0" else '0';

    dmem_inst : data_mem
        port map (
            address => cpu_data_addr(11 downto 0),
            clock   => clk,
            data    => cpu_data_out,
            wren    => ram_wren,
            q       => ram_data_out
        );

    -- =========================================================
    -- READ ADDRESS DECODER (Includes RX Latch extraction)
    -- =========================================================
    process(cpu_data_addr, ram_data_out, rx_valid, rx_latched_data)
    begin
        if cpu_data_addr = x"3004" then
            -- Let Software read address 0x3004 to check if a packet arrived
            cpu_data_in <= (0 => rx_valid, others => '0');
            
        elsif cpu_data_addr = x"3005" then
            -- Read High Payload Word of received packet
            cpu_data_in <= rx_latched_data(31 downto 16);
            
        elsif cpu_data_addr = x"3006" then
            -- Read Low Payload Word of received packet
            cpu_data_in <= rx_latched_data(15 downto 0);
            
        else
            -- Default: read standard Data RAM
            cpu_data_in <= ram_data_out;
        end if;
    end process;

    -- =========================================================
    -- NETWORK TX (TRANSMIT) AND RX (RECEIVE) LOGIC
    -- =========================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_tx_addr <= (others => '0');
            reg_tx_data <= (others => '0');
            send_port.addr <= (others => '0');
            send_port.data <= (others => '0');
            
            rx_latched_addr <= (others => '0');
            rx_latched_data <= (others => '0');
            rx_valid <= '0';
            
        elsif rising_edge(clk) then
            
            -- -------------------------------------------------
            -- 1. Default TX State: Clear the output port
            -- This ensures we only fire the packet for 1 clock cycle
            -- preventing the TDMA FIFOs from double-queuing it.
            -- -------------------------------------------------
            send_port.addr <= (others => '0');
            send_port.data <= (others => '0');

            -- -------------------------------------------------
            -- 2. RX (Receive) Catching Logic
            -- GP2 TDMA-MIN relies on Bit 31 of data to act as the "Valid" flag.
            -- -------------------------------------------------
            if recv_port.data(31) = '1' then
                rx_latched_addr <= recv_port.addr;
                rx_latched_data <= recv_port.data;
                rx_valid <= '1';
            end if;

            -- -------------------------------------------------
            -- 3. Memory Write Intercept (TX Setup & RX Acknowledge)
            -- -------------------------------------------------
            if cpu_wren = '1' then
                case cpu_data_addr is
                    
                    when x"3000" => 
                        -- Capture 8-bit Target ID
                        reg_tx_addr <= cpu_data_out(7 downto 0);
                        
                    when x"3001" => 
                        -- Capture 16-bit Payload High Word
                        reg_tx_data(31 downto 16) <= cpu_data_out;
                        
                    when x"3002" => 
                        -- Capture 16-bit Payload Low Word
                        reg_tx_data(15 downto 0) <= cpu_data_out;
                        
                    when x"3003" => 
                        -- TRIGGER EVENT: Push directly to the NoC!
                        -- Because the software handles setting bit 31 (Valid flag) inside 
                        -- the 32-bit payload, we just push the registers raw to the port.
                        send_port.addr <= reg_tx_addr;
                        send_port.data <= reg_tx_data;

                    when x"3007" =>
                        -- ACKNOWLEDGE RX: Software writing to 0x3007 clears the RX flag
                        rx_valid <= '0';
                        
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;