--Moving Average Filter ASP
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;

entity MovingAverageAsp is
    generic (
        -- Target NoC port/slot to forward the processed data to
        TARGET_PORT : std_logic_vector(7 downto 0) := x"02";
        -- Saturation/Clipping thresholds for the output audio amplitude
        MAX_CLIP    : signed(15 downto 0) := to_signed(4096, 16);
        MIN_CLIP    : signed(15 downto 0) := to_signed(-4096, 16)
    );
    port (
        clock : in  std_logic;
        send  : out tdma_min_port;
        recv  : in  tdma_min_port
    );
end entity MovingAverageAsp;

architecture rtl of MovingAverageAsp is
    -- Shift register arrays to hold past samples (3 slots per channel)
    -- Combined with the live incoming sample, this yields a 4-sample window (N=4)
    type sample_reg is array (0 to 2) of signed(15 downto 0);
    signal regs0 : sample_reg := (others => (others => '0')); -- Channel 0 Buffer
    signal regs1 : sample_reg := (others => (others => '0')); -- Channel 1 Buffer

begin

    process(clock)
        -- 18-bit variables to safely sum four 16-bit numbers without overflow bit-wrap
        variable v_sum  : signed(17 downto 0);
        variable v_avg  : signed(17 downto 0);
        variable v_clip : signed(15 downto 0); 
    begin
        if rising_edge(clock) then
            -- Default assignment: clear output buses when no active transmit is triggered
            send.addr <= (others => '0');
            send.data <= (others => '0');

            -- Packet Filtering: Check if the incoming packet header is valid ("1000")
            if recv.data(31 downto 28) = "1000" then
                
                ----------------------------------------------------------------
                -- 1. Dual-Channel Demultiplexing & Moving Average Calculation
                ----------------------------------------------------------------
                if recv.data(16) = '0' then
                    -- CHANNEL 0 LOGIC
                    -- Sum the incoming data sample and the 3 saved historical samples
                    v_sum := resize(signed(recv.data(15 downto 0)), 18) + 
                             resize(regs0(0), 18) + resize(regs0(1), 18) + resize(regs0(2), 18);
                    
                    -- Shift Register Update: Prepend new sample, shift old ones down, drop the oldest
                    regs0 <= signed(recv.data(15 downto 0)) & regs0(0 to 1);
                else
                    -- CHANNEL 1 LOGIC
                    v_sum := resize(signed(recv.data(15 downto 0)), 18) + 
                             resize(regs1(0), 18) + resize(regs1(1), 18) + resize(regs1(2), 18);
                    
                    regs1 <= signed(recv.data(15 downto 0)) & regs1(0 to 1);
                end if;

                ----------------------------------------------------------------
                -- 2. Division via Scaling Shift
                ----------------------------------------------------------------
                -- To compute a true average of 4 samples, we must divide by 4.
                -- Moving right by 2 bits divides an integer by 2^2 = 4.
                v_avg := shift_right(v_sum, 2);
                
                ----------------------------------------------------------------
                -- 3. Saturation / Amplitude Clipping Circuit
                ----------------------------------------------------------------
                if v_avg > MAX_CLIP then 
                    v_clip := MAX_CLIP;
                elsif v_avg < MIN_CLIP then 
                    v_clip := MIN_CLIP;
                else 
                    v_clip := resize(v_avg, 16);
                end if;

                ----------------------------------------------------------------
                -- 4. NoC Packet Assembler & Forwarding
                ----------------------------------------------------------------
                -- Address the packet to your designated downstream target block
                send.addr <= TARGET_PORT; 
                
                -- Construct data payload: Preserve original metadata upper bits (31 down to 16)
                -- and append the newly filtered 16-bit payload to the bottom half.
                send.data <= recv.data(31 downto 16) & std_logic_vector(v_clip);
                
            end if;
        end if;
    end process;

end architecture rtl;