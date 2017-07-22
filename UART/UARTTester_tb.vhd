--
--	Test bench for UART (instantiates UART tester, the synthesisable top level)
--

library IEEE;
use IEEE.std_logic_1164.all;

entity UARTTester_tb is
end UARTTester_tb;

architecture RTL of UARTTester_tb
is

	component UARTTester
		port (
		
			UART_TXD	:	OUT STD_LOGIC;
			UART_RXD : 	IN	 STD_LOGIC;	
			CLOCK_50		:	IN	STD_LOGIC;
			KEY		:	IN STD_LOGIC_VECTOR (3 DOWNTO 0)
			
		);
	end component;

	signal TX : STD_LOGIC;
	signal RX : STD_LOGIC	:= '1';
	signal CLK : STD_LOGIC	:= '0';
	signal KEY : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111";
	
	constant	clk_period : time := 0.020 us;
	constant bit_period : time := 8680.5 ns;
	
	signal tx_byte : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal parity_bit : STD_LOGIC;
	
begin

	uart0: component UARTTester port map (UART_TXD => TX, UART_RXD => RX, CLOCK_50 => CLK, KEY => KEY);

	process 
	begin
		CLK <= '0';
		wait for clk_period / 2;
		CLK <= '1';
		wait for clk_period / 2;
	end process;
	
	process
	begin
		wait for 10 ns;
		KEY(0) <= '0';
		wait for 40 ns;
		KEY(0) <= '1';
		wait for 10000 ms;
	end process;
	
	-- process TX data
	process
		variable tx_byte_var : STD_LOGIC_VECTOR (7 DOWNTO 0);
	begin
	
		wait until TX = '0';
		tx_byte_var := (others => '0');
		
		for i in tx_byte'reverse_range loop
			wait for bit_period;
			tx_byte_var(i) := TX;
		end loop;
		
		-- get parity bit
		
		wait for bit_period;
		parity_bit <= TX;
		
		-- stop bit
		
		wait for bit_period;
	
		tx_byte <= tx_byte_var;
	
	end process;
	
end RTL;