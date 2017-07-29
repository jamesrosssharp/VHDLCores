--
--	SPI Master lite
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SPIMasterLite is
	generic (
		CLOCK_FREQ	: real := 50000000.0;
		SPI_FREQ		: real := 10000000.0;
		BITS			: integer := 8;
		TX_FIFO_DEPTH	: integer := 3;	-- 2**3 = 8 word FIFO
		RX_FIFO_DEPTH	: integer := 1;	-- 2**1 = 2 word FIFO
		SPI_MODE			: integer := 0
		
		--
		--			SPI Mode
		--
		--		SPI Mode  |  CPOL   | CPHA  
		--		0					0			0		Clock normally low. Data captured on rising edge.
		--		1					0			1		Clock normally low. Data captured on falling edge.
		--		2					1			0		Clock normally high. Data captured on falling edge.
		--		3					1			1		Clock normally high. Data captured on rising edge.
		
	);
	--
	--		Controller has a raw signal interface to make it easier to
	--		interface to other logic. TODO: wrapper with bus interface.
	--
	port (
	
		-- to tx fifo
		wr_data	: IN STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		n_WR		: IN STD_LOGIC;
		
		-- from rx fifo
		rd_data	: OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		n_RD		: IN STD_LOGIC;
		
		--			Control Input
		--		BIT		|		Function
		--		------------------------
		--		0			|		transmit inhibit (1 = inhibit, 0 = transmit)
		
		control  : IN STD_LOGIC;
	
		--			Status Output
		--		BIT		|		Function
		--		-----------------------
		--		0			|		TX Fifo Full
		--		1			|		TX Fifo Empty
		--		2			|		RX Fifo Full
		--		3			|		RX Fifo Empty
		--
		
		status :	OUT STD_LOGIC_VECTOR (3 downto 0);
	
		-- SPI signals
		
		MISO :	IN STD_LOGIC;
		MOSI : 	OUT STD_LOGIC;
		nSS  :	OUT STD_LOGIC;
		SCK  :	OUT STD_LOGIC;
	
		-- signals
		
		CLK	: IN STD_LOGIC;
		nRST	: IN STD_LOGIC
	
	);
end SPIMasterLite;

architecture RTL of SPIMasterLite is

	component Fifo is
		generic (
						DEPTH : INTEGER;
						BITS	: INTEGER
				 );
		port (	
					CLK		: IN STD_LOGIC;
					nRST		: IN STD_LOGIC;
					WR_DATA  : IN STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
					n_WR 		: IN STD_LOGIC;
					RD_DATA	: OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
					n_RD		: IN STD_LOGIC;
					full		: OUT STD_LOGIC;
					empty		: OUT STD_LOGIC
				); 
	end component;
	
	signal txfifo_rd_data	: STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
	signal txfifo_nRD			: STD_LOGIC := '1';
	signal txfifo_nRD_next	: STD_LOGIC := '1';
	
	signal baud_tick			: STD_LOGIC	:= '0';
	signal baud_count			: INTEGER 	:= 0;
	
	type 	 state_type is (idle, latchtx, preTx, txbits, pollTxFifo);	
	signal state 		: state_type := idle;
	signal state_next : state_type;
	
	signal tx_word				: STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
	signal tx_word_next		: STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);

	signal data_bit		:	INTEGER := 0;
	signal data_bit_next	:	INTEGER;
	
	signal serial_clk			: STD_LOGIC;
	signal serial_clk_next	: STD_LOGIC;

	signal serial_data		: STD_LOGIC	:= '1';
	signal serial_data_next : STD_LOGIC;
	
	signal serial_slave_select		: STD_LOGIC	:= '1';
	signal serial_slave_select_next : STD_LOGIC;
	
	signal serial_status		: STD_LOGIC_VECTOR (3 DOWNTO 0);
	
	signal rx_word				: STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
	signal rx_word_next		: STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);

	signal rxfifo_nWR			: STD_LOGIC := '1';
	signal rxfifo_nWR_next	: STD_LOGIC := '1';
	
	
	procedure reset_serial_clock
		(signal serial_clk: OUT STD_LOGIC) is
	begin
			if (SPI_MODE = 0) or (SPI_MODE = 1) then
				serial_clk <= '0';
			else
				serial_clk <= '1';
			end if;
	end reset_serial_clock;
	
	procedure do_tx
		(signal data_bit_next	: OUT INTEGER;
		 signal state_next		: OUT state_type;
		 signal tx_word_next		: OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		 signal txfifo_nRD_next	: OUT STD_LOGIC;
		 signal serial_clk_next	: OUT STD_LOGIC;
		 signal tx_word			: IN  STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		 signal data_bit			: IN  INTEGER;
		 signal serial_clk		: IN  STD_LOGIC;
		 signal rx_word			: IN STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		 signal rx_word_next		: OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
		 signal MISO				: IN  STD_LOGIC;
		 signal rxfifo_nWR_next : OUT STD_LOGIC;
		 constant clock_pol		: IN  STD_LOGIC;
		 constant terminal_count  : IN  INTEGER
		) is
	begin
	
		if serial_clk = clock_pol then	-- on given polarity (rising, falling) change tx data
			data_bit_next <= data_bit + 1;
			tx_word_next <= '0' & tx_word(BITS - 1 downto 1);
			
	
			if (data_bit = terminal_count) then
				state_next <= pollTxFifo;
				txfifo_nRD_next <= '0';
				rxfifo_nWR_next <= '0';
				reset_serial_clock(serial_clk_next);
			end if;
		else										-- on opposite polarity (falling, rising) read rx data
			rx_word_next <=  MISO & rx_word(BITS - 1 DOWNTO 1);
		end if;
			
	end do_tx;

	
begin

txfifo0:	Fifo generic map (
							DEPTH => TX_FIFO_DEPTH,
							BITS => BITS
						)
						port map (CLK => CLK, nRST => nRST, WR_DATA => wr_data, 
								n_WR => n_WR, RD_DATA => txfifo_rd_data,
								n_RD => txfifo_nRD, full => serial_status(0), 
								empty => serial_status(1));

rxfifo0:	Fifo generic map (
							DEPTH => RX_FIFO_DEPTH,
							BITS => BITS
						)
						port map (CLK => CLK, nRST => nRST, WR_DATA => rx_word, 
								n_WR => rxfifo_nWR, RD_DATA => rd_data,
								n_RD => n_RD, full => serial_status(2), 
								empty => serial_status(3));

								
	-- Synchronous updates

	process (CLK, nRST)	
	begin

		if (nRST = '0') then
			txfifo_nRD <= '1';
			
			reset_serial_clock(serial_clk);
			
			serial_data <= '0';
			data_bit <= 0;
			tx_word <= (others => '0');
			state <= idle;
			serial_slave_select <= '1';
			rx_word <= (others => '0');
			rxfifo_nWR <= '1';
		elsif rising_edge(CLK) then 
			txfifo_nRD 	<= txfifo_nRD_next;
			serial_clk 	<= serial_clk_next;
			serial_data <= serial_data_next;
			data_bit 				<= data_bit_next;
			tx_word 					<= tx_word_next;
			state 					<= state_next;
			serial_slave_select  <= serial_slave_select_next;
			rxfifo_nWR 				<= rxfifo_nWR_next;
			rx_word    				<= rx_word_next;
		end if;

	end process;							
									
									
	-- SPI baud tick generator

	process (CLK)
	begin

		if rising_edge(CLK) then
		
			baud_count <= baud_count + 1;
			baud_tick <= '0';
		
			if (baud_count >= (integer(CLOCK_FREQ / SPI_FREQ / 2.0) - 1)) then
				baud_count <= 0;
				baud_tick <= '1';
			end if;
		
		end if; 

	end process;

	process (CLK, serial_status, state, data_bit, 
				txfifo_nRD, tx_word, serial_clk, 
				baud_tick, txfifo_rd_data, serial_data,
				MISO, rx_word
				)
	begin
	
		state_next <= state;
		serial_clk_next <= serial_clk;
		data_bit_next	 <= data_bit;
		txfifo_nRD_next <= '1';
		tx_word_next <= tx_word;
		serial_data_next <= serial_data;
		serial_slave_select_next <= '1';
		rxfifo_nWR_next <= '1';
		rx_word_next <= rx_word;
		
		
		case state is
			when idle =>
				data_bit_next <= 0;
				
				reset_serial_clock(serial_clk_next);
				
				serial_data_next <= '0';
				if (serial_status(1) = '0') then
					state_next <= latchtx;
				end if;
			when latchtx =>
				tx_word_next <= txfifo_rd_data;
				serial_slave_select_next <= '0';

				if (serial_status(1) = '0') then
					state_next <= preTx;
				else
					state_next <= idle;
				end if;
			when preTx  =>
				serial_slave_select_next <= '0';
				serial_data_next <= tx_word(0);
				state_next <= txbits;
			when txbits =>
			
				serial_slave_select_next <= '0';
				serial_data_next <= tx_word(0);
						
				if baud_tick = '1' then
					serial_clk_next <= not serial_clk;
					
					if SPI_MODE = 0 then
						do_tx
						(data_bit_next, state_next, tx_word_next, txfifo_nRD_next,
						 serial_clk_next, tx_word, data_bit, serial_clk, rx_word,
						 rx_word_next, MISO, rxfifo_nWR_next, '1', BITS - 1); -- change data on falling_edge, read data on rising_edge
					elsif SPI_MODE = 1 then
						do_tx
						(data_bit_next, state_next, tx_word_next, txfifo_nRD_next,
						 serial_clk_next, tx_word, data_bit, serial_clk, rx_word,
						 rx_word_next, MISO, rxfifo_nWR_next, '0', BITS); -- change data on rising_edge, read data on falling edge
					elsif SPI_MODE = 2 then	 
						 do_tx
						(data_bit_next, state_next, tx_word_next, txfifo_nRD_next,
						 serial_clk_next, tx_word, data_bit, serial_clk, rx_word,
						 rx_word_next, MISO, rxfifo_nWR_next, '0', BITS); -- change data on rising_edge, read data on falling_edge
				   elsif SPI_MODE = 3 then
						do_tx
						(data_bit_next, state_next, tx_word_next, txfifo_nRD_next,
						 serial_clk_next, tx_word, data_bit, serial_clk, rx_word,
						 rx_word_next, MISO, rxfifo_nWR_next, '1', BITS - 1); -- change data on falling_edge, read data on rising_edge
					end if;
						
				end if;
				
			when others =>
				
				data_bit_next <= 0;
				serial_slave_select_next <= '0';
				
				if (serial_status(1) = '0') then
					state_next <= latchtx;
				else
					state_next <= idle;
				end if;

		end case;
	
	end process;
	
	SCK <= serial_clk;
	MOSI <= serial_data;
	nSS  <= serial_slave_select;
	status <= serial_status;
	
end RTL;
	
