library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity symmetry_core is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        sample_valid : in  std_logic;
        sample_in    : in  std_logic_vector(11 downto 0);

        corr_done    : out std_logic;
        corr_out     : out std_logic_vector(31 downto 0)
    );
end entity;


architecture rtl of symmetry_core is

    -- Sample/buffer sizes. ADDR_W = 6 gives 64 RAM addresses.
    constant SAMPLE_W    : integer := 12;
    constant ADDR_W      : integer := 6;
    constant RAM_DEPTH   : integer := 64;
    constant ACC_W       : integer := 32;

    -- Correlation is done over the newest 32 samples.
    -- The window is split into 16 mirrored pairs.
    constant WINDOW_SIZE : integer := 32;
    constant NUM_PAIRS   : integer := WINDOW_SIZE / 2;

    -- Small circular RAM for incoming ADC samples
    type ram_t is array (0 to RAM_DEPTH-1) of std_logic_vector(SAMPLE_W-1 downto 0);
    signal sample_ram : ram_t := (others => (others => '0'));

    -- write_ptr always points at the next write location
    signal write_ptr    : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal sample_count : integer range 0 to RAM_DEPTH := 0;

    -- origin is the first sample on the right half of the 32-sample window
    signal origin     : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal pair_count : unsigned(ADDR_W-1 downto 0) := (others => '0');

    signal right_addr : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal left_addr  : unsigned(ADDR_W-1 downto 0) := (others => '0');

    -- Multiplier inputs are widened a bit before multiplying.
    -- Product is 36 bits because the operands are 18 bits each.
    signal op_a    : unsigned(17 downto 0) := (others => '0');
    signal op_b    : unsigned(17 downto 0) := (others => '0');

    signal product : unsigned(35 downto 0) := (others => '0');
    signal acc     : unsigned(ACC_W-1 downto 0) := (others => '0');

    type state_t is (
        IDLE,
        ISSUE_ADDR,
        LATCH_OPERANDS,
        MULT_0,
        ACCUMULATE,
        DONE
    );

    signal state : state_t := IDLE;

begin

    process(clk)
        variable next_write_ptr    : unsigned(ADDR_W-1 downto 0);
        variable next_sample_count : integer range 0 to RAM_DEPTH;
        variable acc_next          : unsigned(ACC_W-1 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then

                write_ptr    <= (others => '0');
                sample_count <= 0;

                origin       <= (others => '0');
                pair_count   <= (others => '0');

                right_addr   <= (others => '0');
                left_addr    <= (others => '0');

                op_a         <= (others => '0');
                op_b         <= (others => '0');
                product      <= (others => '0');
                acc          <= (others => '0');

                corr_done    <= '0';
                corr_out     <= (others => '0');

                state        <= IDLE;

            else

                -- corr_done is only meant to pulse when the result is ready
                corr_done <= '0';

                -- These are used so the FSM can see the updated pointer/count
                -- in the same clock cycle that a new sample is written.
                next_write_ptr    := write_ptr;
                next_sample_count := sample_count;

                if sample_valid = '1' then

                    sample_ram(to_integer(write_ptr)) <= sample_in;

                    next_write_ptr := write_ptr + 1;

                    if sample_count < RAM_DEPTH then
                        next_sample_count := sample_count + 1;
                    else
                        next_sample_count := sample_count;
                    end if;

                    write_ptr    <= next_write_ptr;
                    sample_count <= next_sample_count;

                end if;

                case state is

                    when IDLE =>

                        -- Start once a new sample has arrived and there is a full window.
                        if sample_valid = '1' and next_sample_count >= WINDOW_SIZE then

                            -- After the write, next_write_ptr is the next empty slot.
                            -- Subtracting 16 gives the start of the right half.
                            origin <= next_write_ptr - to_unsigned(NUM_PAIRS, ADDR_W);

                            pair_count <= (others => '0');
                            acc        <= (others => '0');

                            state <= ISSUE_ADDR;
                        end if;


                    when ISSUE_ADDR =>

                        -- Pair 0 compares origin with origin-1.
                        -- Pair 1 compares origin+1 with origin-2, and so on.
                        right_addr <= origin + pair_count;
                        left_addr  <= origin - pair_count - 1;

                        state <= LATCH_OPERANDS;


                    when LATCH_OPERANDS =>

                        op_a <= resize(unsigned(sample_ram(to_integer(right_addr))), 18);
                        op_b <= resize(unsigned(sample_ram(to_integer(left_addr))), 18);

                        state <= MULT_0;


                    when MULT_0 =>

                        product <= op_a * op_b;

                        state <= ACCUMULATE;


                    when ACCUMULATE =>

                        acc_next := acc + resize(product, ACC_W);
                        acc <= acc_next;

                        if pair_count = to_unsigned(NUM_PAIRS - 1, ADDR_W) then
                            corr_out <= std_logic_vector(acc_next);
                            state <= DONE;
                        else
                            pair_count <= pair_count + 1;
                            state <= ISSUE_ADDR;
                        end if;


                    when DONE =>

                        corr_done <= '1';
                        state <= IDLE;


                    when others =>

                        state <= IDLE;

                end case;

            end if;
        end if;
    end process;

end architecture;