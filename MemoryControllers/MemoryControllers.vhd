--
--
--      MemoryControllers package
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package MemoryControllers is

  component BlockRamMemoryController is
    generic (
      ADDRESS_WIDTH    : natural := 12;  -- 4096 word memory
      BR_ADDRESS_WIDTH : natural := 4;   -- 16 word memory
      WORD_WIDTH       : natural := 16;
      BURST_SIZE_BITS  : natural := 4
      );
    port (
      clk   : in std_logic;
      reset : in std_logic;

      address    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      -- burst size is number of words to read - 1, e.g. 1111 = 15 = 16 words
      burst_size : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req     : in  std_logic;
      rd_req     : in  std_logic;
      wr_grant   : out std_logic;
      rd_grant   : out std_logic;
      wr_done    : out std_logic;
      n_rd       : in  std_logic;
      n_wr       : in  std_logic;

      br_address : out natural range 0 to 2**BR_ADDRESS_WIDTH - 1;
      br_wr_data : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      br_rd_data : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      br_wr      : out std_logic

      );
  end component;

  component EightPortMemoryController is
    generic (
      ADDRESS_WIDTH   : natural := 23;
      WORD_WIDTH      : natural := 16;
      BURST_SIZE_BITS : natural := 4
      );
    port (

      clk   : in std_logic;
      reset : in std_logic;

      address_1    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_1    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_1    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_1 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_1     : in  std_logic;
      rd_req_1     : in  std_logic;
      wr_grant_1   : out std_logic;
      rd_grant_1   : out std_logic;
      wr_done_1    : out std_logic;
      n_rd_1       : in  std_logic;
      n_wr_1       : in  std_logic;

      address_2    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_2    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_2    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_2 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_2     : in  std_logic;
      rd_req_2     : in  std_logic;
      wr_grant_2   : out std_logic;
      rd_grant_2   : out std_logic;
      wr_done_2    : out std_logic;
      n_rd_2       : in  std_logic;
      n_wr_2       : in  std_logic;

      address_3    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_3    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_3    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_3 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_3     : in  std_logic;
      rd_req_3     : in  std_logic;
      wr_grant_3   : out std_logic;
      rd_grant_3   : out std_logic;
      wr_done_3    : out std_logic;
      n_rd_3       : in  std_logic;
      n_wr_3       : in  std_logic;

      address_4    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_4    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_4    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_4 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_4     : in  std_logic;
      rd_req_4     : in  std_logic;
      wr_grant_4   : out std_logic;
      rd_grant_4   : out std_logic;
      wr_done_4    : out std_logic;
      n_rd_4       : in  std_logic;
      n_wr_4       : in  std_logic;

      address_5    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_5    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_5    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_5 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_5     : in  std_logic;
      rd_req_5     : in  std_logic;
      wr_grant_5   : out std_logic;
      rd_grant_5   : out std_logic;
      wr_done_5    : out std_logic;
      n_rd_5       : in  std_logic;
      n_wr_5       : in  std_logic;

      address_6    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_6    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_6    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_6 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_6     : in  std_logic;
      rd_req_6     : in  std_logic;
      wr_grant_6   : out std_logic;
      rd_grant_6   : out std_logic;
      wr_done_6    : out std_logic;
      n_rd_6       : in  std_logic;
      n_wr_6       : in  std_logic;

      address_7    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_7    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_7    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_7 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_7     : in  std_logic;
      rd_req_7     : in  std_logic;
      wr_grant_7   : out std_logic;
      rd_grant_7   : out std_logic;
      wr_done_7    : out std_logic;
      n_rd_7       : in  std_logic;
      n_wr_7       : in  std_logic;

      address_8    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_8    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_8    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_8 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      wr_req_8     : in  std_logic;
      rd_req_8     : in  std_logic;
      wr_grant_8   : out std_logic;
      rd_grant_8   : out std_logic;
      wr_done_8    : out std_logic;
      n_rd_8       : in  std_logic;
      n_wr_8       : in  std_logic;

      -- half address space mapped to ds port 1
      ds_address_1    : out unsigned (ADDRESS_WIDTH - 2 downto 0);
      ds_wr_data_1    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_rd_data_1    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_burst_size_1 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      ds_wr_req_1     : out std_logic;
      ds_rd_req_1     : out std_logic;
      ds_wr_grant_1   : in  std_logic;
      ds_rd_grant_1   : in  std_logic;
      ds_wr_done_1    : in  std_logic;
      ds_n_rd_1       : out std_logic;
      ds_n_wr_1       : out std_logic;

      -- one quarter address space mapped to each of ds ports 2 and 3
      ds_address_2    : out unsigned (ADDRESS_WIDTH - 3 downto 0);
      ds_wr_data_2    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_rd_data_2    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_burst_size_2 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      ds_wr_req_2     : out std_logic;
      ds_rd_req_2     : out std_logic;
      ds_wr_grant_2   : in  std_logic;
      ds_rd_grant_2   : in  std_logic;
      ds_wr_done_2    : in  std_logic;
      ds_n_rd_2       : out std_logic;
      ds_n_wr_2       : out std_logic;

      ds_address_3    : out unsigned (ADDRESS_WIDTH - 3 downto 0);
      ds_wr_data_3    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_rd_data_3    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      ds_burst_size_3 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
      ds_wr_req_3     : out std_logic;
      ds_rd_req_3     : out std_logic;
      ds_wr_grant_3   : in  std_logic;
      ds_rd_grant_3   : in  std_logic;
      ds_wr_done_3    : in  std_logic;
      ds_n_rd_3       : out std_logic;
      ds_n_wr_3       : out std_logic

      );
  end component;

end MemoryControllers;
