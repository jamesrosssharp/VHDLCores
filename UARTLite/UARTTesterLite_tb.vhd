--
--      Test bench for UARTLite (instantiates UART tester lite, the synthesisable top level)
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity UARTTesterLite_tb is
end UARTTesterLite_tb;

architecture RTL of UARTTesterLite_tb
is

  component UARTTesterLite
    port (

      UART_TXD : OUT STD_LOGIC;
      UART_RXD : IN  STD_LOGIC;
      CLOCK_50 : IN  STD_LOGIC;
      KEY      : IN  STD_LOGIC_VECTOR (3 DOWNTO 0)

      );
  end component;

  signal TX  : STD_LOGIC;
  signal RX  : STD_LOGIC                     := '1';
  signal CLK : STD_LOGIC                     := '0';
  signal KEY : STD_LOGIC_VECTOR (3 DOWNTO 0) := "1111";

  constant clk_period : time := 0.020 us;
  constant bit_period : time := 8680.5 ns;

  constant stop_period : time := 8680.5 ns;

  signal tx_byte    : STD_LOGIC_VECTOR (7 DOWNTO 0);
  signal parity_bit : STD_LOGIC;

  signal chars_transmitted : integer := 0;

  procedure make_serial_byte
    (constant char : in  integer;
     signal tx     : out std_logic
     ) is
    variable tx_char : STD_LOGIC_VECTOR (7 downto 0);
  begin
    
    tx_char := std_logic_vector(to_unsigned(char, 8));

    tx <= '0';

    wait for bit_period;

    for i in tx_char'reverse_range loop
      tx <= tx_char(i);
      wait for bit_period;
    end loop;

    -- stop bit

    tx <= '1';

    wait for stop_period;
    
  end make_serial_byte;
  
  
  
begin

  uart0 : component UARTTesterLite port map (UART_TXD => TX, UART_RXD => RX, CLOCK_50 => CLK, KEY => KEY);

  process
  begin
    CLK <= '0';
    wait for clk_period / 2;
    CLK <= '1';
    wait for clk_period / 2;
  end process;

  process
  begin
    wait for 10 ns;
    KEY(0) <= '0';
    wait for 40 ns;
    KEY(0) <= '1';
    wait for 10 ms;
  end process;

  -- process TX data
  process
    variable tx_byte_var : STD_LOGIC_VECTOR (7 DOWNTO 0);
  begin
    
    wait until TX = '0';
    tx_byte_var := (others => '0');

    for i in tx_byte'reverse_range loop
      wait for bit_period;
      tx_byte_var(i) := TX;
    end loop;

    -- stop bit

    wait for stop_period;

    tx_byte <= tx_byte_var;

    chars_transmitted <= chars_transmitted + 1;
    
  end process;

  process
  begin
    
    wait until chars_transmitted = 1;

    wait for 1000ns;

    -- transmit some chars

    make_serial_byte(16#41#, RX);

    wait until chars_transmitted = 2;

    make_serial_byte(16#42#, RX);

    wait until chars_transmitted = 3;

    make_serial_byte(16#43#, RX);

    wait until chars_transmitted = 4;

    -- simulate bad packet / noise on the line
    RX <= '0';

    wait for 100 ns;

    RX <= '1';

    wait;
    
  end process;
  
end RTL;
