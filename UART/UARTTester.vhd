--
--	Synthesisable top level to test UART Core
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity UARTTester	is
	
	port (
	
		-- Connections to UART
	
		UART_TXD	:	OUT STD_LOGIC;
		UART_RXD : 	IN	 STD_LOGIC;
	
		-- CLK50
		
		CLOCK_50		:	IN	STD_LOGIC;
		
		-- use 1 key for asynchronous reset
		
		KEY		:	IN STD_LOGIC_VECTOR (3 DOWNTO 0)
		
	);

end UARTTester;

architecture RTL of UARTTester
is

	component UART is
		generic (
			TX_FIFO_DEPTH	: INTEGER;
			RX_FIFO_DEPTH  : INTEGER
		);
		port (
		
			TX:	OUT	STD_LOGIC;
			RX:	IN		STD_LOGIC;
			
			CLK:	IN		STD_LOGIC;
			
			nRST: IN		STD_LOGIC;
			
			-- Register interface (bus slave)
			
			WR_DATA:	IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			RD_DATA: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
			
			ADDR:		IN	STD_LOGIC_VECTOR (1 DOWNTO 0);	-- 4 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = CTRL, 3 = STATUS
			
			n_WR	:	IN STD_LOGIC;	-- active low, write to register 
			n_RD	:	IN STD_LOGIC  -- active low, read from register
		
		);
	end component;
		
	signal wr_reg 		 : STD_LOGIC := '1';
	signal wr_reg_next : STD_LOGIC := '1';
	
	signal addr   : STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal addr_next   : STD_LOGIC_VECTOR (1 DOWNTO 0);
	
	signal wr_data 	  : STD_LOGIC_VECTOR (31 DOWNTO 0);
	signal wr_data_next : STD_LOGIC_VECTOR (31 DOWNTO 0);
	
	signal rd_reg : STD_LOGIC := '1';
	signal rd_reg_next : STD_LOGIC := '1';
	signal rd_data : STD_LOGIC_VECTOR (31 DOWNTO 0);
	
	signal n_uartRst : STD_LOGIC;
		
	type state_type is (reset, writeTX, pollRXFifo, echoRX);	-- first reset the core, then write a prompt char, 
																			-- then read and echo character back
	signal state : state_type := reset;
	signal count : unsigned (4 DOWNTO 0) := "00000";	-- counter used as sub-state
	
	signal next_state : state_type := reset;
	signal next_count : unsigned (4 DOWNTO 0) := "00000";
	
	signal nRESET : STD_LOGIC;
	
	function char_2_std_logic_vector(ch: character) return std_logic_vector is
		variable out_vector: std_logic_vector(7 downto 0);                         
		begin                                                                      
		case ch is 
			when '>' => out_vector := std_logic_vector (to_unsigned(62,8)); 
			when 'U' => out_vector := std_logic_vector (to_unsigned(85,8)); 
			when 'A' => out_vector := std_logic_vector (to_unsigned(65,8)); 
			when 'R' => out_vector := std_logic_vector (to_unsigned(82,8)); 
			when 'T' => out_vector := std_logic_vector (to_unsigned(84,8)); 
			when 'e' => out_vector := std_logic_vector (to_unsigned(101,8)); 
			when 's' => out_vector := std_logic_vector (to_unsigned(115,8)); 
			when 't' => out_vector := std_logic_vector (to_unsigned(116,8)); 
			when others => out_vector := std_logic_vector (to_unsigned(0, 8));
		end case;
		return  out_vector;                                                      
end function char_2_std_logic_vector; 
		
	
begin

	u0:	UART generic map (
								TX_FIFO_DEPTH => 4,	-- 2**4 = 16 character FIFO
								RX_FIFO_DEPTH => 4
							)
							port map (TX => UART_TXD,
								RX => UART_RXD,
								CLK => CLOCK_50,
								nRST => n_uartRst,
								WR_DATA => wr_data,
								RD_DATA => rd_data,
								ADDR	  => addr,
								n_WR	  => wr_reg,
								n_RD	  => rd_reg
							);

	nRESET <= KEY(0);
	
	process (CLOCK_50, nRESET)
	begin
		if (nRESET = '0') then 
				state <= reset;
				count <= "00000";
		elsif (CLOCK_50'event and CLOCK_50='1') then
				state <= next_state;
				count <= next_count;
				
				wr_reg  <= wr_reg_next;
				wr_data <= wr_data_next;
				addr    <= addr_next;
				rd_reg  <= rd_reg_next;
				
		end if;
	
	end process;

	process (state, count, rd_data, wr_data)
	begin
	
		next_state <= state;
		next_count <= count;
		
		addr_next <= (others => '0');
		wr_data_next <= wr_data;
		wr_reg_next  <= '1';
		rd_reg_next <= '1';
	
		n_uartRst <= '1';
	
		case state is
			when reset =>
				
				case to_integer(count) is
					when 0 =>
						 next_count <= count + 1;
						 n_uartRst <= '0';
					when 1 =>
						 next_count <= count + 1;
						 n_uartRst <= '1';
				   when 2 =>
						 next_count <= count + 1;
						 addr_next <= "10";
						 wr_reg_next <= '0';
						 wr_data_next (7 DOWNTO 0) <= "10010100"; -- control reg : 115200 baud, even parity, 1 stop bits
				   when others =>
						 next_state <= writeTX;
						 next_count <= "00000";
				end case;
				
			when writeTX =>
				-- Write prompt (UARTTest>)
				case to_integer(count) is
					when 0 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('U');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 1 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('A');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 2 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('R');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 3 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('T');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 4 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('T');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 5 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('e');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 6 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('s');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when 7 =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('t');
						wr_reg_next <= '0';
						next_count <= count + 1;
					when others =>
						addr_next <= "00";
						wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('>');
						wr_reg_next <= '0'; 
						next_count <= "00000";
						next_state <= pollRXFifo;
					end case;
					
			when pollRXFifo =>
				
				case to_integer(count) is
					when 0 => 
						next_count <= count + 1;
						addr_next <= "11";
						rd_reg_next <= '0';
					when 1 => 
						addr_next <= "11";
						rd_reg_next <= '0';
						next_count <= count + 1;	
						if rd_data(3) = '0' then
							next_count <= (others => '0');
							next_state <= echoRX;
						end if;
					when others =>
						next_count <= (others => '0');
				 end case;
				
			when echoRX =>
				
				case to_integer(count) is
					when 0 => 
						next_count <= count + 1;
						addr_next <= "01";
						rd_reg_next <= '0';
					when 1 => 
						addr_next <= "01";
						rd_reg_next <= '0';
						next_count <= count + 1;	
						wr_data_next <= rd_data;
					when 2 =>
						addr_next <= "00";
						wr_reg_next <= '0';
						next_count <= count + 1;
					when others =>
						next_count <= (others => '0');
						next_state <= pollRXFifo;
				 end case;
				 
		end case;
		
	end process;
	
end RTL;
