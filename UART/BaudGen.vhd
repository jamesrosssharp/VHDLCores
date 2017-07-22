--
--	Baud rate generator
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BaudRateGenerator is
		generic (
			CLOCK_FREQ: INTEGER := 50000000;
			BITS		 : INTEGER := 15;		-- set to log2 (CLOCK_FREQ / (300 * 16))
			FRAC_BITS : INTEGER := 4		-- set to as much extra precision as is sensibly necessary
		);
		port (
			BAUDSEL	: IN  STD_LOGIC_VECTOR (3 DOWNTO 0);
			TICK		: OUT STD_LOGIC;
			nRST		: IN	STD_LOGIC;
			CLK		: IN  STD_LOGIC		
		);		
end BaudRateGenerator;	

architecture RTL of BaudRateGenerator
is

	signal count : 		UNSIGNED (BITS + FRAC_BITS - 1 DOWNTO 0);
	signal count_next : 	UNSIGNED (BITS + FRAC_BITS - 1 DOWNTO 0);
	
	signal terminal_count 	   : UNSIGNED (BITS + FRAC_BITS - 1 DOWNTO 0);
	signal terminal_count_next : UNSIGNED (BITS + FRAC_BITS - 1 DOWNTO 0);
	
	signal baud_tick : STD_LOGIC := '0';
	
begin

	process (CLK, nRST)
	begin
	
		if nRST = '0' then
		
				count <= (others => '0');
				terminal_count <= (others => '0');
		
		elsif CLK'event and CLK = '1' then
		
				terminal_count <= terminal_count_next;
				count 	  <= count_next;
				
		end if;
	
	end process;

	process (count, terminal_count)
	begin
	
		if count < terminal_count then
			count_next <= count + to_unsigned(2 ** FRAC_BITS, FRAC_BITS + BITS);
			baud_tick <= '0';
		else
			count_next <= count - terminal_count;
			baud_tick <= '1';
		end if;
	
	end process;
	
	TICK <= baud_tick;
	

	-- these calculations involve 16x oversampling; see Chu, "FPGA Prototyping by VHDL examples"
	
	terminal_count_next <= to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 300 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0000" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 600 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0001" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 1200 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0010" else 
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 2400 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0011" else 
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 4800 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0100" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 9600 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0101" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 19200 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0110" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 38400 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "0111" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 57600 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "1000" else
								  to_unsigned(CLOCK_FREQ * (2 ** FRAC_BITS) / 115200 / 16 - (2 ** FRAC_BITS), FRAC_BITS + BITS) when baudSEL = "1001"
									else (others => '0');
	
	

end RTL;

	