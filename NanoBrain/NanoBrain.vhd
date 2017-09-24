--
--      NanoBrain: 16-bit RISC core
--
--              Top Level
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity NanoBrain is
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

    -- interrupt

    interrupt : in std_logic

    );
end NanoBrain;

architecture RTL of NanoBrain is

  component NanoBrainSingleIssueCore
    generic (
      DCACHE_NUM_LINES_BITS : integer;
      DCACHE_WIDTH_BITS     : integer;
      ICACHE_NUM_LINES_BITS : integer;
      ICACHE_WIDTH_BITS     : integer;
      USE_FPU               : integer;
      USE_BS                : integer;
      USE_MUL               : integer;
      USE_DIV               : integer;
      USE_MMU               : integer
      );
    port (
      clk          : in  std_logic;
      reset        : in  std_logic;
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
      interrupt    : in  std_logic
      );
  end component;

begin

  core0 : NanoBrainSingleIssueCore
    generic map (
      DCACHE_NUM_LINES_BITS => DCACHE_NUM_LINES_BITS,
      DCACHE_WIDTH_BITS     => DCACHE_WIDTH_BITS,
      ICACHE_NUM_LINES_BITS => ICACHE_NUM_LINES_BITS,
      ICACHE_WIDTH_BITS     => ICACHE_WIDTH_BITS,
      USE_FPU               => USE_FPU,
      USE_BS                => USE_BS,
      USE_MUL               => USE_MUL,
      USE_DIV               => USE_DIV,
      USE_MMU               => USE_MMU
      )
    port map (
      clk          => clk,
      reset        => reset,
      i_address    => i_address,
      i_wr_data    => i_wr_data,
      i_rd_data    => i_rd_data,
      i_burst_size => i_burst_size,
      i_wr_req     => i_wr_req,
      i_rd_req     => i_rd_req,
      i_wr_grant   => i_wr_grant,
      i_rd_grant   => i_rd_grant,
      i_wr_done    => i_wr_done,
      i_n_rd       => i_n_rd,
      i_n_wr       => i_n_wr,
      d_address    => d_address,
      d_wr_data    => d_wr_data,
      d_rd_data    => d_rd_data,
      d_burst_size => d_burst_size,
      d_wr_req     => d_wr_req,
      d_rd_req     => d_rd_req,
      d_wr_grant   => d_wr_grant,
      d_rd_grant   => d_rd_grant,
      d_wr_done    => d_wr_done,
      d_n_rd       => d_n_rd,
      d_n_wr       => d_n_wr,
      interrupt    => interrupt
      );

end RTL;
