library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;

entity recop_noc_wrapper is
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;  -- active-low reset from GP2 top

        send_port : out tdma_min_port;
        recv_port : in  tdma_min_port
    );
end entity recop_noc_wrapper;

architecture rtl of recop_noc_wrapper is

    --------------------------------------------------------------------
    -- ReCOP core
    -- NOTE: reset on recop_top is assumed active-high, so reset_n is
    -- inverted before being passed in.
    --------------------------------------------------------------------
    component recop_top is
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            data_address : out std_logic_vector(15 downto 0);
            data_out_bus : out std_logic_vector(15 downto 0);
            data_in_bus  : in  std_logic_vector(15 downto 0);
            wren         : out std_logic;
            pm_address   : out std_logic_vector(15 downto 0);
            pm_data      : in  std_logic_vector(15 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Data memory
    --------------------------------------------------------------------
    component data_mem is
        port (
            address : in  std_logic_vector(11 downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(15 downto 0);
            wren    : in  std_logic;
            q       : out std_logic_vector(15 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- CPU buses
    --------------------------------------------------------------------
    signal reset          : std_logic;

    signal cpu_data_addr  : std_logic_vector(15 downto 0);
    signal cpu_data_out   : std_logic_vector(15 downto 0);
    signal cpu_data_in    : std_logic_vector(15 downto 0);
    signal cpu_wren       : std_logic;

    signal cpu_pm_addr    : std_logic_vector(15 downto 0);
    signal cpu_pm_data    : std_logic_vector(15 downto 0);

    signal ram_data_out   : std_logic_vector(15 downto 0);
    signal ram_wren       : std_logic;

    --------------------------------------------------------------------
    -- Memory-mapped NoC TX registers
    -- 0x3000 = destination address
    -- 0x3001 = payload high word
    -- 0x3002 = payload low word
    -- 0x3003 = trigger send
    --------------------------------------------------------------------
    signal reg_tx_addr    : tdma_min_addr := (others => '0');
    signal reg_tx_data    : tdma_min_data := (others => '0');

    --------------------------------------------------------------------
    -- Memory-mapped NoC RX registers
    -- 0x3004 = RX valid
    -- 0x3005 = RX data high word
    -- 0x3006 = RX data low word
    -- 0x3007 = clear RX valid
    --------------------------------------------------------------------
    signal rx_latched_addr : tdma_min_addr := (others => '0');
    signal rx_latched_data : tdma_min_data := (others => '0');
    signal rx_valid        : std_logic := '0';

begin

    reset <= not reset_n;

    --------------------------------------------------------------------
    -- ReCOP processor
    --------------------------------------------------------------------
    cpu_inst : recop_top
        port map (
            clk          => clk,
            reset        => reset,
            data_address => cpu_data_addr,
            data_out_bus => cpu_data_out,
            data_in_bus  => cpu_data_in,
            wren         => cpu_wren,
            pm_address   => cpu_pm_addr,
            pm_data      => cpu_pm_data
        );

    --------------------------------------------------------------------
    -- Program memory
    -- IMPORTANT:
    -- This assumes your generated instruction ROM entity is named prog_mem
    -- and has this port shape:
    --     address : in  std_logic_vector(11 downto 0);
    --     clock   : in  std_logic;
    --     q       : out std_logic_vector(15 downto 0)
    --
    -- If your ROM address port is 16 bits wide, change the address map to:
    --     address => cpu_pm_addr
    --
    -- If your ROM entity has another name, change work.prog_mem to that name.
    --------------------------------------------------------------------
    pm_inst : entity work.prog_mem
        port map (
            address => cpu_pm_addr(14 downto 0),
            clock   => clk,
            q       => cpu_pm_data
        );

    --------------------------------------------------------------------
    -- Data memory
    --------------------------------------------------------------------
    ram_wren <= cpu_wren when cpu_data_addr(15 downto 12) = x"0" else '0';

    dmem_inst : data_mem
        port map (
            address => cpu_data_addr(11 downto 0),
            clock   => clk,
            data    => cpu_data_out,
            wren    => ram_wren,
            q       => ram_data_out
        );

    --------------------------------------------------------------------
    -- Read decoder
    --------------------------------------------------------------------
    process(cpu_data_addr, ram_data_out, rx_valid, rx_latched_addr, rx_latched_data)
    begin
        case cpu_data_addr is
            when x"3004" =>
                cpu_data_in <= (0 => rx_valid, others => '0');

            when x"3005" =>
                cpu_data_in <= rx_latched_data(31 downto 16);

            when x"3006" =>
                cpu_data_in <= rx_latched_data(15 downto 0);

            when others =>
                cpu_data_in <= ram_data_out;
        end case;
    end process;

    --------------------------------------------------------------------
    -- NoC TX/RX logic
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_tx_addr     <= (others => '0');
            reg_tx_data     <= (others => '0');
            send_port.addr  <= (others => '0');
            send_port.data  <= (others => '0');

            rx_latched_addr <= (others => '0');
            rx_latched_data <= (others => '0');
            rx_valid        <= '0';

        elsif rising_edge(clk) then
            -- Default: no packet sent this cycle
            send_port.addr <= (others => '0');
            send_port.data <= (others => '0');

            -- Latch incoming packet when TDMA-MIN valid bit is set
            if recv_port.data(31) = '1' then
                rx_latched_addr <= recv_port.addr;
                rx_latched_data <= recv_port.data;
                rx_valid        <= '1';
            end if;

            -- Memory-mapped writes from ReCOP
            if cpu_wren = '1' then
                case cpu_data_addr is
                    when x"3000" =>
                        reg_tx_addr <= cpu_data_out(7 downto 0);

                    when x"3001" =>
                        reg_tx_data(31 downto 16) <= cpu_data_out;

                    when x"3002" =>
                        reg_tx_data(15 downto 0) <= cpu_data_out;

                    when x"3003" =>
                        send_port.addr <= reg_tx_addr;
                        send_port.data <= reg_tx_data;

                    when x"3007" =>
                        rx_valid <= '0';

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
