-- Quartus II VHDL Template
-- Single-Port ROM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_rom_1 is

  generic
    (
      DATA_WIDTH : natural := 18;
      ADDR_WIDTH : natural := 10
      );

  port
    (
      clk  : in  std_logic;
      addr : in  natural range 0 to 2**ADDR_WIDTH - 1;
      q    : out std_logic_vector((DATA_WIDTH -1) downto 0)
      );

end entity;

architecture rtl of test_rom_1 is

  -- Build a 2-D array type for the RoM
  subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
  type memory_t is array(7 downto 0) of word_t;

  -- Declare the ROM signal and specify a default value.        Quartus II
  -- will create a memory initialization file (.mif) based on the 
  -- default value.
  signal rom : memory_t := (0 => "000000000010101010", -- LOAD r0, 0xaa
                            1 => "001010000000001111", -- AND r0, 0x0f
                            2 => "000000000100100010", -- LOAD r1, 0x0202
                            3 => "011001000000010000", -- ADD  r0, r1
									 4 => "000000001010101010", -- LOAD r2, 0xaa
									 5 => "000001001100100000", -- LOAD r3, r2
									 6 => "001100001001010101", -- OR r2, 0x55
									 7 => "001111001000110000"  -- XOR r2, r3
                            );

begin

  process(clk)
  begin
    if(rising_edge(clk)) then
      q <= rom(addr mod 8);
    end if;
  end process;

end rtl;
