--
--      Test bench for SDCardSPITester
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SDCardSPITester_tb is
end SDCardSPITester_tb;

architecture RTL of SDCardSPITester_tb is

  component SDCardSPITester is
    generic (
      CLOCK_FREQ : REAL := 50000000.0   -- frequency of driving clock
      );
    port (

      -- SD Card pins
      SD_DAT  : IN    STD_LOGIC;        -- MISO
      SD_CMD  : OUT   STD_LOGIC;        -- MOSI
      SD_CLK  : OUT   STD_LOGIC;        -- CLK
      SD_DAT3 : INOUT STD_LOGIC;        -- \CS / card present

      -- UART Pins
      UART_TXD : OUT STD_LOGIC;
      UART_RXD : IN  STD_LOGIC;

      -- main clock
      CLOCK_50 : IN STD_LOGIC;

      -- KEY[0] used as asynchronous reset 
      KEY : IN STD_LOGIC_VECTOR (3 DOWNTO 0)

      );
  end component;

  constant clk_period : time := 0.020 us;

  constant bit_period  : time := 8680.5 ns;
  constant stop_period : time := 8680.5 ns;

  signal parity_bit : STD_LOGIC;
  signal tx_byte    : STD_LOGIC_VECTOR (7 downto 0);

  signal tb_sd_dat  : STD_LOGIC := '1';
  signal tb_sd_cmd  : STD_LOGIC := '1';
  signal tb_sd_clk  : STD_LOGIC := '0';
  signal tb_sd_dat3 : STD_LOGIC := 'Z';

  signal tb_uart_txd : STD_LOGIC;
  signal tb_uart_rxd : STD_LOGIC;

  signal CLK    : STD_LOGIC;
  signal tb_key : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111";

  signal chars_transmitted : INTEGER := 0;
  
  signal spi_clks : INTEGER := 0;
  
  signal tb_reset_spi_clks : STD_LOGIC;
  
  --sent_sd_response(tb_sd_dat, tb_sd_clk, 16#ff#);
  
  procedure send_sd_response
    (signal tb_sd_dat : out std_logic;
     signal tb_sd_clk : in  std_logic;
	  constant byte_response : in integer) is
		variable response_byte : std_logic_vector (6 downto 0);
  begin
	response_byte := std_logic_vector(to_unsigned(byte_response, 7));
	wait until tb_sd_clk = '0';
	tb_sd_dat <= '0';
	
	for i in response_byte'range loop
		wait until tb_sd_clk = '1';
		wait until tb_sd_clk = '0';
		tb_sd_dat <= response_byte(i);
	end loop;
  
	wait until tb_sd_clk = '1';
	wait until tb_sd_clk = '0';
	
	tb_sd_dat <= '1';
  end send_sd_response;
  
begin

  sd0 : SDCardSPITester
    port map (
      SD_DAT   => tb_sd_dat,
      SD_CMD   => tb_sd_cmd,
      SD_CLK   => tb_sd_clk,
      SD_DAT3  => tb_sd_dat3,
      UART_TXD => tb_uart_txd,
      UART_RXD => tb_uart_rxd,
      CLOCK_50 => CLK,
      KEY      => tb_key
      );

  -- generate clock
  process
  begin
    CLK <= '0';
    wait for clk_period / 2;
    CLK <= '1';
    wait for clk_period / 2;
  end process;

  -- generate command responses etc.

  process
  begin
    wait for 100 ns;
    tb_key(0) <= '0';
    wait for 50 ns;
    tb_key(0) <= '1';
    wait for 200 ns;
    tb_sd_dat3 <= 'H';
    -- wait for command to be sent
	 wait until spi_clks = 250;
	 send_sd_response(tb_sd_dat, tb_sd_clk, 16#aa#);
    wait;
  end process;

  -- process TX data
  process
    variable tx_byte_var : STD_LOGIC_VECTOR (7 DOWNTO 0);
  begin
    
    wait until tb_uart_txd = '0';
    tx_byte_var := (others => '0');

    for i in tx_byte'reverse_range loop
      wait for bit_period;
      tx_byte_var(i) := tb_uart_txd;
    end loop;

    -- get parity bit

    wait for bit_period;
    parity_bit <= tb_uart_txd;

    -- stop bit

    wait for stop_period;

    tx_byte <= tx_byte_var;

    chars_transmitted <= chars_transmitted + 1;
    
  end process;

  process (tb_sd_clk, tb_reset_spi_clks)
  begin
	  if tb_reset_spi_clks = '1' then
		spi_clks <= 0;
     elsif rising_edge(tb_sd_clk) then
		spi_clks <= spi_clks + 1;
	  end if;
  end process;
  
end RTL;


