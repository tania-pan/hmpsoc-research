library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.opcodes.all;

entity prog_mem is
    port (
        address : in  std_logic_vector(14 downto 0);
        clock   : in  std_logic := '1';
        q       : out std_logic_vector(15 downto 0)
    );
end prog_mem;

architecture sim of prog_mem is
    type rom_t is array (0 to 63) of std_logic_vector(15 downto 0);

    constant rom : rom_t := (
        ----------------------------------------------------------------
        -- 0: LDR R1, #5
        ----------------------------------------------------------------
        0  => am_immediate & ldr  & x"1" & x"0",
        1  => x"0005",

        ----------------------------------------------------------------
        -- 2: ADD R2, R1, #3      => R2 = 8
        ----------------------------------------------------------------
        2  => am_immediate & addr & x"2" & x"1",
        3  => x"0003",

        ----------------------------------------------------------------
        -- 4: AND R3, R2, #1      => R3 = 8 AND 1 = 0
        ----------------------------------------------------------------
        4  => am_immediate & andr & x"3" & x"2",
        5  => x"0001",

        ----------------------------------------------------------------
        -- 6: OR R4, R3, #8       => R4 = 0 OR 8 = 8
        ----------------------------------------------------------------
        6  => am_immediate & orr  & x"4" & x"3",
        7  => x"0008",

        ----------------------------------------------------------------
        -- 8: LDR R6, #12         => jump target in register
        ----------------------------------------------------------------
        8  => am_immediate & ldr  & x"6" & x"0",
        9  => x"000C",

        ----------------------------------------------------------------
        -- 10: JMP R6             => should jump to address 12
        ----------------------------------------------------------------
        10 => am_register  & jmp  & x"0" & x"6",

        ----------------------------------------------------------------
        -- 11: NOOP               => should be skipped by JMP R6
        ----------------------------------------------------------------
        11 => am_inherent  & noop & x"0" & x"0",

        ----------------------------------------------------------------
        -- 12: JMP #12            => tight self-loop
        ----------------------------------------------------------------
        12 => am_immediate & jmp  & x"0" & x"0",
        13 => x"000C",

        others => x"0000"
    );

begin
    -- Combinational ROM for clean simulation fetch behaviour
    q <= rom(to_integer(unsigned(address)));
end architecture;