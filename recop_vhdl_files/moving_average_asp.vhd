--Moving Average Filter ASP
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MovingAverageAsp is
    generic (
        TARGET_PORT : std_logic_vector(7 downto 0) := x"02";
        MAX_CLIP    : signed(15 downto 0) := to_signed(4096, 16);
        MIN_CLIP    : signed(15 downto 0) := to_signed(-4096, 16)
    );
    port (
        clock          : in  std_logic;
        recv_slot_addr : in  std_logic_vector(7 downto 0);
        recv_slot_data : in  std_logic_vector(31 downto 0);
        send_slot_addr : out std_logic_vector(7 downto 0);
        send_slot_data : out std_logic_vector(31 downto 0)
    );
end entity MovingAverageAsp;

architecture rtl of MovingAverageAsp is
    type sample_reg is array (0 to 2) of signed(15 downto 0);
    signal regs0 : sample_reg := (others => (others => '0')); 
    signal regs1 : sample_reg := (others => (others => '0')); 
begin
    process(clock)
        variable v_sum  : signed(17 downto 0);
        variable v_avg  : signed(17 downto 0);
        variable v_clip : signed(15 downto 0); 
    begin
        if rising_edge(clock) then
            -- Default assignments
            send_slot_addr <= (others => '0');
            send_slot_data <= (others => '0');

            -- Packet Filtering: Check header bits 31 down to 28
            if recv_slot_data(31 downto 28) = "1000" then
                
                -- Dual-Channel Demultiplexing
                if recv_slot_data(16) = '0' then
                    v_sum := resize(signed(recv_slot_data(15 downto 0)), 18) + 
                             resize(regs0(0), 18) + resize(regs0(1), 18) + resize(regs0(2), 18);
                    regs0 <= signed(recv_slot_data(15 downto 0)) & regs0(0 to 1);
                else
                    v_sum := resize(signed(recv_slot_data(15 downto 0)), 18) + 
                             resize(regs1(0), 18) + resize(regs1(1), 18) + resize(regs1(2), 18);
                    regs1 <= signed(recv_slot_data(15 downto 0)) & regs1(0 to 1);
                end if;

                -- Division by 4 via Shift Right 2 bits
                v_avg := shift_right(v_sum, 2);
                
                -- Saturation Clipping Bounds
                if v_avg > MAX_CLIP then 
                    v_clip := MAX_CLIP;
                elsif v_avg < MIN_CLIP then 
                    v_clip := MIN_CLIP;
                else 
                    v_clip := resize(v_avg, 16);
                end if;

                -- NoC Packet Forwarding
                send_slot_addr <= TARGET_PORT; 
                send_slot_data <= recv_slot_data(31 downto 16) & std_logic_vector(v_clip);
            end if;
        end if;
    end process;
end architecture rtl;