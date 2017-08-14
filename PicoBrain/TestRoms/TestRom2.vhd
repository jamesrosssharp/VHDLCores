-- Quartus II VHDL Template
-- Single-Port ROM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_rom_2 is

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

architecture rtl of test_rom_2 is

  -- Build a 2-D array type for the RoM
  subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
  type memory_t is array(1 downto 0) of word_t;

  -- Declare the ROM signal and specify a default value.        Quartus II
  -- will create a memory initialization file (.mif) based on the 
  -- default value.
  signal rom : memory_t := ( 0 => "000000000001000001", -- LOAD r0, 0x41
			     1 => "101100000000000000" -- OUTPUT r0, 0
		            );

begin

  process(clk)
  begin
    if(rising_edge(clk)) then
      q <= rom(addr mod 2);
    end if;
  end process;

end rtl;
