--
--      PicoBrainTester, tester for Picoblaze compatible microcontroller core
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity PicoBrainTester is
  generic (
    ROM_SEL : natural := 0            -- select which test rom to instantiate
    );
  port (
    UART_TXD : out std_logic;
    UART_RXD : in  std_logic;

    -- CLK50
    -- TODO: generate clock from 24MHz clock using PLL

    CLOCK_50 : in std_logic;

    -- use 1 key for asynchronous reset

    KEY : in std_logic_vector (3 downto 0) := "1111";

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
end PicoBrainTester;

architecture RTL of PicoBrainTester is

  -- The PicoBrain

  component PicoBrain is
    port (
      address       : out std_logic_vector (9 downto 0);
      instruction   : in  std_logic_vector (17 downto 0);
      port_id       : out std_logic_vector (7 downto 0);
      write_strobe  : out std_logic;
      out_port      : out std_logic_vector (7 downto 0);
      read_strobe   : out std_logic;
      in_port       : in  std_logic_vector (7 downto 0);
      interrupt     : in  std_logic;
      interrupt_ack : out std_logic;
      reset         : in  std_logic;
      clk           : in  std_logic
      );
  end component;

  -- Test ROMs

  component test_rom_1 is

    port
      (
        clk  : in  std_logic;
        addr : in  natural range 0 to 1023;
        q    : out std_logic_vector(17 downto 0)
        );

  end component;

  -- signals

  signal rom_addr : std_logic_vector(9 downto 0);
  signal rom_addr_nat : natural range 0 to 1023;
  signal rom_data : std_logic_vector(17 downto 0);
  
  signal reset : std_logic := '0';

begin

  reset <= not KEY(0);
  rom_addr_nat <= to_integer(unsigned(rom_addr));

  rom0 : if ROM_SEL = 0 generate
    testrom1: 
    test_rom_1
      port map (
        clk  => CLOCK_50,
        addr => rom_addr_nat,
        q    => rom_data
        );
  end generate rom0;

  pb0 : PicoBrain
    port map (
      address       => rom_addr,
      instruction   => rom_data,
      port_id       => open,
      write_strobe  => open,
      out_port      => open,
      read_strobe   => open,
      in_port       => (others => '0'),
      interrupt     => '0',
      interrupt_ack => open,
      reset         => reset,
      clk           => CLOCK_50
      );

end RTL;

