--
--      L1Cache_tb.vhd : test bench for L1 cache
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity L1Cache_tb is
end L1Cache_tb;

architecture RTL of L1Cache_tb is

  constant clk_period : time := 20 ns;

  component L1Cache is
    generic (
      WORD_WIDTH            : natural := 16;
      BYTE_WIDTH            : natural := 8;
      CACHE_LINE_WIDTH_BITS : natural := 3;
      CACHE_LINE_NUM_BITS   : natural := 2;
      ADDRESS_WIDTH         : natural := 24
      );
    port (

      clk   : in std_logic;
      reset : in std_logic;

      wr_data  : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
      rd_data  : out std_logic_vector (WORD_WIDTH - 1 downto 0);
      data_sel : in  std_logic;

      rd_req     : in  std_logic;
      wr_req     : in  std_logic; 
      flush_req  : in  std_logic;
      rd_ready   : out std_logic;
      wr_ready   : out std_logic;
      flush_done : out std_logic;

      address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

      address_ds : out unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_ds : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS * 2**BYTE_WIDTH - 1 downto 0);
      rd_data_ds : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS * 2**BYTE_WIDTH - 1 downto 0);

      wr_ready_ds   : in  std_logic;
      rd_ready_ds   : in  std_logic;
      flush_done_ds : in  std_logic;
      flush_req_ds  : out std_logic;
      wr_req_ds     : out std_logic;
      rd_req_ds     : out std_logic

      );
  end component;

  signal tb_clk   : std_logic;
  signal tb_reset : std_logic;

  signal tb_wr_data  : std_logic_vector (15 downto 0);
  signal tb_rd_data  : std_logic_vector (15 downto 0);
  signal tb_data_sel : std_logic := '0';

  signal tb_rd_req     : std_logic := '0';
  signal tb_wr_req     : std_logic := '0';
  signal tb_flush_req  : std_logic := '0';
  signal tb_rd_ready   : std_logic;
  signal tb_wr_ready   : std_logic;
  signal tb_flush_done : std_logic;

  signal tb_address : unsigned (7 downto 0);

  signal tb_address_ds : unsigned (7 downto 0);
  signal tb_wr_data_ds : std_logic_vector (15 downto 0);
  signal tb_rd_data_ds : std_logic_vector (15 downto 0);

  signal tb_wr_ready_ds   : std_logic;
  signal tb_rd_ready_ds   : std_logic;
  signal tb_flush_done_ds : std_logic;
  signal tb_flush_req_ds  : std_logic;
  signal tb_wr_req_ds     : std_logic;
  signal tb_rd_req_ds     : std_logic;

  -- downstream cache

  constant ADDRESS_WIDTH : integer := 8;

  subtype ds_cache_line is std_logic_vector(15 downto 0);
  type ds_cache_array is array(2**(ADDRESS_WIDTH - 1) - 1 downto 0) of ds_cache_line;

  function init_mem
    return ds_cache_array is
    variable tmp : ds_cache_array := (others => (others => '0'));
  begin
    for addr_pos in 0 to 2**(ADDRESS_WIDTH - 1) - 1 loop
      -- Initialize each address with the address itself
      tmp(addr_pos) := std_logic_vector(to_unsigned(addr_pos * 2 + 1, 8)) &
              std_logic_vector(to_unsigned(addr_pos * 2, 8));
    end loop;
    return tmp;
  end init_mem;

  signal ds_cache : ds_cache_array := init_mem;

begin

  cache0 : L1Cache generic map (
    WORD_WIDTH            => 16,
    BYTE_WIDTH            => 8,
    CACHE_LINE_WIDTH_BITS => 1,             -- 2**1 = 2 byte cache lines
    CACHE_LINE_NUM_BITS   => 2,             -- 2**2 = 4 cache lines
    ADDRESS_WIDTH         => ADDRESS_WIDTH  -- 8 bit width
    )
    port map (
      clk   => tb_clk,
      reset => tb_reset,

      wr_data  => tb_wr_data,
      rd_data  => tb_rd_data,
      data_sel => tb_data_sel,

      rd_req     => tb_rd_req,
      wr_req     => tb_wr_req,
      flush_req  => tb_flush_req,
      rd_ready   => tb_rd_ready,
      wr_ready   => tb_wr_ready,
      flush_done => tb_flush_done,

      address => tb_address,

      address_ds => tb_address_ds,
      wr_data_ds => tb_wr_data_ds,
      rd_data_ds => tb_rd_data_ds,

      wr_ready_ds   => tb_wr_ready_ds,
      rd_ready_ds   => tb_rd_ready_ds,
      flush_done_ds => tb_flush_done_ds,
      flush_req_ds  => tb_flush_req_ds,
      wr_req_ds     => tb_wr_req_ds,
      rd_req_ds     => tb_rd_req_ds
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
    tb_reset <= '0';
    -- assert reset
    wait for 5*clk_period;
    tb_reset <= '1';
    wait for clk_period;
    tb_reset <= '0';
    
    -- initiate write request to address 5

    tb_address        <= (0 => '1', 2 => '1', others => '0');
    tb_wr_req         <= '1';
    tb_data_sel       <= '0';           -- select byte
    tb_wr_data        <= "0000000010101010";
    wait until tb_wr_ready = '1';
    wait until tb_clk = '0';
    wait until tb_clk = '1';
    tb_wr_req         <= '0';
    
    -- initiate read request from address 1

    tb_address        <= (0 => '1', others => '0');
    tb_rd_req         <= '1';
    tb_data_sel       <= '0';           -- select byte
    wait until tb_clk = '0';				 -- miss glitch at start
	 wait until tb_rd_ready = '1';
	 wait until tb_clk = '0';
    wait until tb_clk = '1';
    tb_rd_req         <= '0';
    
	 -- flush address 5
	 
	 tb_address 	   <= (0 => '1', 2 => '1', others => '0');
	 tb_flush_req 		<= '1';
	 tb_data_sel 		<= '0';
	 wait until tb_flush_done = '1';
	 wait until tb_clk = '0';
	 wait until tb_clk = '1';
	 tb_flush_req <= '0';

    wait;

  end process;

  -- model a downstream cache
  process (tb_address_ds, tb_wr_data_ds, tb_rd_data_ds,
           tb_flush_req_ds, tb_wr_req_ds, tb_rd_req_ds)
  begin

    tb_rd_ready_ds   <= '0';
    tb_wr_ready_ds   <= '0';
    tb_flush_done_ds <= '0';
	 
    if tb_rd_req_ds = '1' then

      tb_rd_data_ds  <= ds_cache(to_integer(tb_address_ds(7 downto 1)));
      tb_rd_ready_ds <= '1';

    elsif tb_wr_req_ds = '1' then

      ds_cache(to_integer(tb_address_ds(7 downto 1))) <= tb_wr_data_ds;
      tb_wr_ready_ds <= '1';

	 elsif tb_flush_req_ds = '1' then
		
		tb_flush_done_ds <= '1';
		
    end if;

  end process;

end RTL;
