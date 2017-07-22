--
-- UART receiver
--
-- See Chu, "FPGA Prototyping by VHDL Examples"
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTReceiver is
	port	(
		CLK	:	IN	STD_LOGIC;
		nRST	:	IN STD_LOGIC;
		
		nRxDone	: OUT STD_LOGIC;
		
		rxData	: OUT STD_LOGIC_VECTOR (7 downto 0);
		
		stopBits 	: IN STD_LOGIC_VECTOR (1 downto 0);
		parityBits 	: IN STD_LOGIC_VECTOR (1 downto 0);
		
		baudTick		: IN STD_LOGIC;
		
		RXD			: IN STD_LOGIC
	);
end UARTReceiver;

architecture RTL of UARTReceiver is

	type state_type is (idle, startBit, rxBits, rxParity, rxStopBits, waitForIdle );	
	signal state : state_type := idle;
	signal state_next : state_type;
	
	signal rx_byte 				 : STD_LOGIC_VECTOR (7 downto 0);
	signal rx_byte_next 			 : STD_LOGIC_VECTOR (7 downto 0);

	signal rx_filter				 : STD_LOGIC_VECTOR (3 downto 0);	-- filter received input into rx_filter
	signal rx_filter_next		 : STD_LOGIC_VECTOR (3 downto 0);
	
	signal count				: UNSIGNED (3 downto 0); -- 2**4 = 16 counts per bit
	signal count_next			: UNSIGNED (3 downto 0);

	signal data_bit			: UNSIGNED (2 downto 0);
	signal data_bit_next		: UNSIGNED (2 downto 0);
	
	signal stop_bit_count	: UNSIGNED (4 downto 0);
	signal stop_bit_count_next	: UNSIGNED (4 downto 0);

begin

	process (CLK, nRST)
	begin
	
		if (nRST = '0') then
		
			rx_byte <= (others => '0');
			count 				<= (others => '0');
			data_bit				<= (others => '0');
			stop_bit_count		<= (others => '0');
			rx_filter			<= (others => '0');
			state					<= idle;
		
		elsif CLK'event and CLK = '1' then
		
			rx_byte <= rx_byte_next;
			state				 <= state_next;
			count				 <= count_next;
			data_bit			 <= data_bit_next;
			stop_bit_count	 <= stop_bit_count_next;
			rx_filter		 <= rx_filter_next;

		end if;
	
	end process;
	
	
	process (RXD, rx_byte, state, count, data_bit, stop_bit_count, 
				baudTick, rx_filter, stopBits, parityBits)
		variable filter : STD_LOGIC;
		variable parity : STD_LOGIC;
		variable terminalStopBitCount : UNSIGNED (4 DOWNTO 0);
	begin
	
		state_next <= state;
		rx_byte_next <= rx_byte;
		count_next <= count;
		data_bit_next <= data_bit;
		stop_bit_count_next <= stop_bit_count;
		rx_filter_next <= rx_filter;
		
		nRXDone <= '1';
	
		case state is
			when idle =>
				if (RXD = '0') then
					state_next <= startBit;
				end if;
			when startBit =>
				
				if (baudTick = '1') then 
					count_next <= count + 1;
					
					if (count > 7 and count < 13) then
						rx_filter_next <= rx_filter(2 downto 0) & RXD;
					end if;
					
					filter := '1';
					
					for i in rx_filter'range loop
						filter := filter and rx_filter(i);
					end loop;
					
					if (count = "1111" and filter = '0') then
						state_next <= rxBits;
					else 
						state_next <= idle;
					end if;
				end if;
					
			when rxBits => 
		
				if (baudTick = '1') then
					count_next <= count + 1;
					
					if (count > 7 and count < 13) then
						rx_filter_next <= rx_filter(2 downto 0) & RXD;
					end if;
					
					filter := '1';
					
					for i in rx_filter'range loop
						filter := filter and rx_filter(i);
					end loop;
					
					if (count = "1111") then
						data_bit_next <= data_bit + 1;
						rx_byte_next <=  filter & rx_byte(7 downto 1);
						
						if (data_bit = "111") then
							
							case parityBits is 
								when "00" =>
									state_next <= rxStopBits;
								when "11" =>
									state_next <= rxStopBits;
								when others =>
									state_next <= rxParity;
								end case;
						end if;
					end if;
				end if;
					
			when rxParity  =>
			
				if (baudTick = '1') then
					count_next <= count + 1;
					
					if (count > 7 and count < 13) then
						rx_filter_next <= rx_filter(2 downto 0) & RXD;
					end if;
					
					filter := '1';
					
					for i in rx_filter'range loop
						filter := filter and rx_filter(i);
					end loop;
					
					parity := '0';
					for i in rx_byte'range loop
						parity := parity xor rx_byte(i);
					end loop;
					
					if (count = "1111") then
						case parityBits is
								when "01" =>	-- even parity
									if ((filter xor parity) = '0') then
										state_next <= rxStopBits;
									else
										state_next <= idle;	-- drop the packet: parity was foobar
									end if;
								when "10" =>	-- odd parity
									if ((filter xor parity) = '1') then
										state_next <= rxStopBits;
									else
										state_next <= idle;	-- drop the packet: parity was foobar
									end if;
								when others =>
									state_next <= idle;
						end case;
					end if;
				end if;
					
			when rxStopBits =>
				if (baudTick = '1') then
					
					stop_bit_count_next <= stop_bit_count + 1;
				
					case stopBits is 
						when "01" =>
							terminalStopBitCount := to_unsigned(23,5); -- 1.5 stop bits
						when "10" =>
							terminalStopBitCount := to_unsigned(31,5); -- 2 stop bits
						when others =>
							terminalStopBitCount := to_unsigned(15,5); -- 1 stop bit
					end case;
			
					if (stop_bit_count = terminalStopBitCount) then
						state_next <= waitForIdle;
						nRxDone <= '0';
					end if;
					
				end if;
					
			when others =>
			
				state_next <= idle;
				
		end case;
						
	end process;
	
	rxData <= rx_byte;
	
end RTL;