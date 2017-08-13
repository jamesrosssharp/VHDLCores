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
      ROM_SEL : natural := 0           -- select which test rom to instantiate
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

  signal tb_clk : std_logic;
  signal tb_key : std_logic_vector (3 downto 0) := "1111";
  
begin

  pbt0 : PicoBrainTester port map (
    UART_TXD => open,
    UART_RXD => '1',
    CLOCK_50 => tb_clk,
    KEY      => tb_key,
    HEX0     => open,
    HEX1     => open,
    HEX2     => open,
    HEX3     => open,
    LEDR     => open,
    LEDG     => open,
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
    wait for 10 ns;
    tb_key(0) <= '0';
    wait for 40 ns;
    tb_key(0) <= '1';
    wait for 10 ms;
  end process;


end RTL;
