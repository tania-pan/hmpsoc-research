library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;

entity tb_recop_top is
end entity;

architecture sim of tb_recop_top is

    constant CLK_PERIOD : time := 10 ns;

    signal clk     : bit_1 := '0';
    signal reset   : bit_1 := '0';

    signal sip     : bit_16 := x"0000";
    signal sop     : bit_16;
    signal dpcr    : bit_32;

    signal dbg_pc  : bit_16;
    signal dbg_ir  : bit_32;
    signal dbg_rx  : bit_16;
    signal dbg_rz  : bit_16;
    signal dbg_alu : bit_16;

    signal done    : boolean := false;

    --------------------------------------------------------------------
    -- HELPERS
    --------------------------------------------------------------------
    procedure step is
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
    end procedure;

    procedure step_n(constant n : in natural) is
    begin
        for i in 1 to n loop
            step;
        end loop;
    end procedure;

    procedure check16(
        constant actual  : in bit_16;
        constant expect  : in bit_16;
        constant label_s : in string
    ) is
    begin
        assert actual = expect
            report label_s &
                   " | expected=" & integer'image(to_integer(unsigned(expect))) &
                   " got="      & integer'image(to_integer(unsigned(actual)))
            severity failure;
    end procedure;

    procedure check32(
        constant actual  : in bit_32;
        constant expect  : in bit_32;
        constant label_s : in string
    ) is
    begin
        assert actual = expect
            report label_s
            severity failure;
    end procedure;

    procedure banner(constant s : in string) is
    begin
        report "---------------- " & s & " ----------------";
    end procedure;

begin

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.recop_top
        port map (
            clk     => clk,
            reset   => reset,
            dbg_pc  => dbg_pc,
            dbg_ir  => dbg_ir,
            dbg_rx  => dbg_rx,
            dbg_rz  => dbg_rz,
            dbg_alu => dbg_alu,
            sip     => sip,
            sop     => sop,
            dpcr    => dpcr
        );

    --------------------------------------------------------------------
    -- CLOCK
    --------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- WATCHDOG
    --------------------------------------------------------------------
    watchdog : process
    begin
        wait for 20 us;
        if not done then
            assert false report "Timeout: simulation did not finish" severity failure;
        end if;
        wait;
    end process;

    --------------------------------------------------------------------
    -- STIMULUS / CHECKS
    --
    -- This TB assumes the program is:
    --
    -- LDR R1 #10
    -- LDR R2 #20
    -- ADD R3 R1 #20
    -- AND R4 R2 #7
    -- OR  R5 R4 #8
    -- CLFZ
    -- NOOP
    -- JMP END_LOOP
    --
    -- END_LOOP:
    -- NOOP
    -- JMP END_LOOP
    --
    -- With the synchronous PM-aware CU:
    --   first 2-word instruction after reset completes in 7 steps
    --   each later 2-word instruction completes in 6 more steps
    --   each 1-word instruction completes in 4 more steps
    --------------------------------------------------------------------
    stim : process
    begin
        report "Starting recop_top TB";

        ----------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------
        banner("RESET");
        reset <= '1';
        sip   <= x"1234";
        wait for 25 ns;
        reset <= '0';
        wait for 1 ns;

        check16(dbg_pc, x"0000", "After reset release, PC should be 0");
        check32(dbg_ir, x"00000000", "After reset release, IR should be 0");

        ----------------------------------------------------------------
        -- LDR R1,#10
        ----------------------------------------------------------------
        banner("LDR R1,#10");
        step_n(7);
        check16(dbg_pc, x"0002", "After LDR R1,#10, PC");
        check16(dbg_rz, x"000A", "After LDR R1,#10, R1");

        ----------------------------------------------------------------
        -- LDR R2,#20
        ----------------------------------------------------------------
        banner("LDR R2,#20");
        step_n(6);
        check16(dbg_pc, x"0004", "After LDR R2,#20, PC");
        check16(dbg_rz, x"0014", "After LDR R2,#20, R2");

        ----------------------------------------------------------------
        -- ADD R3,R1,#20  => 10 + 20 = 30
        ----------------------------------------------------------------
        banner("ADD R3,R1,#20");
        step_n(6);
        check16(dbg_pc, x"0006", "After ADD R3,R1,#20, PC");
        check16(dbg_rx, x"000A", "During/after ADD, Rx should be R1=10");
        check16(dbg_rz, x"001E", "After ADD R3,R1,#20, R3 should be 30");

        ----------------------------------------------------------------
        -- AND R4,R2,#7  => 20 AND 7 = 4
        ----------------------------------------------------------------
        banner("AND R4,R2,#7");
        step_n(6);
        check16(dbg_pc, x"0008", "After AND R4,R2,#7, PC");
        check16(dbg_rx, x"0014", "During/after AND, Rx should be R2=20");
        check16(dbg_rz, x"0004", "After AND R4,R2,#7, R4 should be 4");

        ----------------------------------------------------------------
        -- OR R5,R4,#8  => 4 OR 8 = 12
        ----------------------------------------------------------------
        banner("OR R5,R4,#8");
        step_n(6);
        check16(dbg_pc, x"000A", "After OR R5,R4,#8, PC");
        check16(dbg_rx, x"0004", "During/after OR, Rx should be R4=4");
        check16(dbg_rz, x"000C", "After OR R5,R4,#8, R5 should be 12");

        ----------------------------------------------------------------
        -- CLFZ
        ----------------------------------------------------------------
        banner("CLFZ");
        step_n(4);
        check16(dbg_pc, x"000B", "After CLFZ, PC");

        ----------------------------------------------------------------
        -- NOOP
        ----------------------------------------------------------------
        banner("NOOP");
        step_n(4);
        check16(dbg_pc, x"000C", "After NOOP, PC");

        ----------------------------------------------------------------
        -- JMP END_LOOP
        -- END_LOOP should be PM address 14 (0x000E)
        ----------------------------------------------------------------
        banner("JMP END_LOOP");
        step_n(6);
        check16(dbg_pc, x"000E", "After JMP END_LOOP, PC should be 14");

        ----------------------------------------------------------------
        -- END_LOOP: NOOP
        ----------------------------------------------------------------
        banner("END_LOOP NOOP");
        step_n(4);
        check16(dbg_pc, x"000F", "After END_LOOP NOOP, PC should be 15");

        ----------------------------------------------------------------
        -- END_LOOP: JMP END_LOOP
        ----------------------------------------------------------------
        banner("END_LOOP JMP");
        step_n(6);
        check16(dbg_pc, x"000E", "Loop JMP should return PC to 14");

        ----------------------------------------------------------------
        -- One more repetition to prove stable loop
        ----------------------------------------------------------------
        banner("LOOP STABILITY");
        step_n(4);
        check16(dbg_pc, x"000F", "Repeated loop NOOP should move PC to 15");

        done <= true;
        report "recop_top TB PASSED";
        wait;
    end process;

end architecture;