library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.various_constants.all;

entity alu_tb is
end alu_tb;

architecture sim of alu_tb is

	-- DUT signals
	signal clk           : bit_1 := '0';
	signal reset         : bit_1 := '0';
	signal z_flag        : bit_1;
	signal alu_operation : bit_3;
	signal alu_op1_sel   : bit_2;
	signal alu_op2_sel   : bit_1;
	signal alu_carry     : bit_1 := '0';
	signal alu_result    : bit_16;
	signal rx            : bit_16;
	signal rz            : bit_16;
	signal ir_operand    : bit_16;
	signal clr_z_flag    : bit_1 := '0';

begin

	-- =========================
	-- Instantiate ALU
	-- =========================
	DUT: entity work.alu
	port map (
		clk           => clk,
		reset         => reset,
		z_flag        => z_flag,
		alu_operation => alu_operation,
		alu_op1_sel   => alu_op1_sel,
		alu_op2_sel   => alu_op2_sel,
		alu_carry     => alu_carry,
		alu_result    => alu_result,
		rx            => rx,
		rz            => rz,
		ir_operand    => ir_operand,
		clr_z_flag    => clr_z_flag
	);

	-- =========================
	-- Clock generation
	-- =========================
	clk_process : process
	begin
		while true loop
			clk <= '0';
			wait for 10 ns;
			clk <= '1';
			wait for 10 ns;
		end loop;
	end process;

	-- =========================
	-- Stimulus
	-- =========================
	stim_proc: process
	begin

		-- Reset
		reset <= '1';
		wait for 20 ns;
		reset <= '0';

		--------------------------------
		-- TEST 1: ADD 5 + 3 = 8
		--------------------------------
		rx <= X"0005";
		rz <= X"0003";

		alu_op1_sel <= "00"; -- operand1 = rx
		alu_op2_sel <= '1';  -- operand2 = rz
		alu_operation <= alu_add;

		wait for 20 ns;

		--------------------------------
		-- TEST 2: SUB 5 - 3 = 2
		--------------------------------
		rx <= X"0003";
		rz <= X"0005";

		alu_op1_sel <= "00";
		alu_op2_sel <= '1';
		alu_operation <= alu_sub;

		wait for 20 ns;

		--------------------------------
		-- TEST 3: AND
		--------------------------------
		rx <= X"00FF";
		rz <= X"0F0F";

		alu_operation <= alu_and;

		wait for 20 ns;

		--------------------------------
		-- TEST 4: OR
		--------------------------------
		rx <= X"00FF";
		rz <= X"0F0F";

		alu_operation <= alu_or;

		wait for 20 ns;

		--------------------------------
		-- TEST 5: MAX
		--------------------------------
		rx <= X"0009";
		rz <= X"0003";

		alu_operation <= alu_max;

		wait for 20 ns;

		--------------------------------
		-- TEST 6: ZERO FLAG
		--------------------------------
		rx <= X"0002";
		rz <= X"0002";

		alu_operation <= alu_sub; -- result = 0

		wait for 40 ns;

		--------------------------------
		-- END
		--------------------------------
		wait;

	end process;

end sim;