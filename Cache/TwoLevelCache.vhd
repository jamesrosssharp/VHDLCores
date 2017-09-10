--
--      TwoLevelCache - top level for L1 and L2 caches, with bypass so caching
--      can be disabled.
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity TwoLevelCache is
  generic (
    WORD_WIDTH             : natural := 16;  -- width of data, e.g 16 bit word
    BYTE_WIDTH             : natural := 8;  -- width of a byte
    ADDRESS_WIDTH          : natural := 24;  -- width of address bus
    CACHE_LINE_WIDTH_BITS  : natural := 3;  -- number of bits used to represent
                                            -- cache line size in units of
                                            -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                            -- 8 bytes
    L2_CACHE_LINE_NUM_BITS : natural := 9;  -- E.g. 2**9 = 512 cache lines in
                                            -- L2 cache.
    L1_CACHE_LINE_NUM_BITS : natural := 2   -- E.g 2**2 = 4 cache lines in L1
                                            -- cache.
    );
  port (

    clk   : in std_logic;
    reset : in std_logic;

    wr_data  : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data  : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    data_sel : in  std_logic;           -- '1', address word (address must be
    -- aligned), '0' address byte

    rd_req         : in std_logic;
    wr_req         : in std_logic;
    flush_req      : in std_logic;  -- flush a single cache line that contains address
    invalidate_req : in std_logic;      -- invalidate entire cache.
    bypass         : in std_logic;      -- if '1' cache is bypassed, and L1/L2
    -- caches will be held in reset. If
    -- '0', cache is active and cache
    -- bypass logic will be held in reset.

    rd_ready        : out std_logic;    -- '1' if cache hit
    wr_ready        : out std_logic;    -- '1' when data will be written to
    -- cache on next rising edge of clock
    flush_done      : out std_logic;
    invalidate_done : out std_logic;

    address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

    -- connection to downstream memory controller

    address_ds    : out unsigned (ADDRESS_WIDTH - 2 downto 0);
    wr_data_ds    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_ds    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_ds : out std_logic_vector(3 downto 0);  -- 1, 2, 4, 8 word bursts
                                        -- to downstream memory controller
    wr_req_ds     : out std_logic;  -- request to write from L2 to memory controller
    rd_req_ds     : out std_logic;  -- request to read from L2 to memory controller
    wr_grant_ds   : in  std_logic;      -- request to write granted by memory
    -- controller, so words can now be written
    -- to memory controller
    rd_grant_ds   : in  std_logic;      -- request to read granted by memory
    -- controller, and words are ready to be read
    wr_done_ds    : in  std_logic;  -- write cycle completed by memory controller
    n_rd_ds       : out std_logic;      -- write a word to memory controller
    n_wr_ds       : out std_logic       -- read a word from memory controller

    );
end TwoLevelCache;

architecture RTL of TwoLevelCache is

  -- L1 cache

  component L1Cache is
    generic (
      WORD_WIDTH            : natural := 16;
      BYTE_WIDTH            : natural := 8;
      CACHE_LINE_WIDTH_BITS : natural := 2;
      CACHE_LINE_NUM_BITS   : natural := 1;
      ADDRESS_WIDTH         : natural := 24
      );
    port (
      clk           : in  std_logic;
      reset         : in  std_logic;
      wr_data       : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data       : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      data_sel      : in  std_logic;
      rd_req        : in  std_logic;
      wr_req        : in  std_logic;
      flush_req     : in  std_logic;
      rd_ready      : out std_logic;
      wr_ready      : out std_logic;
      flush_done    : out std_logic;
      address       : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_ds    : out unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_ds    : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);
      rd_data_ds    : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);
      wr_ready_ds   : in  std_logic;
      rd_ready_ds   : in  std_logic;
      flush_done_ds : in  std_logic;
      flush_req_ds  : out std_logic;
      wr_req_ds     : out std_logic;
      rd_req_ds     : out std_logic
      );
  end component;

  -- L2 cache

  component L2Cache is
    generic (
      WORD_WIDTH            : natural := 16;
      BYTE_WIDTH            : natural := 8;
      CACHE_LINE_WIDTH_BITS : natural := 3;
      CACHE_LINE_NUM_BITS   : natural := 9;
      ADDRESS_WIDTH         : natural := 24
      );
    port (
      clk           : in  std_logic;
      reset         : in  std_logic;
      busy          : out std_logic;
      wr_data       : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);
      rd_data       : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);
      rd_req        : in  std_logic;
      wr_req        : in  std_logic;
      flush_req     : in  std_logic;
      rd_ready      : out std_logic;
      wr_ready      : out std_logic;
      flush_done    : out std_logic;
      address       : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_ds    : out unsigned (ADDRESS_WIDTH - 2 downto 0);
      wr_data_ds    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_ds    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
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

  -- Cache bypass

  component CacheBypass is
    generic (
      WORD_WIDTH    : natural := 16;    -- width of data, e.g 16 bit word
      BYTE_WIDTH    : natural := 8;     -- width of a byte
      ADDRESS_WIDTH : natural := 24     -- width of address bus
      );
    port (
      clk           : in  std_logic;
      reset         : in  std_logic;
      wr_data       : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data       : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      data_sel      : in  std_logic;
      rd_req        : in  std_logic;
      wr_req        : in  std_logic;
      rd_ready      : out std_logic;
      wr_ready      : out std_logic;
      address       : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_ds    : out unsigned (ADDRESS_WIDTH - 2 downto 0);
      wr_data_ds    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_ds    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
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

  -- L1 cache signals

  signal l1_rd_data       : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal l1_reset         : std_logic;
  signal l1_rd_ready      : std_logic;
  signal l1_wr_ready      : std_logic;
  signal l1_flush_done    : std_logic;
  signal l1_address_ds    : unsigned (ADDRESS_WIDTH - 1 downto 0);
  signal l1_wr_data_ds    : std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);
  signal l1_rd_data_ds    : std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);
  signal l1_wr_ready_ds   : std_logic;
  signal l1_rd_ready_ds   : std_logic;
  signal l1_flush_done_ds : std_logic;
  signal l1_flush_req_ds  : std_logic;
  signal l1_wr_req_ds     : std_logic;
  signal l1_rd_req_ds     : std_logic;

  -- L2 cache signals

  signal l2_reset         : std_logic;
  signal l2_address_ds    : unsigned (ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH downto 0);
  signal l2_wr_data_ds    : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal l2_burst_size_ds : std_logic_vector (3 downto 0);
  signal l2_wr_req_ds     : std_logic;
  signal l2_rd_req_ds     : std_logic;
  signal l2_n_rd_ds       : std_logic;
  signal l2_n_wr_ds       : std_logic;

  -- Cache bypass signals

  signal cbp_reset         : std_logic;
  signal cbp_rd_data			: std_logic_vector(WORD_WIDTH - 1 downto 0);
  signal cbp_rd_ready      : std_logic;
  signal cbp_wr_ready      : std_logic;
  signal cbp_address_ds    : unsigned (ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH downto 0);
  signal cbp_wr_data_ds    : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal cbp_burst_size_ds : std_logic_vector (3 downto 0);
  signal cbp_wr_req_ds     : std_logic;
  signal cbp_rd_req_ds     : std_logic;
  signal cbp_n_rd_ds       : std_logic;
  signal cbp_n_wr_ds       : std_logic;

begin

  -- L1 cache instance

  l1_0 : L1Cache
    generic map (
      WORD_WIDTH            => WORD_WIDTH,
      BYTE_WIDTH            => BYTE_WIDTH,
      CACHE_LINE_WIDTH_BITS => CACHE_LINE_WIDTH_BITS,
      CACHE_LINE_NUM_BITS   => L1_CACHE_LINE_NUM_BITS,
      ADDRESS_WIDTH         => ADDRESS_WIDTH
      )
    port map (
      clk           => clk,
      reset         => l1_reset,
      wr_data       => wr_data,
      rd_data       => l1_rd_data,
      data_sel      => data_sel,
      rd_req        => rd_req,
      wr_req        => wr_req,
      flush_req     => flush_req,
      rd_ready      => l1_rd_ready,
      wr_ready      => l1_wr_ready,
      flush_done    => l1_flush_done,
      address       => address,
      address_ds    => l1_address_ds,
      wr_data_ds    => l1_wr_data_ds,
      rd_data_ds    => l1_rd_data_ds,
      wr_ready_ds   => l1_wr_ready_ds,
      rd_ready_ds   => l1_rd_ready_ds,
      flush_done_ds => l1_flush_done_ds,
      flush_req_ds  => l1_flush_req_ds,
      wr_req_ds     => l1_wr_req_ds,
      rd_req_ds     => l1_rd_req_ds
      );

-- L2 cache instance

  l2_0 : L2Cache
    generic map (
      WORD_WIDTH            => WORD_WIDTH,
      BYTE_WIDTH            => BYTE_WIDTH,
      CACHE_LINE_WIDTH_BITS => CACHE_LINE_WIDTH_BITS,
      CACHE_LINE_NUM_BITS   => L2_CACHE_LINE_NUM_BITS,
      ADDRESS_WIDTH         => ADDRESS_WIDTH
      )
    port map (
      clk           => clk,
      reset         => l2_reset,
      busy          => open,
      wr_data       => l1_wr_data_ds,
      rd_data       => l1_rd_data_ds,
      rd_req        => l1_rd_req_ds,
      wr_req        => l1_wr_req_ds,
      flush_req     => l1_flush_req_ds,
      rd_ready      => l1_rd_ready_ds,
      wr_ready      => l1_wr_ready_ds,
      flush_done    => l1_flush_done_ds,
      address       => l1_address_ds,
      address_ds    => l2_address_ds,
      wr_data_ds    => l2_wr_data_ds,
      rd_data_ds    => rd_data_ds,
      burst_size_ds => l2_burst_size_ds,
      wr_req_ds     => l2_wr_req_ds,
      rd_req_ds     => l2_rd_req_ds,
      wr_grant_ds   => wr_grant_ds,
      rd_grant_ds   => rd_grant_ds,
      wr_done_ds    => wr_done_ds,
      n_rd_ds       => l2_n_rd_ds,
      n_wr_ds       => l2_n_wr_ds
      );

-- cache bypass instance

  cbp_0 : CacheBypass
    generic map (
      WORD_WIDTH    => WORD_WIDTH,
      BYTE_WIDTH    => BYTE_WIDTH,
      ADDRESS_WIDTH => ADDRESS_WIDTH
      )
    port map (
      clk           => clk,
      reset         => cbp_reset,
      wr_data       => wr_data,
      rd_data       => cbp_rd_data,
      data_sel      => data_sel,
      rd_req        => rd_req,
      wr_req        => wr_req,
      rd_ready      => cbp_rd_ready,
      wr_ready      => cbp_wr_ready,
      address       => address,
      address_ds    => cbp_address_ds,
      wr_data_ds    => cbp_wr_data_ds,
      rd_data_ds    => rd_data_ds,
      burst_size_ds => cbp_burst_size_ds,
      wr_req_ds     => cbp_wr_req_ds,
      rd_req_ds     => cbp_rd_req_ds,
      wr_grant_ds   => wr_grant_ds,
      rd_grant_ds   => rd_grant_ds,
      wr_done_ds    => wr_done_ds,
      n_rd_ds       => cbp_n_rd_ds,
      n_wr_ds       => cbp_n_wr_ds
      );


-- L1 cache reset logic

l1_reset <= '1' when reset = '1' or bypass = '1' else '0';

-- L2 cache reset logic

l2_reset <= l1_reset;

-- Cache bypass reset logic

cbp_reset <= '1' when reset = '1' or bypass = '0' else '0';

-- mux output to memory controller

wr_data_ds <= l2_wr_data_ds when bypass = '0' else cbp_wr_data_ds;
address_ds <= l2_address_ds when bypass = '0' else cbp_address_ds;

wr_req_ds   <= l2_wr_req_ds   when bypass = '0' else cbp_wr_req_ds;
rd_req_ds   <= l2_rd_req_ds   when bypass = '0' else cbp_rd_req_ds;
n_rd_ds     <= l2_n_rd_ds     when bypass = '0' else cbp_n_rd_ds;
n_wr_ds     <= l2_n_wr_ds     when bypass = '0' else cbp_n_wr_ds;

-- mux control signals

rd_ready   <= l1_rd_ready when bypass = '0' else cbp_rd_ready;
wr_ready   <= l1_wr_ready when bypass = '0' else cbp_wr_ready;
flush_done <= l1_flush_done;
rd_data    <= l1_rd_data when bypass = '0' else cbp_rd_data;

--TODO: invalidate  


end RTL;


