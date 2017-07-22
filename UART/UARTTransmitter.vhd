--
--	UART transmitter core
--
--		See Chu, "FPGA Prototyping by VHDL Examples"
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTTransmitter is
		port	(
			CLK	:	IN	STD_LOGIC;
			nRST	:	IN STD_LOGIC;
			
			nTxStart	: IN STD_LOGIC;
			nTxDone	: OUT STD_LOGIC;
			
			txData	: IN STD_LOGIC_VECTOR (7 downto 0);
			
			stopBits 	: IN STD_LOGIC_VECTOR (1 downto 0);
			parityBits 	: IN STD_LOGIC_VECTOR (1 downto 0);
			
			baudTick		: IN STD_LOGIC;
			
			TXD			: OUT STD_LOGIC
		);
end UARTTransmitter;

architecture RTL of UARTTransmitter
is

	type state_type is (idle, latchByteAndParity, startBit, txBits, txParity, txStopBits, waitForIdle );	
	signal state : state_type := idle;
	signal state_next : state_type;
	
	signal tx_byte 			: STD_LOGIC_VECTOR (7 downto 0);
	signal tx_byte_next 		: STD_LOGIC_VECTOR (7 downto 0);
	
	signal count				: UNSIGNED (3 downto 0); -- 2**4 = 16 counts per bit
	signal count_next			: UNSIGNED (3 downto 0);

	signal data_bit			: UNSIGNED (2 downto 0);
	signal data_bit_next		: UNSIGNED (2 downto 0);
	
	signal stop_bit_count	: UNSIGNED (4 downto 0);
	signal stop_bit_count_next	: UNSIGNED (4 downto 0);
	
	signal even_parity_bit 	 	 : STD_LOGIC;
	signal odd_parity_bit 		 : STD_LOGIC;
	signal even_parity_bit_next : STD_LOGIC;
	signal odd_parity_bit_next  : STD_LOGIC;
	
	signal n_tx_done_bit			 : STD_LOGIC;
	
	signal tx_bit					 : STD_LOGIC;
	signal tx_bit_next			 : STD_LOGIC;
	
begin

	process (CLK, nRST)
	begin
	
		if (nRST = '0') then
		
			tx_byte <= (others => '0');
			even_parity_bit 	<= '0';
			odd_parity_bit 	<= '0';
			tx_bit 				<= '1';
			count 				<= to_unsigned(0, 4);
			data_bit				<= to_unsigned(0, 3);
			stop_bit_count		<= to_unsigned(0,	5);
		
		elsif CLK'event and CLK = '1' then
		
			tx_byte <= tx_byte_next;
			even_parity_bit <= even_parity_bit_next;
			odd_parity_bit  <= odd_parity_bit_next;
			tx_bit 			 <= tx_bit_next;
			state				 <= state_next;
			count				 <= count_next;
			data_bit			 <= data_bit_next;
			stop_bit_count	 <= stop_bit_count_next;
		end if;
	
	end process;
	
	process (tx_byte, even_parity_bit, odd_parity_bit, 
				tx_bit, state, txData, nTxStart, count, data_bit, baudTick, 
				parityBits, stopBits, stop_bit_count)
		variable parity : STD_LOGIC;
		variable terminalStopBitCount : UNSIGNED (4 DOWNTO 0);
	begin
	
		tx_byte_next			<= tx_byte;
		even_parity_bit_next <= even_parity_bit;
		odd_parity_bit_next  <= odd_parity_bit;
		tx_bit_next				<= tx_bit;
		state_next				<= state;
		count_next				<= count;
		data_bit_next			<= data_bit;
		stop_bit_count_next  <= stop_bit_count;
		n_tx_done_bit			<= '1';
	
		case state is
			when idle =>
			
				tx_bit_next <= '1';
				
				if nTxStart = '0' then	-- we wait a cycle after the tick (read from fifo) to account for delay
					state_next <= latchByteAndParity;
				end if;
				
			when latchByteAndParity =>
			
				tx_byte_next <= txData;
				
				parity := '0';
				for i in txData'range loop
					parity := parity xor txData(i);
				end loop;
				
				even_parity_bit_next <= parity; 
				odd_parity_bit_next  <= not parity;
			
				state_next <= startBit;
				
				count_next <= to_unsigned(0, 4);
			
			when startBit => 
			
				tx_bit_next <= '0';
				
				if (baudTick = '1') then
					count_next  <= count + 1;
				
					if (count = "1111") then
						count_next <=  to_unsigned(0, 4);
						state_next <= txBits;
						data_bit_next <= to_unsigned(0, 3);
					end if;
				end if;
				
			when txBits =>
			
				tx_bit_next <= tx_byte(0);
			
				if (baudTick = '1') then
				
					count_next  <= count + 1;
			
					if (count = "1111") then
						data_bit_next <= data_bit + 1;
						tx_byte_next <= '0' & tx_byte(7 downto 1);
						
						if (data_bit = "111") then
							case parityBits is
								when "00" =>
									state_next <= txStopBits;
								when "11" => 
									state_next <= txStopBits;
								when others =>
									state_next <= txParity;
							end case;
						end if;
						
						count_next <= to_unsigned(0, 4);
						
					end if;
				end if;
					
			when txParity =>
	
				case parityBits is
					when "01" =>		-- even parity
						tx_bit_next <= even_parity_bit;
					when "10" =>		-- odd parity	
						tx_bit_next <= odd_parity_bit;
					when others =>
						null;
				end case;
	
				if (baudTick = '1') then
				
					count_next <= count + 1;
					
					if (count = "1111") then
						state_next <= txStopBits;
					end if;
				end if;
	
			when txStopBits => 

				tx_bit_next <= '1';
				
				case stopBits is 
					when "01" =>
						terminalStopBitCount := to_unsigned(23,5); -- 1.5 stop bits
					when "10" =>
						terminalStopBitCount := to_unsigned(31,5); -- 2 stop bits
					when others =>
						terminalStopBitCount := to_unsigned(15,5); -- 1 stop bit
				end case;
				
				if (baudTick = '1') then
					stop_bit_count_next <= stop_bit_count + 1;
					
					if (stop_bit_count = terminalStopBitCount) then
						state_next <= waitForIdle;
						n_tx_done_bit <= '0';
						count_next <= (others => '0');
					end if;
					
				end if;
			
			when others =>
			
				state_next <= idle;
		
		end case;	
	
	end process;
	
	nTxDone <= n_tx_done_bit;
	TXD	  <= tx_bit;

end RTL;
