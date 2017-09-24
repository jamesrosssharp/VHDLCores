--
--
--      Cache package
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package Cache is

  component DualPortBlockRamCache is
    generic (
      WORD_WIDTH_BITS       : natural := 4; 
      BYTE_WIDTH_BITS       : natural := 3; 
      ADDRESS_WIDTH         : natural := 24;
      CACHE_LINE_WIDTH_BITS : natural := 3; 
      CACHE_LINE_NUM_BITS   : natural := 9  
      );
    port (

      clk   : in std_logic;
      reset : in std_logic;

      wr_data_a  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_a  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      data_sel_a : in  std_logic;  
      rd_req_a       : in std_logic;
      wr_req_a       : in std_logic;
      flush_req      : in std_logic; 
      invalidate_req : in std_logic; 
      wr_data_b  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_b  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      data_sel_b : in  std_logic;    
      rd_req_b : in std_logic;
      wr_req_b : in std_logic;
      bypass : in std_logic;  
      rd_ready_a : out std_logic;   
      wr_ready_a : out std_logic;   
      rd_ready_b : out std_logic;   
      wr_ready_b : out std_logic;   
      flush_done      : out std_logic;
      invalidate_done : out std_logic;
      address_a : in unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_b : in unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_ds    : out unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_ds    : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_ds    : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      burst_size_ds : out std_logic_vector(3 downto 0);  
      wr_req_ds     : out std_logic;
      rd_req_ds     : out std_logic;
      wr_grant_ds   : in  std_logic;  
      rd_grant_ds   : in  std_logic;   
      wr_done_ds    : in  std_logic;  
      n_rd_ds       : out std_logic;  
      n_wr_ds       : out std_logic   
      );
  end component;

end Cache;
