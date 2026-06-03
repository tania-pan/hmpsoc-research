-- Zoran Salcic

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE WORK.RECOP_TYPES.ALL;

PACKAGE various_constants IS

    -- ALU operation selection
    CONSTANT alu_add  : bit_3 := "000";
    CONSTANT alu_sub  : bit_3 := "001";
    CONSTANT alu_and  : bit_3 := "010";
    CONSTANT alu_or   : bit_3 := "011";
    CONSTANT alu_idle : bit_3 := "100";
    CONSTANT alu_max  : bit_3 := "101";

    -- Register file input select
    CONSTANT rf_from_operand : bit_3 := "000";
    CONSTANT rf_from_dprr    : bit_3 := "001";
    CONSTANT rf_from_alu     : bit_3 := "011";
    CONSTANT rf_from_max     : bit_3 := "100";
    CONSTANT rf_from_sip     : bit_3 := "101";
    CONSTANT rf_from_er      : bit_3 := "110";
    CONSTANT rf_from_dm      : bit_3 := "111";

END various_constants;