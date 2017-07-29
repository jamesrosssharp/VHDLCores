--
--		Test bench for SPIMasterLite
--

library IEEE;
use 	  IEEE.std_logic_1164.all;
use 	  IEEE.numeric_std.all;

entity SPIMasterLite_tb is
	generic (
		SPI_MODE : integer := 1
	);
end 	 SPIMasterLite_tb;

architecture RTL of SPIMasterLite_tb
is

	component SPIMasterLite is
		generic (
			CLOCK_FREQ		: real 			:= 50000000.0;
			SPI_FREQ			: real 			:= 12500000.0;
			BITS				: integer 	 	:= 8;
			TX_FIFO_DEPTH	: integer 		:= 3;	-- 2**3 = 8 word FIFO
			RX_FIFO_DEPTH	: integer 		:= 1;	-- 2**1 = 2 word FIFO
			SPI_MODE			: integer		:= 0
		);
		port (
			wr_data	: IN 	STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
			n_WR		: IN 	STD_LOGIC;
			rd_data	: OUT 	STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
			n_RD		: IN 	STD_LOGIC;
			control  : IN 	STD_LOGIC;
			status 	: OUT STD_LOGIC_VECTOR (3 downto 0);
			MISO 		: IN 	STD_LOGIC;
			MOSI 		: OUT STD_LOGIC;
			nSS  		: OUT STD_LOGIC;
			SCK  		: OUT STD_LOGIC;
			CLK		: IN 	STD_LOGIC;
			nRST		: IN 	STD_LOGIC
		);
	end component;

	signal spi_wr_data	:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal spi_n_wr		:	STD_LOGIC;
	signal spi_rd_data	:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal spi_n_rd		:  STD_LOGIC := '1';
	
	signal control_word	:	STD_LOGIC;
	signal status_word	:	STD_LOGIC_VECTOR (3 DOWNTO 0);
	
	signal miso				: 	STD_LOGIC;
	signal mosi				:	STD_LOGIC;
	signal slave_select	: 	STD_LOGIC;
	signal serial_clk		:	STD_LOGIC;
	signal main_clk		:	STD_LOGIC;
	signal n_reset			:	STD_LOGIC;
	
	signal tx_data_acc		:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal tx_data				:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	
	signal data_bits			: integer := 0;
	
	signal rx_byte				: STD_LOGIC_VECTOR (7 DOWNTO 0) := std_logic_vector(to_unsigned(16#AA#, 8));
	
	signal recvd_byte				: STD_LOGIC_VECTOR (7 DOWNTO 0);
	
	
	constant	clk_period : time := 0.020 us;
begin

spi0:	SPIMasterLite  generic map (
								SPI_MODE => SPI_MODE
							)
							port map (
								wr_data	=> spi_wr_data,
								n_WR		=> spi_n_wr,
								rd_data	=> spi_rd_data,
								n_RD		=> spi_n_rd,
								control  => control_word,
								status => status_word,
								MISO  => miso,
								MOSI 	=> mosi,
								nSS  	=> slave_select,
								SCK   => serial_clk,
								CLK	=> main_clk,
								nRST	=> n_reset
							);

-- generate clock


	process 
	begin
		main_clk <= '0';
		wait for clk_period / 2;
		main_clk <= '1';
		wait for clk_period / 2;
	end process;					
							
							
	process
	begin
			spi_wr_data <= (others => '0');
			spi_n_wr <= '1';
			
			n_reset <= '1';
			-- pulse reset
			wait for 100 ns;		
			n_reset <= '0';
			wait for 100 ns;
			n_reset <= '1';
			
			
			wait until main_clk = '0';
		
			spi_wr_data <= std_logic_vector(to_unsigned(16#AA#, 8));
			spi_n_wr <= '0';
			wait for clk_period;
			
			spi_wr_data <= std_logic_vector(to_unsigned(16#55#, 8));
			spi_n_wr <= '0';
			wait for clk_period;
		
			spi_wr_data <= std_logic_vector(to_unsigned(16#99#, 8));
			spi_n_wr <= '0';
			wait for clk_period;
			
			spi_wr_data <= std_logic_vector(to_unsigned(16#66#, 8));
			spi_n_wr <= '0';
			wait for clk_period;
	
			spi_n_wr <= '1';
			
			wait for 500us;
			
			wait;

	end process;

	process (status_word)
	begin
		if (status_word(3) = '0') then
			recvd_byte <= spi_rd_data;
			spi_n_rd <= '0'; 
		else
			spi_n_rd <= '1';
		end if;
	end process;
	
	
	proc0 : if SPI_MODE = 0 or SPI_MODE = 3 generate
		process (main_clk, serial_clk, mosi, slave_select)
		begin
			if rising_edge(serial_clk) then
				tx_data_acc <=  mosi & tx_data_acc(7 downto 1);
				data_bits <= data_bits + 1;
			end if;
			
			if falling_edge(serial_clk) or falling_edge(slave_select) then
				if (data_bits < 8) then
					miso <= rx_byte(data_bits);
				end if;
			end if;
			
			if data_bits = 8 then
				tx_data <= tx_data_acc;
				data_bits <= 0;
				rx_byte <= not rx_byte;
			end if;
		
		end process;
	end generate proc0;
	
	proc1 : if SPI_MODE = 1 or SPI_MODE = 2 generate
		process (main_clk, serial_clk, mosi, slave_select)
		begin
			if falling_edge(serial_clk) then
				tx_data_acc <=  mosi & tx_data_acc(7 downto 1);
				data_bits <= data_bits + 1;
			end if;
		
			if rising_edge(serial_clk) or falling_edge(slave_select) then
				if (data_bits < 8) then
					miso <= rx_byte(data_bits);
				end if;
			end if;
			
			if data_bits = 8 then
				tx_data <= tx_data_acc;
				data_bits <= 0;
			end if;
		
		end process;
	end generate proc1;

end RTL;