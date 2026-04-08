library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.opcodes.all;

entity tb_recop_top is
end entity;

architecture sim of tb_recop_top is

    signal clk     : bit_1 := '0';
    signal reset   : bit_1 := '1';

    signal dbg_pc  : bit_16;
    signal dbg_ir  : bit_32;
    signal dbg_rx  : bit_16;
    signal dbg_rz  : bit_16;
    signal dbg_alu : bit_16;

    constant CLK_PERIOD : time := 10 ns;

    -- Same instructions as the built-in ROM in datapath.vhd
    constant INST0 : bit_32 := am_immediate & ldr  & X"1" & X"0" & X"0005"; -- LDR R1, #5
    constant INST1 : bit_32 := am_immediate & addr & X"2" & X"1" & X"0003"; -- ADD R2, R1, #3
    constant INST2 : bit_32 := am_inherent  & noop & X"0" & X"0" & X"0000"; -- NOOP
    constant INST3 : bit_32 := am_immediate & jmp  & X"0" & X"0" & X"0003"; -- JMP #3

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
            dbg_alu => dbg_alu
        );

    --------------------------------------------------------------------
    -- Clock generation
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
    -- Stimulus + checks
    --------------------------------------------------------------------
    stim_proc : process
    begin
        report "Starting ReCOP testbench";

        -- Hold reset high for a couple of cycles
        reset <= '1';
        wait for 25 ns;
        reset <= '0';
        report "Reset released";

        ----------------------------------------------------------------
        -- 1st rising edge after reset release:
        -- control state moves ST_RESET -> ST_FETCH
        -- datapath still idle this edge
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_pc = X"0000"
            report "After first edge, PC should still be 0"
            severity error;

        ----------------------------------------------------------------
        -- 2nd rising edge:
        -- fetch instruction 0 into IR
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_ir = INST0
            report "Instruction 0 fetch failed: expected LDR R1, #5"
            severity error;

        assert dbg_pc = X"0000"
            report "PC should still be 0 during fetch of instruction 0"
            severity error;

        ----------------------------------------------------------------
        -- 3rd rising edge:
        -- execute LDR R1, #5
        -- PC should increment to 1
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_pc = X"0001"
            report "After executing LDR, PC should be 1"
            severity error;

        ----------------------------------------------------------------
        -- 4th rising edge:
        -- fetch instruction 1 into IR
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_ir = INST1
            report "Instruction 1 fetch failed: expected ADD R2, R1, #3"
            severity error;

        assert dbg_rx = X"0005"
            report "During ADD fetch/execute window, Rx should show R1 = 5"
            severity error;

        ----------------------------------------------------------------
        -- 5th rising edge:
        -- execute ADD R2, R1, #3
        -- ALU result should be 8
        -- PC should increment to 2
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_pc = X"0002"
            report "After executing ADD, PC should be 2"
            severity error;

        assert dbg_alu = X"0008"
            report "ADD failed: ALU result should be 8"
            severity error;

        ----------------------------------------------------------------
        -- 6th rising edge:
        -- fetch NOOP
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_ir = INST2
            report "Instruction 2 fetch failed: expected NOOP"
            severity error;

        ----------------------------------------------------------------
        -- 7th rising edge:
        -- execute NOOP, PC should increment to 3
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_pc = X"0003"
            report "After NOOP, PC should be 3"
            severity error;

        ----------------------------------------------------------------
        -- 8th rising edge:
        -- fetch JMP #3
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_ir = INST3
            report "Instruction 3 fetch failed: expected JMP #3"
            severity error;

        ----------------------------------------------------------------
        -- 9th rising edge:
        -- execute JMP #3, PC should stay/load 3
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_pc = X"0003"
            report "After JMP #3, PC should be 3"
            severity error;

        ----------------------------------------------------------------
        -- 10th rising edge:
        -- fetch JMP #3 again because it loops
        ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dbg_ir = INST3
            report "Loop failed: should fetch JMP #3 again"
            severity error;

        assert dbg_pc = X"0003"
            report "Loop failed: PC should remain 3"
            severity error;

        report "All testbench checks passed" severity note;
        wait;
    end process;

end architecture;