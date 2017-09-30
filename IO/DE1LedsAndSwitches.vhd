--
--      DE1LedsAndSwitches
--
--      16 bit register interface to DE1 board LEDs, switches and 7-segment displays
--
--      Register                |       Function
--      -----------------------------------------------------
--      0                       |       green LEDs
--      1                       |       red LEDs
--      2                       |       Switches
--      3                       |       Hex 0
--      4                       |       Hex 1
--      5                       |       Hex 2
--      6                       |       Hex 3
--
--      
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DE1LedsAndSwitches is
  port (

    clk   : in std_logic;
    reset : in std_logic;

    SW   : in  std_logic_vector (9 downto 0);
    LEDR : out std_logic_vector (9 downto 0);
    LEDG : out std_logic_vector (7 downto 0);
    HEX0 : out std_logic_vector (6 downto 0);
    HEX1 : out std_logic_vector (6 downto 0);
    HEX2 : out std_logic_vector (6 downto 0);
    HEX3 : out std_logic_vector (6 downto 0);

    port_address : in std_logic_vector(2 downto 0);
    port_wr_data : in std_logic_vector(15 downto 0);
    port_rd_data : out std_logic_vector(15 downto 0);
    port_n_wr    : in std_logic;
    port_n_rd    : in std_logic

    );
end DE1LedsAndSwitches;

architecture RTL of DE1LedsAndSwitches is

  signal green_leds, green_leds_next : std_logic_vector(15 downto 0);
  signal red_leds, red_leds_next     : std_logic_vector(15 downto 0);
  signal sig_hex0, hex0_next             : std_logic_vector(15 downto 0);
  signal sig_hex1, hex1_next             : std_logic_vector(15 downto 0);
  signal sig_hex2, hex2_next             : std_logic_vector(15 downto 0);
  signal sig_hex3, hex3_next             : std_logic_vector(15 downto 0);

begin

  LEDR <= red_leds(9 downto 0);
  LEDG <= green_leds(7 downto 0);
  HEX0 <= sig_hex0(6 downto 0);
  HEX1 <= sig_hex1(6 downto 0);
  HEX2 <= sig_hex2(6 downto 0);
  HEX3 <= sig_hex3(6 downto 0);
  
  process (clk, reset)
  begin

    if reset = '1' then
      green_leds <= (others => '0');
      red_leds   <= (others => '0');
      sig_hex0       <= (others => '0');
      sig_hex1       <= (others => '0');
		sig_hex2       <= (others => '0');
      sig_hex3       <= (others => '0');
    elsif rising_edge(clk) then
      green_leds <= green_leds_next;
      red_leds   <= red_leds_next;
      sig_hex0       <= hex0_next;
      sig_hex1       <= hex1_next;
      sig_hex2       <= hex2_next;
      sig_hex3       <= hex3_next;
    end if;
  end process;

  process (port_address, port_n_rd, port_n_wr, port_wr_data,
           green_leds, red_leds, sig_hex0, sig_hex1, sig_hex2, sig_hex3, SW)
  begin

    green_leds_next <= green_leds;
    red_leds_next   <= red_leds;
    hex0_next       <= sig_hex0;
    hex1_next       <= sig_hex1;
    hex2_next       <= sig_hex2;
    hex3_next       <= sig_hex3;

    port_rd_data <= (others => '0');

    if port_n_rd = '1' then

      case to_integer(unsigned(port_address(2 downto 0))) is
        when 0 =>                       -- green LEDs
          port_rd_data <= green_leds;
        when 1 =>                       -- red LEDs
          port_rd_data <= red_leds;
        when 2 =>
          port_rd_data <= "000000" & SW;
        when 3 =>
          port_rd_data <= sig_hex0;
        when 4 =>
          port_rd_data <= sig_hex1;
        when 5 =>
          port_rd_data <= sig_hex2;
        when 6 =>
          port_rd_data <= sig_hex3;
        when others =>
          null;
      end case;

    elsif port_n_wr = '1' then
      case to_integer(unsigned(port_address(2 downto 0))) is
        when 0 =>                       -- green LEDs
          green_leds_next <= port_wr_data;
        when 1 =>                       -- red LEDs
          red_leds_next <= port_wr_data;
        when 3 =>
          hex0_next <= port_wr_data;
        when 4 =>
          hex1_next <= port_wr_data;
        when 5 =>
          hex2_next <= port_wr_data;
        when 6 =>
          hex3_next <= port_wr_data;
        when others =>
          null;
      end case;
    end if;

  end process;


end RTL;
