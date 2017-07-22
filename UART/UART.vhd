--
--	Top level of UART core
--

library ieee;
use ieee.std_logic_1164.all;


entity UART is

generic (
			TX_FIFO_DEPTH	: INTEGER := 4;	-- 2**4 = 16 depth
			RX_FIFO_DEPTH  : INTEGER := 4
		);
		
port (
		
			TX:	OUT	STD_LOGIC;
			RX:	IN		STD_LOGIC;
			
			CLK:	IN		STD_LOGIC;
			
			nRST: IN		STD_LOGIC;
			
			-- Register interface (bus slave)
			
			WR_DATA:	IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			RD_DATA: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
			
			ADDR:		IN	STD_LOGIC_VECTOR (1 DOWNTO 0);	-- 2 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = BAUDGEN, 3 = CTRL
			
			n_WR	:	IN STD_LOGIC;	-- active low, write to register 
			n_RD	:	IN STD_LOGIC  -- active low, read from register
		
		);
		
end UART;

architecture RTL of UART 
is

	component BaudRateGenerator is
		generic (
			CLOCK_FREQ: INTEGER;
			BITS: INTEGER;
			FRAC_BITS: INTEGER
		);
		port (
			BAUDSEL	: IN  STD_LOGIC_VECTOR (3 DOWNTO 0);
			TICK		: OUT STD_LOGIC;
			nRST		: IN  STD_LOGIC;
			CLK		: IN  STD_LOGIC		
		);
	end component;

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
		
	component UARTTransmitter is
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
	end component;
	
	component UARTReceiver is
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
	end component;
	
	signal txfifo_wr_data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal txfifo_nWR 	 : STD_LOGIC := '1';
	signal txfifo_rd_data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal txfifo_nRD 	 : STD_LOGIC := '1';
	
	signal rxfifo_wr_data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal rxfifo_nWR 	 : STD_LOGIC := '1';
	signal rxfifo_rd_data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal rxfifo_nRD 	 : STD_LOGIC := '1';
	
	-- Control register 
	
	-- 		Bit						|				Function
	
	--			0							|				N_STOP_BITS_0
	--			1							|				N_STOP_BITS_1    (N_STOP_BITS[1:0] : "00" : 1 stop bit, "01" 1.5 stop bits "10" 1.5 stop bits "10" 2 stop bits, "11" 1 stop bit)
	--			2							|				PARITY_0
	--			3							|				PARITY_1				(PARITY[1:0] : "00" no parity "01" even parity "10" odd parity "11" no parity
	--			4, 5, 6, 7				| 				BAUD_RATE					
	--
	--	Baud rate generator:
	--
	--		Value				Baud Rate
	--		0000				300
	--		0001				600
	--		0010				1200				
	--		0011				2400
	--		0100				4800
	--		0101				9600
	--		0110				19200
	--		0111				38400
	--		1000				57600
	--		1001				115200
	--
	--
	
	signal control_reg 		: STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal control_reg_next : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal control_reg_nWR 	: STD_LOGIC;
	
	--	Status register
	--
	--			0							|				TX_FIFO_FULL
	--			1							|				TX_FIFO_EMPTY
	--			2							|				RX_FIFO_FULL
	--			3							|				RX_FIFO_EMPTY
	--			4							|				RX_OVERRUN
	
	signal status_reg 		: STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal status_reg_next 	: STD_LOGIC_VECTOR (7 DOWNTO 0);
	
	signal baud_tick 			: STD_LOGIC;
	
begin

	status_reg_next(7 downto 4) <= (others => '0');

	baud0: BaudRateGenerator generic map (
										CLOCK_FREQ 	=> 50000000,
										BITS 			=> 15,
										FRAC_BITS 	=> 4
									)
									port map (BAUDSEL => control_reg (7 DOWNTO 4), 
												  CLK => CLK, 
												  TICK => baud_tick, 
												  nRST => nRST);
												
	txFifo0:	Fifo  generic map (
						DEPTH => TX_FIFO_DEPTH, -- TX_FIFO_DEPTH deep (can set this generic to descrease area if need be)
						BITS  => 8					-- 8 bit (1 char) width
				  )
				  port map (	CLK => CLK,
									nRST => nRST,
									WR_DATA => txfifo_wr_data, 
									n_WR => txfifo_nWR, 
									RD_DATA => txfifo_rd_data, 
									n_RD => txfifo_nRD,
									full => status_reg_next(0),
									empty => status_reg_next(1)
								); 	
								
	tx0: UARTTransmitter port map	(	CLK	=> CLK,
									nRST	=> nRST,
									nTxStart	=> status_reg(1),
									nTxDone	=> txfifo_nRD,
									txData	=> txfifo_rd_data,
									stopBits 	=> control_reg(1 downto 0),
									parityBits 	=> control_reg(3 downto 2),
									baudTick		=> baud_tick,
									TXD			=> TX
								);
	
	rxFifo0:	Fifo	generic map (
						DEPTH => RX_FIFO_DEPTH, 
						BITS  => 8					
				  )
				  port map (	CLK => CLK,
									nRST => nRST,
									WR_DATA => rxfifo_wr_data, 
									n_WR => rxfifo_nWR, 
									RD_DATA => rxfifo_rd_data, 
									n_RD => rxfifo_nRD,
									full => status_reg_next(2),
									empty => status_reg_next(3)
								);
								
	rx0: UARTReceiver port map	(	
									CLK			=> CLK,
									nRST			=> nRST,
									nRxDone		=> rxfifo_nWR,
									rxData		=> rxfifo_wr_data,
									stopBits 	=> control_reg(1 downto 0),
									parityBits 	=> control_reg(3 downto 2),
									baudTick		=> baud_tick,
									RXD			=> RX
								);
	
	process(CLK, nRST)
	begin
	
		if nRST = '0' then
			control_reg <= (others => '0');
		elsif CLK'event and CLK = '1' then
	
			-- synchronous transitions here
			
			if (control_reg_nWR = '0') then
				-- only bits 4 - 7 are user settable
				control_reg <= control_reg_next;
			else
				null;
			end if;
			
			status_reg <= status_reg_next;
			
		end if;	
	end process;

	process (ADDR, WR_DATA, n_WR, rxfifo_rd_data, n_RD, status_reg)
	begin
	
		txfifo_wr_data <= (others => '0');
		txfifo_nWR <= '1';
		
		control_reg_next <= (others => '0');
		control_reg_nWR <= '1';
		
		RD_DATA <= (others => '0');
		rxfifo_nRD <= '1';
	
		case ADDR is 
			when "00" =>	-- TX fifo
				
				txfifo_wr_data <= WR_DATA(7 downto 0);
				txfifo_nWR		<= n_WR;
		
			when "10" =>   -- CTRL
	
				control_reg_next <= WR_DATA(7 downto 0);
				control_reg_nWR  <= n_WR;
				
			when "01" => 	--	RX fifo
			
				RD_DATA(7 downto 0) <= rxfifo_rd_data;
				rxfifo_nRD			  <= n_RD;
						
			when "11" => 	-- status register
			
				RD_DATA(7 downto 0) <= status_reg;
			
			when others =>
			
				null;
				
		end case;
	
	end process;
	
end RTL;