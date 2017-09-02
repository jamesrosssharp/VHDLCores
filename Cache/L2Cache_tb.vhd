--
--      L2Cache_tb.vhd : test bench for L2 cache
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity L2Cache_tb is
end L2Cache_tb;

architecture RTL of L2Cache_tb is

  constant clk_period : time := 20 ns;

  component L2Cache is
    generic (
      WORD_WIDTH            : natural := 16;  -- width of data, e.g 16 bit word
      BYTE_WIDTH            : natural := 8;  -- width of a byte
      CACHE_LINE_WIDTH_BITS : natural := 3;  -- number of bits used to represent
                                             -- cache line size in units of
                                             -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                             -- 8 bytes
      CACHE_LINE_NUM_BITS   : natural := 9;  -- E.g. 2**9 = 512 cache lines in cache.
      ADDRESS_WIDTH         : natural := 14  -- width of address bus
      );
    port (

      clk   : in  std_logic;
      reset : in  std_logic;
      busy  : out std_logic;

      wr_data : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);
      rd_data : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);

      rd_req    : in std_logic;
      wr_req    : in std_logic;
      flush_req : in std_logic;         -- '1' flush cache line

      rd_ready   : out std_logic;       -- '1' if cache hit
      wr_ready   : out std_logic;       -- '1' when data will be written to
      -- cache on next rising edge of clock
      flush_done : out std_logic;       -- '1' when flush operation is complete

      address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

      -- connection to memory controller

      address_ds : out unsigned (ADDRESS_WIDTH - 2 downto 0);
      wr_data_ds : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_ds : in  std_logic_vector (WORD_WIDTH - 1 downto 0);

      burst_size_ds : out std_logic_vector(3 downto 0);  -- 1, 2, 4, 8 word bursts
                                        -- to downstream memory controller

      wr_req_ds   : out std_logic;  -- request to write from L2 to memory controller
      rd_req_ds   : out std_logic;  -- request to read from L2 to memory controller
      wr_grant_ds : in  std_logic;      -- request to write granted by memory
      -- controller, so words can now be written
      -- to memory controller
      rd_grant_ds : in  std_logic;      -- request to read granted by memory
      -- controller, and words are ready to be read
      wr_done_ds  : in  std_logic;  -- write cycle completed by memory controller
      n_rd_ds     : out std_logic;      -- write a word to memory controller
      n_wr_ds     : out std_logic       -- read a word from memory controller

      );
  end component;

  signal tb_clk   : std_logic;
  signal tb_reset : std_logic;
  signal tb_busy  : std_logic;

  signal tb_wr_data : std_logic_vector (63 downto 0);
  signal tb_rd_data : std_logic_vector (63 downto 0);

  signal tb_rd_req     : std_logic := '0';
  signal tb_wr_req     : std_logic := '0';
  signal tb_flush_req  : std_logic := '0';
  signal tb_rd_ready   : std_logic;
  signal tb_wr_ready   : std_logic;
  signal tb_flush_done : std_logic;
  signal tb_address    : unsigned (13 downto 0);  -- only 8k ram words downstream in
                                                  -- the test bench

  signal tb_address_ds : unsigned (12 downto 0);
  signal tb_wr_data_ds : std_logic_vector (15 downto 0);
  signal tb_rd_data_ds : std_logic_vector (15 downto 0);

  signal tb_burst_size_ds : std_logic_vector(3 downto 0);
  signal tb_wr_req_ds     : std_logic;
  signal tb_rd_req_ds     : std_logic;
  signal tb_wr_grant_ds   : std_logic;
  signal tb_rd_grant_ds   : std_logic;
  signal tb_wr_done_ds    : std_logic;
  signal tb_n_rd_ds       : std_logic;
  signal tb_n_wr_ds       : std_logic;

  signal tb_cacheline : std_logic_vector(63 downto 0);

  -- downstream memory

  constant ADDRESS_WIDTH : integer := 14;

  subtype memory_word is std_logic_vector(15 downto 0);
  type memory_array is array(2**(ADDRESS_WIDTH - 1) - 1 downto 0) of memory_word;

  function init_mem
    return memory_array is
    variable tmp : memory_array := (others => (others => '0'));
  begin
    for addr_pos in 0 to 2**(ADDRESS_WIDTH - 1) - 1 loop
      -- Initialize each address with the address itself
      tmp(addr_pos) := std_logic_vector(to_unsigned(addr_pos * 2 + 1, 8)) &
                       std_logic_vector(to_unsigned(addr_pos * 2, 8));
    end loop;
    return tmp;
  end init_mem;

  signal memory : memory_array := init_mem;


begin

  cache0 : L2Cache port map (
    clk   => tb_clk,
    reset => tb_reset,
    busy  => tb_busy,

    wr_data => tb_wr_data,
    rd_data => tb_rd_data,

    rd_req    => tb_rd_req,
    wr_req    => tb_wr_req,
    flush_req => tb_flush_req,

    rd_ready   => tb_rd_ready,
    wr_ready   => tb_wr_ready,
    flush_done => tb_flush_done,

    address => tb_address,

    address_ds => tb_address_ds,
    wr_data_ds => tb_wr_data_ds,
    rd_data_ds => tb_rd_data_ds,

    burst_size_ds => tb_burst_size_ds,
    wr_req_ds     => tb_wr_req_ds,
    rd_req_ds     => tb_rd_req_ds,
    wr_grant_ds   => tb_wr_grant_ds,
    rd_grant_ds   => tb_rd_grant_ds,
    wr_done_ds    => tb_wr_done_ds,
    n_rd_ds       => tb_n_rd_ds,
    n_wr_ds       => tb_n_wr_ds
    );

  process
  begin
    tb_clk <= '1';
    wait for clk_period / 2;
    tb_clk <= '0';
    wait for clk_period / 2;
  end process;

  process
  begin
    tb_reset                 <= '0';
    -- assert reset
    wait for 5*clk_period;
    tb_reset                 <= '1';
    wait for clk_period;
    tb_reset                 <= '0';
    --wait until tb_busy = '1';
    wait until tb_busy = '0';
    wait until tb_clk = '0';
    wait until tb_clk = '1';
    tb_rd_req                <= '1';
    tb_address               <= "10000000000000";
    wait until tb_rd_ready = '1';
    wait until tb_clk = '0';
    wait until tb_clk = '1';
    tb_cacheline             <= tb_rd_data;
    tb_rd_req                <= '0';
    wait until tb_clk = '0';
    tb_wr_data(7 downto 0) <= "10101010";
    tb_wr_data(63 downto 8)               <= tb_cacheline(63 downto 8);
    tb_wr_req                <= '1';
    wait until tb_clk = '1';
    wait until tb_wr_ready = '1';
    wait until tb_clk = '0';
    wait until tb_clk = '1';
	 tb_wr_req <= '0';
	 tb_flush_req <= '1';
	 wait until tb_flush_done = '1';
	 wait until tb_clk = '0';
	 wait until tb_clk = '1';
	 tb_flush_req <= '0';
    wait;
  end process;

  process
  begin

    wait until tb_rd_req_ds = '1';
    tb_rd_grant_ds <= '1';
    wait until tb_n_rd_ds = '0';

    for i in 0 to 3 loop  --2**to_integer(tb_burst_size_ds) - 1 loop
      wait until tb_clk = '0';
      tb_rd_data_ds <= memory(to_integer(tb_address_ds) + i);
      wait until tb_clk = '1';
    end loop;

    wait until tb_rd_req_ds = '0';
    tb_rd_grant_ds <= '0';
  end process;

  process
  begin

    wait until tb_wr_req_ds = '1';
    tb_wr_grant_ds <= '1';
    wait until tb_n_wr_ds = '0';

    for i in 0 to 3 loop
      wait until tb_clk = '0';
      wait until tb_clk = '1';
      memory(to_integer(tb_address_ds) + i) <= tb_wr_data_ds;
    end loop;

    wait until tb_wr_req_ds = '0';
    tb_wr_grant_ds <= '0';

  end process;

end RTL;
