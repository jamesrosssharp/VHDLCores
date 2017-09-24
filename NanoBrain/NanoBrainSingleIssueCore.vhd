--
--      NanoBrain: 16-bit RISC core
--
--      Single-issue core top level
--
--      Embeds i-cache, d-cache, integer processing unit,
--      barrel shifter, floating point unit, flow control unit,
--      io unit in a single core, instantiated by the top-level.
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.NanoBrainInternal.all;
use work.Cache.all;

entity NanoBrainSingleIssueCore is
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
    clk   : in std_logic;
    reset : in std_logic;

    -- instruction memory interface
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

    -- data memory interface
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

    -- interrupt line
    interrupt : in std_logic
    );
end NanoBrainSingleIssueCore;

architecture RTL of NanoBrainSingleIssueCore is

  component NanoBrainSingleIssueInstructionPipeline
    port (
      clk   : in std_logic;
      reset : in std_logic;

    icache_wr_data_a       : out  std_logic_vector (15 downto 0);
    icache_rd_data_a       : in std_logic_vector (15 downto 0);
    icache_data_sel_a      : out  std_logic;
    icache_rd_req_a        : out  std_logic;
    icache_wr_req_a        : out  std_logic;
    icache_flush_req       : out  std_logic;
    icache_invalidate_req  : out  std_logic;
    icache_wr_data_b       : out  std_logic_vector (15 downto 0);
    icache_rd_data_b       : in std_logic_vector (15 downto 0);
    icache_data_sel_b      : out  std_logic;
    icache_rd_req_b        : out  std_logic;
    icache_wr_req_b        : out  std_logic;
    icache_bypass          : out  std_logic;
    icache_rd_ready_a      : in std_logic;
    icache_wr_ready_a      : in std_logic;
    icache_rd_ready_b      : in std_logic;
    icache_wr_ready_b      : in std_logic;
    icache_flush_done      : in std_logic;
    icache_invalidate_done : in std_logic;
    icache_address_a       : out  unsigned (23 downto 0);
    icache_address_b       : out  unsigned (23 downto 0);

    -- dcache

    dcache_wr_data_a       : out  std_logic_vector (15 downto 0);
    dcache_rd_data_a       : in std_logic_vector (15 downto 0);
    dcache_data_sel_a      : out  std_logic;
    dcache_rd_req_a        : out std_logic;
    dcache_wr_req_a        : out  std_logic;
    dcache_flush_req       : out  std_logic;
    dcache_invalidate_req  : out  std_logic;
    dcache_wr_data_b       : out  std_logic_vector (15 downto 0);
    dcache_rd_data_b       : in std_logic_vector (15 downto 0);
    dcache_data_sel_b      : out  std_logic;
    dcache_rd_req_b        : out  std_logic;
    dcache_wr_req_b        : out  std_logic;
    dcache_bypass          : out  std_logic;
    dcache_rd_ready_a      : in std_logic;
    dcache_wr_ready_a      : in std_logic;
    dcache_rd_ready_b      : in std_logic;
    dcache_wr_ready_b      : in std_logic;
    dcache_flush_done      : in std_logic;
    dcache_invalidate_done : in std_logic;
    dcache_address_a       : out unsigned (23 downto 0);
    dcache_address_b       : out unsigned (23 downto 0);

    -- connection to IPU
    ipu_operand_x : out std_logic_vector(15 downto 0);
    ipu_operand_y : out std_logic_vector(15 downto 0);
    ipu_operand_z : out std_logic_vector(15 downto 0);
    ipu_result_lo : in  std_logic_vector(15 downto 0);
    ipu_result_hi : in  std_logic_vector(15 downto 0);
    ipu_C_in      : out std_logic;
    ipu_C_out     : in  std_logic;
	 ipu_Z_in      : out std_logic;
    ipu_Z_out     : in  std_logic;
    ipu_busy      : in  std_logic;
    ipu_op        : out IPU_Op;

    -- connection to FPU
    fpu_operand_x : out std_logic_vector(31 downto 0);
    fpu_operand_y : out std_logic_vector(31 downto 0);
    fpu_result    : in  std_logic_vector(31 downto 0);
    fpu_C_out     : in  std_logic;
    fpu_Z_out     : in  std_logic;
    -- when '1', FPU is busy with an operation. Pipeline must stall until it
    -- completes.
    fpu_busy      : in  std_logic;
    fpu_op        : out FPU_Op;

    -- connection to BS
    bs_operand_x : out std_logic_vector(15 downto 0);
    bs_shift     : out std_logic_vector(3 downto 0);
    bs_result    : in  std_logic_vector(15 downto 0);
    bs_C_in      : out std_logic;
    bs_C_out     : in  std_logic;
    bs_op        : out BS_Op
      );
  end component;

  component NanoBrainIntegerProcessingUnit
    generic (
      USE_MUL : integer;
      USE_DIV : integer
      );
    port (
      -- 16 bit operand x
      operand_x : in  std_logic_vector(15 downto 0);
      -- 16 bit operand y
      operand_y : in  std_logic_vector(15 downto 0);
      -- 16 bit operand z (for e.g. div -> z:x / y) 
      operand_z : in  std_logic_vector(15 downto 0);
      -- 16 bit result low word 
      result_lo : out std_logic_vector(15 downto 0);
      -- 16 bit result high word
      result_hi : out std_logic_vector(15 downto 0);
      -- carry in
      C_in      : in  std_logic;
      -- carry out
      C_out     : out std_logic;
      -- Zero in
      Z_in      : in std_logic;
      -- zero out
      Z_out     : out std_logic;
      -- we will stall the pipeline eg. on a division instruction while it completes.
      busy      : out std_logic;
      -- operation
      op        : in  IPU_Op
      );
  end component;

  component NanoBrainFloatingPointUnit
    port (
      operand_x : in  std_logic_vector(31 downto 0);
      operand_y : in  std_logic_vector(31 downto 0);
      result    : out std_logic_vector(31 downto 0);
      C_out     : out std_logic;
      Z_out     : out std_logic;
      -- when '1', FPU is busy with an operation. Pipeline must stall until it
      -- completes.
      busy      : out std_logic;
      op        : in  FPU_Op
      );
  end component;

  component NanoBrainBarrelShifter
    port (
      operand_x : in  std_logic_vector(15 downto 0);
      shift     : in  std_logic_vector(3 downto 0);
      result    : out std_logic_vector(15 downto 0);
      C_in      : in  std_logic;
      C_out     : out std_logic;
      op        :     BS_Op
      );
  end component;

  signal icache_wr_data_a       : std_logic_vector(15 downto 0);
  signal icache_rd_data_a       : std_logic_vector(15 downto 0);
  signal icache_data_sel_a      : std_logic;
  signal icache_rd_req_a        : std_logic;
  signal icache_wr_req_a        : std_logic;
  signal icache_flush_req       : std_logic;
  signal icache_invalidate_req  : std_logic;
  signal icache_wr_data_b       : std_logic_vector (15 downto 0);
  signal icache_rd_data_b       : std_logic_vector (15 downto 0);
  signal icache_data_sel_b      : std_logic;
  signal icache_rd_req_b        : std_logic;
  signal icache_wr_req_b        : std_logic;
  signal icache_bypass          : std_logic;
  signal icache_rd_ready_a      : std_logic;
  signal icache_wr_ready_a      : std_logic;
  signal icache_rd_ready_b      : std_logic;
  signal icache_wr_ready_b      : std_logic;
  signal icache_flush_done      : std_logic;
  signal icache_invalidate_done : std_logic;
  signal icache_address_a       : unsigned (23 downto 0);
  signal icache_address_b       : unsigned (23 downto 0);

  signal dcache_wr_data_a       : std_logic_vector (15 downto 0);
  signal dcache_rd_data_a       : std_logic_vector (15 downto 0);
  signal dcache_data_sel_a      : std_logic;
  signal dcache_rd_req_a        : std_logic;
  signal dcache_wr_req_a        : std_logic;
  signal dcache_flush_req       : std_logic;
  signal dcache_invalidate_req  : std_logic;
  signal dcache_wr_data_b       : std_logic_vector (15 downto 0);
  signal dcache_rd_data_b       : std_logic_vector (15 downto 0);
  signal dcache_data_sel_b      : std_logic;
  signal dcache_rd_req_b        : std_logic;
  signal dcache_wr_req_b        : std_logic;
  signal dcache_bypass          : std_logic;
  signal dcache_rd_ready_a      : std_logic;
  signal dcache_wr_ready_a      : std_logic;
  signal dcache_rd_ready_b      : std_logic;
  signal dcache_wr_ready_b      : std_logic;
  signal dcache_flush_done      : std_logic;
  signal dcache_invalidate_done : std_logic;
  signal dcache_address_a       : unsigned (23 downto 0);
  signal dcache_address_b       : unsigned (23 downto 0);

  signal ipu_operand_x : std_logic_vector(15 downto 0);
  signal ipu_operand_y : std_logic_vector(15 downto 0);
  signal ipu_operand_z : std_logic_vector(15 downto 0);
  signal ipu_result_lo : std_logic_vector(15 downto 0);
  signal ipu_result_hi : std_logic_vector(15 downto 0);
  signal ipu_C_in      : std_logic;
  signal ipu_C_out     : std_logic;
  signal ipu_Z_in      : std_logic;
  signal ipu_Z_out     : std_logic;
  signal ipu_busy      : std_logic;
  signal ipu_op        : IPU_Op;

  signal fpu_operand_x : std_logic_vector(31 downto 0) := (others => '0');
  signal fpu_operand_y : std_logic_vector(31 downto 0) := (others => '0');
  signal fpu_result    : std_logic_vector(31 downto 0) := (others => '0');
  signal fpu_C_out     : std_logic                     := '0';
  signal fpu_Z_out     : std_logic                     := '0';

  signal fpu_busy : std_logic := '0';
  signal fpu_op   : FPU_Op    := FPUOP_NOP;

  signal bs_operand_x : std_logic_vector(15 downto 0) := (others => '0');
  signal bs_shift     : std_logic_vector(3 downto 0)  := (others => '0');
  signal bs_result    : std_logic_vector(15 downto 0) := (others => '0');
  signal bs_C_in      : std_logic                     := '0';
  signal bs_C_out     : std_logic                     := '0';
  signal bs_op        : BS_Op                         := BSOP_NOP;

begin

  pipe0 : NanoBrainSingleIssueInstructionPipeline
    port map (
      clk                    => clk,
      reset                  => reset,
      icache_wr_data_a       => icache_wr_data_a,
      icache_rd_data_a       => icache_rd_data_a,
      icache_data_sel_a      => icache_data_sel_a,
      icache_rd_req_a        => icache_rd_req_a,
      icache_wr_req_a        => icache_wr_req_a,
      icache_flush_req       => icache_flush_req,
      icache_invalidate_req  => icache_invalidate_req,
      icache_wr_data_b       => icache_wr_data_b,
      icache_rd_data_b       => icache_rd_data_b,
      icache_data_sel_b      => icache_data_sel_b,
      icache_rd_req_b        => icache_rd_req_b,
      icache_wr_req_b        => icache_wr_req_b,
      icache_bypass          => icache_bypass,
      icache_rd_ready_a      => icache_rd_ready_a,
      icache_wr_ready_a      => icache_wr_ready_a,
      icache_rd_ready_b      => icache_rd_ready_b,
      icache_wr_ready_b      => icache_wr_ready_b,
      icache_flush_done      => icache_flush_done,
      icache_invalidate_done => icache_invalidate_done,
      icache_address_a       => icache_address_a,
      icache_address_b       => icache_address_b,
      dcache_wr_data_a       => dcache_wr_data_a,
      dcache_rd_data_a       => dcache_rd_data_a,
      dcache_data_sel_a      => dcache_data_sel_a,
      dcache_rd_req_a        => dcache_rd_req_a,
      dcache_wr_req_a        => dcache_wr_req_a,
      dcache_flush_req       => dcache_flush_req,
      dcache_invalidate_req  => dcache_invalidate_req,
      dcache_wr_data_b       => dcache_wr_data_b,
      dcache_rd_data_b       => dcache_rd_data_b,
      dcache_data_sel_b      => dcache_data_sel_b,
      dcache_rd_req_b        => dcache_rd_req_b,
      dcache_wr_req_b        => dcache_wr_req_b,
      dcache_bypass          => dcache_bypass,
      dcache_rd_ready_a      => dcache_rd_ready_a,
      dcache_wr_ready_a      => dcache_wr_ready_a,
      dcache_rd_ready_b      => dcache_rd_ready_b,
      dcache_wr_ready_b      => dcache_wr_ready_b,
      dcache_flush_done      => dcache_flush_done,
      dcache_invalidate_done => dcache_invalidate_done,
      dcache_address_a       => dcache_address_a,
      dcache_address_b       => dcache_address_b,
      ipu_operand_x          => ipu_operand_x,
      ipu_operand_y          => ipu_operand_y,
      ipu_operand_z          => ipu_operand_z,
      ipu_result_lo          => ipu_result_lo,
      ipu_result_hi          => ipu_result_hi,
      ipu_C_in               => ipu_C_in,
      ipu_C_out              => ipu_C_out,
      ipu_Z_out              => ipu_Z_out,
      ipu_busy               => ipu_busy,
      ipu_op                 => ipu_op,
      fpu_operand_x          => fpu_operand_x,
      fpu_operand_y          => fpu_operand_y,
      fpu_result             => fpu_result,
      fpu_C_out              => fpu_C_out,
      fpu_Z_out              => fpu_Z_out,
      fpu_busy               => fpu_busy,
      fpu_op                 => fpu_op,
      bs_operand_x           => bs_operand_x,
      bs_shift               => bs_shift,
      bs_result              => bs_result,
      bs_C_in                => bs_C_in,
      bs_C_out               => bs_C_out,
      bs_op                  => bs_op
      );

  ipu0 : NanoBrainIntegerProcessingUnit
    generic map (
      USE_MUL => USE_MUL,
      USE_DIV => USE_DIV
      )
    port map (
      operand_x => ipu_operand_x,
      operand_y => ipu_operand_y,
      operand_z => ipu_operand_z,
      result_lo => ipu_result_lo,
      result_hi => ipu_result_hi,
      C_in      => ipu_C_in,
      C_out     => ipu_C_out,
      Z_in      => ipu_Z_in,
      Z_out     => ipu_Z_out,
      busy      => ipu_busy,
      op        => ipu_op
      );

  fpu : if USE_FPU /= 0 generate
    fpu0 : NanoBrainFloatingPointUnit port map (
      operand_x => fpu_operand_x,
      operand_y => fpu_operand_y,
      result    => fpu_result,
      C_out     => fpu_C_out,
      Z_out     => fpu_Z_out,
      busy      => fpu_busy,
      op        => fpu_op
      );
  end generate fpu;

  bs : if USE_BS /= 0 generate
    bs0 : NanoBrainBarrelShifter
      port map (
        operand_x => bs_operand_x,
        shift     => bs_shift,
        result    => bs_result,
        C_in      => bs_C_in,
        C_out     => bs_C_out,
        op        => bs_op
        );
  end generate bs;

  icache0 : DualPortBlockRamCache
    generic map (
      WORD_WIDTH_BITS       => 4,
      BYTE_WIDTH_BITS       => 3,
      ADDRESS_WIDTH         => 24,
      CACHE_LINE_WIDTH_BITS => ICACHE_WIDTH_BITS,
      CACHE_LINE_NUM_BITS   => ICACHE_NUM_LINES_BITS
      )
    port map (
      clk             => clk,
      reset           => reset,
      wr_data_a       => icache_wr_data_a,
      rd_data_a       => icache_rd_data_a,
      data_sel_a      => icache_data_sel_a,
      rd_req_a        => icache_rd_req_a,
      wr_req_a        => icache_wr_req_a,
      flush_req       => icache_flush_req,
      invalidate_req  => icache_invalidate_req,
      wr_data_b       => icache_wr_data_b,
      rd_data_b       => icache_rd_data_b,
      data_sel_b      => icache_data_sel_b,
      rd_req_b        => icache_rd_req_b,
      wr_req_b        => icache_wr_req_b,
      bypass          => icache_bypass,
      rd_ready_a      => icache_rd_ready_a,
      wr_ready_a      => icache_wr_ready_a,
      rd_ready_b      => icache_rd_ready_b,
      wr_ready_b      => icache_wr_ready_b,
      flush_done      => icache_flush_done,
      invalidate_done => icache_invalidate_done,
      address_a       => icache_address_a,
      address_b       => icache_address_b,
      address_ds      => i_address,
      wr_data_ds      => i_wr_data,
      rd_data_ds      => i_rd_data,
      burst_size_ds   => i_burst_size,
      wr_req_ds       => i_wr_req,
      rd_req_ds       => i_rd_req,
      wr_grant_ds     => i_wr_grant,
      rd_grant_ds     => i_rd_grant,
      wr_done_ds      => i_wr_done,
      n_rd_ds         => i_n_rd,
      n_wr_ds         => i_n_wr
      );


  dcache0 : DualPortBlockRamCache
    generic map (
      WORD_WIDTH_BITS       => 4,
      BYTE_WIDTH_BITS       => 3,
      ADDRESS_WIDTH         => 24,
      CACHE_LINE_WIDTH_BITS => DCACHE_WIDTH_BITS,
      CACHE_LINE_NUM_BITS   => DCACHE_NUM_LINES_BITS
      )
    port map (
      clk             => clk,
      reset           => reset,
      wr_data_a       => dcache_wr_data_a,
      rd_data_a       => dcache_rd_data_a,
      data_sel_a      => dcache_data_sel_a,
      rd_req_a        => dcache_rd_req_a,
      wr_req_a        => dcache_wr_req_a,
      flush_req       => dcache_flush_req,
      invalidate_req  => dcache_invalidate_req,
      wr_data_b       => dcache_wr_data_b,
      rd_data_b       => dcache_rd_data_b,
      data_sel_b      => dcache_data_sel_b,
      rd_req_b        => dcache_rd_req_b,
      wr_req_b        => dcache_wr_req_b,
      bypass          => dcache_bypass,
      rd_ready_a      => dcache_rd_ready_a,
      wr_ready_a      => dcache_wr_ready_a,
      rd_ready_b      => dcache_rd_ready_b,
      wr_ready_b      => dcache_wr_ready_b,
      flush_done      => dcache_flush_done,
      invalidate_done => dcache_invalidate_done,
      address_a       => dcache_address_a,
      address_b       => dcache_address_b,
      address_ds      => d_address,
      wr_data_ds      => d_wr_data,
      rd_data_ds      => d_rd_data,
      burst_size_ds   => d_burst_size,
      wr_req_ds       => d_wr_req,
      rd_req_ds       => d_rd_req,
      wr_grant_ds     => d_wr_grant,
      rd_grant_ds     => d_rd_grant,
      wr_done_ds      => d_wr_done,
      n_rd_ds         => d_n_rd,
      n_wr_ds         => d_n_wr
      );

end RTL;
