library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.opcodes.all;

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

    --------------------------------------------------------------------
    -- HELPER PROCEDURES
    --------------------------------------------------------------------
    procedure step is
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
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
    -- OPTIONAL WATCHDOG
    --------------------------------------------------------------------
    watchdog : process
    begin
        wait for 5 us;
        assert false report "Timeout: simulation did not finish" severity failure;
    end process;

    --------------------------------------------------------------------
    -- MAIN STIMULUS / CHECKS
    --------------------------------------------------------------------
    stim : process
    begin
        report "Starting robust integrated recop_top testbench";

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
        -- PROGRAM BEING TESTED (from simulation prog_mem)
        --
        -- 0  : LDR R1,#5
        -- 1  : 0005
        -- 2  : ADD R2,R1,#3
        -- 3  : 0003
        -- 4  : AND R3,R2,#1
        -- 5  : 0001
        -- 6  : OR  R4,R3,#8
        -- 7  : 0008
        -- 8  : LDR R6,#12
        -- 9  : 000C
        -- 10 : JMP R6
        -- 11 : NOOP   (should be skipped)
        -- 12 : JMP #12
        -- 13 : 000C
        ----------------------------------------------------------------

        ----------------------------------------------------------------
        -- C1 FETCH @0 : LDR R1,#5 word
        ----------------------------------------------------------------
        banner("C1 FETCH LDR R1,#5");
        step;
        check16(dbg_pc, x"0000", "C1 PC");
        check16(dbg_ir(31 downto 16), am_immediate & ldr & x"1" & x"0",
                "C1 IR upper word");

        ----------------------------------------------------------------
        -- C2 DECODE @1 : operand 0005
        ----------------------------------------------------------------
        banner("C2 DECODE LDR operand");
        step;
        check16(dbg_pc, x"0000", "C2 PC");
        check16(dbg_ir(15 downto 0), x"0005", "C2 IR lower word");

        ----------------------------------------------------------------
        -- C3 EXEC : R1 = 5, PC = 2
        ----------------------------------------------------------------
        banner("C3 EXEC LDR");
        step;
        check16(dbg_pc, x"0002", "C3 PC after LDR");
        check16(dbg_rz, x"0005", "C3 R1 writeback");

        ----------------------------------------------------------------
        -- C4 FETCH @2 : ADD R2,R1,#3
        ----------------------------------------------------------------
        banner("C4 FETCH ADD R2,R1,#3");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & addr & x"2" & x"1",
                "C4 IR upper word");

        ----------------------------------------------------------------
        -- C5 DECODE @3 : operand 0003
        ----------------------------------------------------------------
        banner("C5 DECODE ADD operand");
        step;
        check16(dbg_ir(15 downto 0), x"0003", "C5 IR lower word");

        ----------------------------------------------------------------
        -- C6 EXEC : R2 = 8, PC = 4
        ----------------------------------------------------------------
        banner("C6 EXEC ADD");
        step;
        check16(dbg_pc, x"0004", "C6 PC after ADD");
        check16(dbg_rx, x"0005", "C6 Rx should be R1=5");
        check16(dbg_rz, x"0008", "C6 R2 writeback should be 8");

        ----------------------------------------------------------------
        -- C7 FETCH @4 : AND R3,R2,#1
        ----------------------------------------------------------------
        banner("C7 FETCH AND R3,R2,#1");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & andr & x"3" & x"2",
                "C7 IR upper word");

        ----------------------------------------------------------------
        -- C8 DECODE @5 : operand 0001
        ----------------------------------------------------------------
        banner("C8 DECODE AND operand");
        step;
        check16(dbg_ir(15 downto 0), x"0001", "C8 IR lower word");

        ----------------------------------------------------------------
        -- C9 EXEC : R3 = 0, PC = 6
        ----------------------------------------------------------------
        banner("C9 EXEC AND");
        step;
        check16(dbg_pc, x"0006", "C9 PC after AND");
        check16(dbg_rx, x"0008", "C9 Rx should be R2=8");
        check16(dbg_rz, x"0000", "C9 R3 writeback should be 0");

        ----------------------------------------------------------------
        -- C10 FETCH @6 : OR R4,R3,#8
        ----------------------------------------------------------------
        banner("C10 FETCH OR R4,R3,#8");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & orr & x"4" & x"3",
                "C10 IR upper word");

        ----------------------------------------------------------------
        -- C11 DECODE @7 : operand 0008
        ----------------------------------------------------------------
        banner("C11 DECODE OR operand");
        step;
        check16(dbg_ir(15 downto 0), x"0008", "C11 IR lower word");

        ----------------------------------------------------------------
        -- C12 EXEC : R4 = 8, PC = 8
        ----------------------------------------------------------------
        banner("C12 EXEC OR");
        step;
        check16(dbg_pc, x"0008", "C12 PC after OR");
        check16(dbg_rx, x"0000", "C12 Rx should be R3=0");
        check16(dbg_rz, x"0008", "C12 R4 writeback should be 8");

        ----------------------------------------------------------------
        -- C13 FETCH @8 : LDR R6,#12
        ----------------------------------------------------------------
        banner("C13 FETCH LDR R6,#12");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & ldr & x"6" & x"0",
                "C13 IR upper word");

        ----------------------------------------------------------------
        -- C14 DECODE @9 : operand 000C
        ----------------------------------------------------------------
        banner("C14 DECODE LDR operand");
        step;
        check16(dbg_ir(15 downto 0), x"000C", "C14 IR lower word");

        ----------------------------------------------------------------
        -- C15 EXEC : R6 = 12, PC = 10
        ----------------------------------------------------------------
        banner("C15 EXEC LDR R6,#12");
        step;
        check16(dbg_pc, x"000A", "C15 PC after LDR R6");
        check16(dbg_rz, x"000C", "C15 R6 writeback should be 12");

        ----------------------------------------------------------------
        -- C16 FETCH @10 : JMP R6
        ----------------------------------------------------------------
        banner("C16 FETCH JMP R6");
        step;
        check16(dbg_ir(31 downto 16), am_register & jmp & x"0" & x"6",
                "C16 IR upper word");

        ----------------------------------------------------------------
        -- C17 DECODE JMP R6
        ----------------------------------------------------------------
        banner("C17 DECODE JMP R6");
        step;
        check16(dbg_pc, x"000A", "C17 PC should remain 10");

        ----------------------------------------------------------------
        -- C18 EXEC : PC := R6 = 12
        ----------------------------------------------------------------
        banner("C18 EXEC JMP R6");
        step;
        check16(dbg_pc, x"000C", "C18 PC should jump to 12");
        check16(dbg_rx, x"000C", "C18 Rx should be R6=12");

        ----------------------------------------------------------------
        -- C19 FETCH @12 : JMP #12
        -- If this happens, address 11 NOOP was correctly skipped.
        ----------------------------------------------------------------
        banner("C19 FETCH JMP #12");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & jmp & x"0" & x"0",
                "C19 IR upper word");

        ----------------------------------------------------------------
        -- C20 DECODE @13 : operand 000C
        ----------------------------------------------------------------
        banner("C20 DECODE JMP #12 operand");
        step;
        check16(dbg_ir(15 downto 0), x"000C", "C20 IR lower word");

        ----------------------------------------------------------------
        -- C21 EXEC : PC := 12
        ----------------------------------------------------------------
        banner("C21 EXEC JMP #12");
        step;
        check16(dbg_pc, x"000C", "C21 self-loop PC should remain 12");

        ----------------------------------------------------------------
        -- Stability check: loop repeats cleanly
        ----------------------------------------------------------------
        banner("LOOP STABILITY");
        step;
        check16(dbg_ir(31 downto 16), am_immediate & jmp & x"0" & x"0",
                "Loop fetch should still see JMP #12");

        step;
        check16(dbg_ir(15 downto 0), x"000C",
                "Loop decode should still see operand 000C");

        step;
        check16(dbg_pc, x"000C",
                "Loop exec should still leave PC at 12");

        report "ROBUST integrated recop_top testbench PASSED";
        wait;
    end process;

end architecture;