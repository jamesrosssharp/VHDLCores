--
--      NanoBrainCPU: 16-bit RISC core
--
--              Package
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package NanoBrainCPU is

  component NanoBrain is
    generic (
      -- cache config
      DCACHE_NUM_LINES_BITS : integer := 4;
      DCACHE_WIDTH_BITS     : integer := 3;

      ICACHE_NUM_LINES_BITS : integer := 9;
      ICACHE_WIDTH_BITS     : integer := 3;

      -- FPU

      -- if non zero, build in FPU support
      USE_FPU : integer := 0;

      -- Barrel shift

      -- if non zero, build in barrel shifter support
      USE_BS : integer := 0;

      -- Multiply / divide

      USE_MUL : integer := 0;
      USE_DIV : integer := 0;

      -- MMU

      USE_MMU : integer := 0;

      -- Instruction sequencing

      -- if non-zero, use dual instruction pipelines
      DUAL_ISSUE : integer := 0

      );
    port (

      clk   : in std_logic;
      reset : in std_logic;

      -- instruction memory

      i_address    : out unsigned (23 downto 0);
      i_wr_data    : out std_logic_vector (15 downto 0);
      i_rd_data    : in  std_logic_vector (15 downto 0);
      i_burst_size : out std_logic_vector(3 downto 0);
      i_wr_req     : out std_logic;
      i_rd_req     : out std_logic;
      i_wr_grant   : in  std_logic;
      i_rd_grant   : in  std_logic;
      i_wr_done    : in  std_logic;
      i_n_rd       : out std_logic;
      i_n_wr       : out std_logic;

      -- data memory

      d_address    : out unsigned (23 downto 0);
      d_wr_data    : out std_logic_vector (15 downto 0);
      d_rd_data    : in  std_logic_vector (15 downto 0);
      d_burst_size : out std_logic_vector(3 downto 0);
      d_wr_req     : out std_logic;
      d_rd_req     : out std_logic;
      d_wr_grant   : in  std_logic;
      d_rd_grant   : in  std_logic;
      d_wr_done    : in  std_logic;
      d_n_rd       : out std_logic;
      d_n_wr       : out std_logic;

      -- port bus connection

      port_address : out std_logic_vector(15 downto 0);
      port_wr_data : out std_logic_vector(15 downto 0);
      port_rd_data : in  std_logic_vector(15 downto 0);
      port_n_rd    : out std_logic;
      port_n_wr    : out std_logic;

      -- interrupt

      interrupt : in std_logic

      );
  end component;

end NanoBrainCPU;
