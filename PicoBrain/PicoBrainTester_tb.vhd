--
--      TestBench for PicoBrain tester
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity PicoBrainTester_tb is
end PicoBrainTester_tb;

architecture RTL of PicoBrainTester_tb
is

  component PicoBrainTester is
    generic (
      ROM_SEL : natural := 1          -- select which test rom to instantiate
      );
    port (
      UART_TXD : out std_logic;
      UART_RXD : in  std_logic;

      -- CLK50
      -- TODO: generate clock from 24MHz clock using PLL

      CLOCK_50 : in std_logic;

      -- use 1 key for asynchronous reset

      KEY : in std_logic_vector (3 downto 0);

      -- hex display

      HEX0 : out std_logic_vector(7 downto 0);
      HEX1 : out std_logic_vector(7 downto 0);
      HEX2 : out std_logic_vector(7 downto 0);
      HEX3 : out std_logic_vector(7 downto 0);

      -- LEDs

      LEDR : out std_logic_vector(9 downto 0);
      LEDG : out std_logic_vector(7 downto 0);

      -- Switches

      SW : in std_logic_vector(9 downto 0)

      );
  end component;

  constant clk_period : time := 0.020 us;

  constant bit_period : time := 8680.5 ns;

  constant stop_period     : time    := 8680.5 ns;
  signal tx_byte           : std_logic_vector (7 downto 0);
  signal chars_transmitted : integer := 0;


  signal tb_clk : std_logic;
  signal tb_key : std_logic_vector (3 downto 0) := "1111";

  signal tb_txd : std_logic;
  
  signal tb_hex0 : std_logic_vector (7 downto 0);
  signal tb_hex1 : std_logic_vector (7 downto 0);
  signal tb_hex2 : std_logic_vector (7 downto 0);
  signal tb_hex3 : std_logic_vector (7 downto 0);
  
  signal tb_ledg : std_logic_vector (7 downto 0);
  signal tb_ledr : std_logic_vector (9 downto 0);
  

begin

  pbt0 : PicoBrainTester port map (
    UART_TXD => tb_txd,
    UART_RXD => '1',
    CLOCK_50 => tb_clk,
    KEY      => tb_key,
    HEX0     => tb_hex0,
    HEX1     => tb_hex1,
    HEX2     => tb_hex2,
    HEX3     => tb_hex3,
    LEDR     => tb_ledr,
    LEDG     => tb_ledg,
    SW       => "0000000000"
    );

  process
  begin
    tb_clk <= '0';
    wait for clk_period / 2;
    tb_clk <= '1';
    wait for clk_period / 2;
  end process;

  process
  begin
    wait for 13 ns;
    tb_key(0) <= '0';
    wait for 16 ns;
    tb_key(0) <= '1';
    wait for 1 ms;

	 for i in 0 to 7 loop
		 tb_key(1) <= '0';
		 wait for 100ns;
		 tb_key(1) <= '1';
		 wait for 1ms;
	end loop;

  end process;


  -- process serial data
  process
    variable tx_byte_var : std_logic_vector (7 downto 0);
  begin

    wait until tb_txd = '0';
    tx_byte_var := (others => '0');

    for i in tx_byte'reverse_range loop
      wait for bit_period;
      tx_byte_var(i) := tb_txd;
    end loop;

    -- stop bit

    wait for stop_period;

    tx_byte <= tx_byte_var;

    chars_transmitted <= chars_transmitted + 1;

  end process;



end RTL;
