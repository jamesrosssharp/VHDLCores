--
--      TwoLevelCache_tb.vhd : test bench for two level cache
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity TwoLevelCache_tb is
end TwoLevelCache_tb;

architecture RTL of TwoLevelCache_tb is

  component TwoLevelCache is
    generic (
      WORD_WIDTH             : natural := 16;
      BYTE_WIDTH             : natural := 8;
      ADDRESS_WIDTH          : natural := 14;
      CACHE_LINE_WIDTH_BITS  : natural := 2;
      L2_CACHE_LINE_NUM_BITS : natural := 9;
      L1_CACHE_LINE_NUM_BITS : natural := 2
      );
    port (
      clk             : in  std_logic;
      reset           : in  std_logic;
      wr_data         : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data         : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      data_sel        : in  std_logic;
      rd_req          : in  std_logic;
      wr_req          : in  std_logic;
      flush_req       : in  std_logic;
      invalidate_req  : in  std_logic;
      bypass          : in  std_logic;
      rd_ready        : out std_logic;
      wr_ready        : out std_logic;
      flush_done      : out std_logic;
      invalidate_done : out std_logic;
      address         : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_ds      : out unsigned (ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH downto 0);
      wr_data_ds      : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data_ds      : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      burst_size_ds   : out std_logic_vector(3 downto 0);
      wr_req_ds       : out std_logic;
      rd_req_ds       : out std_logic;
      wr_grant_ds     : in  std_logic;
      rd_grant_ds     : in  std_logic;
      wr_done_ds      : in  std_logic;
      n_rd_ds         : out std_logic;
      n_wr_ds         : out std_logic
      );
  end component;

  constant WORD_WIDTH    : natural := 16;
  constant BYTE_WIDTH    : natural := 8;
  constant ADDRESS_WIDTH : natural := 14;


  signal tb_clk             : std_logic;
  signal tb_reset           : std_logic;
  signal tb_wr_data         : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_rd_data         : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_data_sel        : std_logic;
  signal tb_rd_req          : std_logic;
  signal tb_wr_req          : std_logic;
  signal tb_flush_req       : std_logic;
  signal tb_invalidate_req  : std_logic;
  signal tb_bypass          : std_logic;
  signal tb_rd_ready        : std_logic;
  signal tb_wr_ready        : std_logic;
  signal tb_flush_done      : std_logic;
  signal tb_invalidate_done : std_logic;
  signal tb_address         : unsigned (ADDRESS_WIDTH - 1 downto 0);
  signal tb_address_ds      : unsigned (ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH downto 0);
  signal tb_wr_data_ds      : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_rd_data_ds      : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_burst_size_ds   : std_logic_vector(3 downto 0);
  signal tb_wr_req_ds       : std_logic;
  signal tb_rd_req_ds       : std_logic;
  signal tb_wr_grant_ds     : std_logic;
  signal tb_rd_grant_ds     : std_logic;
  signal tb_wr_done_ds      : std_logic;
  signal tb_n_rd_ds         : std_logic;
  signal tb_n_wr_ds         : std_logic;

  -- downstream memory

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

  constant clk_period : time := 20 ns;

  signal byte_read : std_logic_vector(7 downto 0);

begin

  cache0 : TwoLevelCache
    generic map (
      WORD_WIDTH             => WORD_WIDTH,
      BYTE_WIDTH             => BYTE_WIDTH,
      ADDRESS_WIDTH          => ADDRESS_WIDTH,
      CACHE_LINE_WIDTH_BITS  => 3,
      L2_CACHE_LINE_NUM_BITS => 9,
      L1_CACHE_LINE_NUM_BITS => 2
      )
  port map (
    clk             => tb_clk,
    reset           => tb_reset,
    wr_data         => tb_wr_data,
    rd_data         => tb_rd_data,
    data_sel        => tb_data_sel,
    rd_req          => tb_rd_req,
    wr_req          => tb_wr_req,
    flush_req       => tb_flush_req,
    invalidate_req  => tb_invalidate_req,
    bypass          => tb_bypass,
    rd_ready        => tb_rd_ready,
    wr_ready        => tb_wr_ready,
    flush_done      => tb_flush_done,
    invalidate_done => tb_invalidate_done,
    address         => tb_address,
    address_ds      => tb_address_ds,
    wr_data_ds      => tb_wr_data_ds,
    rd_data_ds      => tb_rd_data_ds,
    burst_size_ds   => tb_burst_size_ds,
    wr_req_ds       => tb_wr_req_ds,
    rd_req_ds       => tb_rd_req_ds,
    wr_grant_ds     => tb_wr_grant_ds,
    rd_grant_ds     => tb_rd_grant_ds,
    wr_done_ds      => tb_wr_done_ds,
    n_rd_ds         => tb_n_rd_ds,
    n_wr_ds         => tb_n_wr_ds
    );

  process
  begin
    tb_clk <= '1';
    wait for clk_period / 2;
    tb_clk <= '0';
    wait for clk_period / 2;
  end process;

  -- main process

  process
  begin
    tb_reset <= '0';
    -- assert reset
    wait for 5*clk_period;
    tb_reset <= '1';
    wait for clk_period;
    tb_reset <= '0';

    -- for entire memory, read one byte, then increment the value by one,
    -- then write it back.

    for i in 0 to 2**ADDRESS_WIDTH - 1 loop

      tb_rd_req  <= '1';
      tb_data_sel <= '0';
      tb_address <= to_unsigned(i, ADDRESS_WIDTH);
      wait until tb_rd_ready = '1';
      byte_read  <= tb_rd_data(7 downto 0);
      wait until tb_clk = '0';
      wait until tb_clk = '1';
      tb_rd_req <= '0';
      
      tb_wr_data(7 downto 0) <= byte_read;
      tb_wr_req <= '1';

      wait until tb_wr_ready = '1';
      wait until tb_clk = '0';
      wait until tb_clk = '1';
      tb_wr_req <= '0';
                       
    end loop;

    -- invalidate entire cache

    -- validate memory

    -- now bypass cache and decrement each byte in memory by one

    -- validate memory


  end process;

   process
  begin

    wait until tb_rd_req_ds = '1';
    tb_rd_grant_ds <= '1';
    wait until tb_n_rd_ds = '0';

    for i in 0 to to_integer(unsigned(tb_burst_size_ds)) - 1 loop
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

    for i in 0 to to_integer(unsigned(tb_burst_size_ds)) - 1 loop
      wait until tb_clk = '0';
      wait until tb_clk = '1';
      memory(to_integer(tb_address_ds) + i) <= tb_wr_data_ds;
    end loop;

    wait until tb_wr_req_ds = '0';
    tb_wr_grant_ds <= '0';

  end process;

  
end RTL;
