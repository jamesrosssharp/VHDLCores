--
--      IO Package
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package IO is

  component SixteenPortIOController is

  generic (
    ADDRESS_WIDTH : natural := 16;
    DATA_WIDTH    : natural := 16
    );
  port (
    port_address : in std_logic_vector (ADDRESS_WIDTH - 1 downto 0);
    port_wr_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    port_rd_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    port_n_rd    : in std_logic;
    port_n_wr    : in std_logic;

    ds_port_1_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_1_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_1_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_1_n_rd    : out std_logic;
    ds_port_1_n_wr    : out std_logic;

   ds_port_2_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_2_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_2_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_2_n_rd    : out std_logic;
    ds_port_2_n_wr    : out std_logic;

 ds_port_3_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_3_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_3_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_3_n_rd    : out std_logic;
    ds_port_3_n_wr    : out std_logic;

 ds_port_4_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_4_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_4_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_4_n_rd    : out std_logic;
    ds_port_4_n_wr    : out std_logic;

 ds_port_5_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_5_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_5_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_5_n_rd    : out std_logic;
    ds_port_5_n_wr    : out std_logic;

 ds_port_6_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_6_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_6_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_6_n_rd    : out std_logic;
    ds_port_6_n_wr    : out std_logic;

 ds_port_7_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_7_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_7_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_7_n_rd    : out std_logic;
    ds_port_7_n_wr    : out std_logic;

 ds_port_8_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_8_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_8_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_8_n_rd    : out std_logic;
    ds_port_8_n_wr    : out std_logic;

 ds_port_9_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_9_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_9_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_9_n_rd    : out std_logic;
    ds_port_9_n_wr    : out std_logic;

 ds_port_10_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_10_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_10_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_10_n_rd    : out std_logic;
    ds_port_10_n_wr    : out std_logic;

 ds_port_11_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_11_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_11_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_11_n_rd    : out std_logic;
    ds_port_11_n_wr    : out std_logic;

 ds_port_12_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_12_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_12_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_12_n_rd    : out std_logic;
    ds_port_12_n_wr    : out std_logic;

 ds_port_13_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_13_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_13_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_13_n_rd    : out std_logic;
    ds_port_13_n_wr    : out std_logic;

 ds_port_14_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_14_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_14_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_14_n_rd    : out std_logic;
    ds_port_14_n_wr    : out std_logic;

 ds_port_15_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_15_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_15_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_15_n_rd    : out std_logic;
    ds_port_15_n_wr    : out std_logic;

 ds_port_16_address : out std_logic_vector (ADDRESS_WIDTH - 5 downto 0);
    ds_port_16_wr_data : out std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_16_rd_data : in std_logic_vector (DATA_WIDTH - 1 downto 0);
    ds_port_16_n_rd    : out std_logic;
    ds_port_16_n_wr    : out std_logic

    );
end component;

  component DE1LedsAndSwitches is
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
      port_rd_data : in std_logic_vector(15 downto 0);
      port_n_wr    : in std_logic;
      port_n_rd    : in std_logic

      );
  end component;
end IO;
