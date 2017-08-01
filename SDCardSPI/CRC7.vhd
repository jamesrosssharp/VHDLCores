--
--              CRC7 generator
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CRC7 is
  port (
    din  : in STD_LOGIC;
    n_WR : in STD_LOGIC;
    clk  : in STD_LOGIC;
    nRST : in STD_LOGIC;
    crc7 : out STD_LOGIC_VECTOR (6 downto 0)
    );
end CRC7;

architecture RTL of CRC7 is
  signal crc7_data 		: STD_LOGIC_VECTOR (6 downto 0) := (others => '0');
  signal crc7_data_next : STD_LOGIC_VECTOR (6 downto 0) := (others => '0');
begin

  crc7 <= crc7_data;

  process (clk, nRST)
  begin
    if (nRST = '0') then
      crc7_data <= (others => '0');
    elsif (clk'event and clk = '1') then
      crc7_data <= crc7_data_next;
    end if;
  end process;

  process (din, n_WR, crc7_data)
    variable din_prime : STD_LOGIC := '0';
  begin
  
	crc7_data_next <= crc7_data;
  
    if (n_WR = '0') then
      din_prime := din xor crc7_data(6);

      crc7_data_next(0) <= din_prime;
      crc7_data_next(1) <= crc7_data(0);
      crc7_data_next(2) <= crc7_data(1);
      crc7_data_next(3) <= crc7_data(2) xor din_prime;
      crc7_data_next(4) <= crc7_data(3);
      crc7_data_next(5) <= crc7_data(4);
      crc7_data_next(6) <= crc7_data(5);
      
    end if;
  end process;
end RTL;

      
      
