--
--      UART Lite package
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package UARTLitePackage is

  component UARTLite is

    generic (
      TX_FIFO_DEPTH : integer := 2;     -- 2**2 = 16 depth
      RX_FIFO_DEPTH : integer := 2;
      BAUD_RATE     : integer := 115200;
      CLOCK_FREQ    : integer := 50000000;
      BAUD_BITS     : integer := 5
      );

    port (

      TX : out std_logic;
      RX : in  std_logic;

      CLK : in std_logic;

      nRST : in std_logic;

      -- Register interface (bus slave)

      WR_DATA : in  std_logic_vector (31 downto 0);
      RD_DATA : out std_logic_vector (31 downto 0);

      ADDR : in std_logic_vector (1 downto 0);  -- 2 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = BAUDGEN, 3 = CTRL

      n_WR : in std_logic;              -- active low, write to register 
      n_RD : in std_logic               -- active low, read from register

      );

  end component;

end UARTLitePackage;
