--
--	Baud rate generator
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BaudRateGeneratorLite is
		generic (
			CLOCK_FREQ: INTEGER := 50000000;
			BAUD_RATE:  INTEGER := 115200;
			BITS		 : INTEGER := 5		-- set to log2 (CLOCK_FREQ / (BAUD_RATE * 16))
		);
		port (
			TICK		: OUT STD_LOGIC;
			nRST		: IN	STD_LOGIC;
			CLK		: IN  STD_LOGIC		
		);		
end BaudRateGeneratorLite;	

architecture RTL of BaudRateGeneratorLite
is

	signal count : 		UNSIGNED (BITS - 1 DOWNTO 0);
	signal count_next : 	UNSIGNED (BITS - 1 DOWNTO 0);
	
	signal baud_tick : STD_LOGIC := '0';
	
begin

	process (CLK, nRST)
	begin
	
		if nRST = '0' then
				count <= (others => '0');
		elsif CLK'event and CLK = '1' then
				count 	  <= count_next;		
		end if;
	
	end process;

	process (count)
	begin
	
		if count = 
		to_unsigned(CLOCK_FREQ / BAUD_RATE / 16 - 1, BITS) then
			count_next <= (others => '0');
			baud_tick <= '1';
		else
			count_next <= count + 1;
			baud_tick <= '0';
		end if;
	
	end process;
	
	TICK <= baud_tick;
	

end RTL;

	