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
        corr_out     : out std_logic_vector(35 downto 0)
    );
end entity;


architecture rtl of symmetry_core is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant SAMPLE_W    : integer := 12;
    constant ADDR_W      : integer := 6;
    constant RAM_DEPTH   : integer := 64;
    constant ACC_W       : integer := 36;

    constant WINDOW_SIZE : integer := 32;
    constant NUM_PAIRS   : integer := WINDOW_SIZE / 2;

    --------------------------------------------------------------------
    -- Sample RAM
    --------------------------------------------------------------------
    type ram_t is array (0 to RAM_DEPTH-1) of std_logic_vector(SAMPLE_W-1 downto 0);
    signal sample_ram : ram_t := (others => (others => '0'));

    --------------------------------------------------------------------
    -- Circular buffer
    --------------------------------------------------------------------
    signal write_ptr    : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal sample_count : integer range 0 to RAM_DEPTH := 0;

    --------------------------------------------------------------------
    -- Correlation address/control
    --------------------------------------------------------------------
    signal origin     : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal pair_count : unsigned(ADDR_W-1 downto 0) := (others => '0');

    signal right_addr : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal left_addr  : unsigned(ADDR_W-1 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Datapath
    --------------------------------------------------------------------
    signal op_a    : unsigned(17 downto 0) := (others => '0');
    signal op_b    : unsigned(17 downto 0) := (others => '0');

    signal product : unsigned(35 downto 0) := (others => '0');
    signal acc     : unsigned(ACC_W-1 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- FSM
    --------------------------------------------------------------------
    type state_t is (
        IDLE,
        ISSUE_ADDR,
        LATCH_OPERANDS,
        MULT_0,
        MULT_1,
        ACCUMULATE,
        DONE_STATE
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

                ----------------------------------------------------------------
                -- Default: corr_done is a one-clock pulse
                ----------------------------------------------------------------
                corr_done <= '0';

                ----------------------------------------------------------------
                -- Work out what the write pointer/sample count would be
                -- after this clock, if a new sample arrives.
                ----------------------------------------------------------------
                next_write_ptr    := write_ptr;
                next_sample_count := sample_count;

                ----------------------------------------------------------------
                -- Write incoming sample into circular buffer
                ----------------------------------------------------------------
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

                ----------------------------------------------------------------
                -- Correlation FSM
                ----------------------------------------------------------------
                case state is

                    ------------------------------------------------------------
                    -- Wait until a new sample arrives and at least 32 samples
                    -- are available in the circular buffer.
                    ------------------------------------------------------------
                    when IDLE =>

                        if sample_valid = '1' and next_sample_count >= WINDOW_SIZE then

                            -- next_write_ptr points to next write location.
                            -- newest sample is next_write_ptr - 1.
                            -- origin is start of right half of latest 32 samples.
                            origin <= next_write_ptr - to_unsigned(NUM_PAIRS, ADDR_W);

                            pair_count <= (others => '0');
                            acc        <= (others => '0');

                            state <= ISSUE_ADDR;
                        end if;


                    ------------------------------------------------------------
                    -- Generate mirrored pair addresses:
                    -- right = f(x+i)
                    -- left  = f(x-i-1)
                    ------------------------------------------------------------
                    when ISSUE_ADDR =>

                        right_addr <= origin + pair_count;
                        left_addr  <= origin - pair_count - 1;

                        state <= LATCH_OPERANDS;


                    ------------------------------------------------------------
                    -- Read RAM values and zero-extend to 18-bit multiplier input.
                    ------------------------------------------------------------
                    when LATCH_OPERANDS =>

                        op_a <= resize(unsigned(sample_ram(to_integer(right_addr))), 18);
                        op_b <= resize(unsigned(sample_ram(to_integer(left_addr))), 18);

                        state <= MULT_0;


                    ------------------------------------------------------------
                    -- Multiply current pair.
                    ------------------------------------------------------------
                    when MULT_0 =>

                        product <= op_a * op_b;

                        state <= MULT_1;


                    ------------------------------------------------------------
                    -- Extra wait state for conservative registered multiplier timing.
                    ------------------------------------------------------------
                    when MULT_1 =>

                        state <= ACCUMULATE;


                    ------------------------------------------------------------
                    -- Accumulate product.
                    ------------------------------------------------------------
                    when ACCUMULATE =>

                        acc_next := acc + resize(product, ACC_W);
                        acc <= acc_next;

                        if pair_count = to_unsigned(NUM_PAIRS - 1, ADDR_W) then
                            corr_out <= std_logic_vector(acc_next);
                            state <= DONE_STATE;
                        else
                            pair_count <= pair_count + 1;
                            state <= ISSUE_ADDR;
                        end if;


                    ------------------------------------------------------------
                    -- Pulse done for one clock.
                    ------------------------------------------------------------
                    when DONE_STATE =>

                        corr_done <= '1';
                        state <= IDLE;


                    when others =>

                        state <= IDLE;

                end case;

            end if;
        end if;
    end process;

end architecture;