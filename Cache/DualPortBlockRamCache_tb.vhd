--
--      DualPortBlockRamCache_tb.vhd : test bench for dual port block ram cache
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DualPortBlockRamCache_tb is
end DualPortBlockRamCache_tb;

architecture RTL of DualPortBlockRamCache_tb is

  constant clk_period : time := 20 ns;

  component DualPortBlockRamCache is
    generic (
      WORD_WIDTH_BITS            : natural;  -- width of data, e.g 16 bit word
      BYTE_WIDTH_BITS            : natural;  -- width of a byte
      ADDRESS_WIDTH         : natural;  -- width of address bus
      CACHE_LINE_WIDTH_BITS : natural;  -- number of bits used to represent
                                             -- cache line size in units of
                                             -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                             -- 8 bytes
      CACHE_LINE_NUM_BITS   : natural  -- E.g. 2**9 = 512 cache lines in
                                             -- L2 cache.
      );
    port (

      clk   : in std_logic;
      reset : in std_logic;

      wr_data_a  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_a  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      data_sel_a : in  std_logic;       -- '1', address word (address must be
      -- aligned), '0' address byte

      rd_req_a         : in std_logic;
      wr_req_a         : in std_logic;
      flush_req     : in std_logic;  -- flush a single cache line that contains address
      invalidate_req : in std_logic;  -- invalidate entire cache.

      wr_data_b  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_b  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      data_sel_b : in  std_logic;       -- '1', address word (address must be
      -- aligned), '0' address byte

      rd_req_b         : in std_logic;
      wr_req_b         : in std_logic;
      
      bypass : in std_logic;            -- if '1' cache is bypassed, and L1/L2
      -- caches will be held in reset. If
      -- '0', cache is active and cache
      -- bypass logic will be held in reset.

      rd_ready_a : out std_logic;       -- '1' if cache hit
      wr_ready_a : out std_logic;       -- '1' when data will be written to
      -- cache on next rising edge of clock

      rd_ready_b : out std_logic;       -- '1' if cache hit
      wr_ready_b : out std_logic;       -- '1' when data will be written to
      -- cache on next rising edge of clock

      flush_done      : out std_logic;
      invalidate_done : out std_logic;

      address_a : in unsigned (ADDRESS_WIDTH - 1 downto 0);
      address_b : in unsigned (ADDRESS_WIDTH - 1 downto 0);

      -- connection to downstream memory controller

      address_ds    : out unsigned (ADDRESS_WIDTH - 1 downto 0);
      wr_data_ds    : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      rd_data_ds    : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
      burst_size_ds : out std_logic_vector(3 downto 0);  -- 1, 2, 4, 8 word bursts
                                        -- to downstream memory controller
      wr_req_ds     : out std_logic;  -- request to write from L2 to memory controller
      rd_req_ds     : out std_logic;  -- request to read from L2 to memory controller
      wr_grant_ds   : in  std_logic;    -- request to write granted by memory
      -- controller, so words can now be written
      -- to memory controller
      rd_grant_ds   : in  std_logic;    -- request to read granted by memory
      -- controller, and words are ready to be read
      wr_done_ds    : in  std_logic;  -- write cycle completed by memory controller
      n_rd_ds       : out std_logic;    -- write a word to memory controller
      n_wr_ds       : out std_logic     -- read a word from memory controller
      );
  end component;

  constant WORD_WIDTH : natural := 16;
  constant ADDRESS_WIDTH : natural := 14;
  
  signal tb_clk   : std_logic;
  signal tb_reset : std_logic;

  signal tb_wr_data_a  : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_rd_data_a  : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_data_sel_a : std_logic;

  signal tb_rd_req_a         : std_logic := '0';
  signal tb_wr_req_a         : std_logic := '0';
  signal tb_flush_req      : std_logic := '0';
  signal tb_invalidate_req : std_logic := '0';
  
  signal tb_wr_data_b  : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_rd_data_b  : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_data_sel_b : std_logic;
  
  signal tb_rd_req_b         : std_logic;
  signal tb_wr_req_b         : std_logic;
  
  signal tb_bypass           : std_logic;
  
  signal tb_rd_ready_a : std_logic;
  signal tb_wr_ready_a : std_logic;
  
  signal tb_rd_ready_b : std_logic;
  signal tb_wr_ready_b : std_logic;
  
  signal tb_flush_done      : std_logic;
  signal tb_invalidate_done : std_logic;

  signal tb_address_a : unsigned (ADDRESS_WIDTH - 1 downto 0);
  signal tb_address_b : unsigned (ADDRESS_WIDTH - 1 downto 0);

  signal tb_address_ds    : unsigned (ADDRESS_WIDTH - 1 downto 0);
  signal tb_wr_data_ds    : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_rd_data_ds    : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal tb_burst_size_ds : std_logic_vector(3 downto 0);
  signal tb_wr_req_ds     : std_logic;
  signal tb_rd_req_ds     : std_logic;
  signal tb_wr_grant_ds   : std_logic;
  signal tb_rd_grant_ds   : std_logic;
  signal tb_wr_done_ds    : std_logic;
  signal tb_n_rd_ds       : std_logic;
  signal tb_n_wr_ds       : std_logic;
    
  signal tb_read_data_a : std_logic_vector(15 downto 0);
  signal tb_test_a, tb_test_a_done : std_logic := '0';
 
  signal tb_read_data_b : std_logic_vector(15 downto 0);
  signal tb_test_b, tb_test_b_done : std_logic := '0';
  
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


begin

  cache0 : DualPortBlockRamCache 
  generic map (
      WORD_WIDTH_BITS            => 4,  
      BYTE_WIDTH_BITS            => 3,  
      ADDRESS_WIDTH         => ADDRESS_WIDTH,  
      CACHE_LINE_WIDTH_BITS => 3,
      CACHE_LINE_NUM_BITS   => 9  
      )
  port map (
      clk  	=> tb_clk,
      reset => tb_reset,
      wr_data_a  => tb_wr_data_a,
      rd_data_a  => tb_rd_data_a,
      data_sel_a => tb_data_sel_a,       
      rd_req_a   => tb_rd_req_a,
      wr_req_a   => tb_wr_req_a,
      flush_req     => tb_flush_req, 
      invalidate_req => tb_invalidate_req,
      wr_data_b  => tb_wr_data_b,
      rd_data_b  => tb_rd_data_b,
      data_sel_b => tb_data_sel_b,       
      rd_req_b   => tb_rd_req_b,
      wr_req_b   => tb_wr_req_b,
      bypass 			  => tb_bypass,            
      rd_ready_a 		  => tb_rd_ready_a,       
      wr_ready_a 		  => tb_wr_ready_a,      
      rd_ready_b 		  => tb_rd_ready_b,    
      wr_ready_b 		  => tb_wr_ready_b, 
      flush_done       => tb_flush_done,
      invalidate_done  => tb_invalidate_done,
      address_a 		  => tb_address_a,
      address_b 		  => tb_address_b,
      address_ds    	  => tb_address_ds,
      wr_data_ds  	  => tb_wr_data_ds,
      rd_data_ds    	  => tb_rd_data_ds,
      burst_size_ds    => tb_burst_size_ds,
      wr_req_ds        => tb_wr_req_ds,
      rd_req_ds        => tb_rd_req_ds,
      wr_grant_ds      => tb_wr_grant_ds, 
      rd_grant_ds      => tb_rd_grant_ds,
      wr_done_ds       => tb_wr_done_ds,
      n_rd_ds          => tb_n_rd_ds,
      n_wr_ds          => tb_n_wr_ds  
    );

  process
  begin
    tb_clk <= '1';
    wait for clk_period / 2;
    tb_clk <= '0';
    wait for clk_period / 2;
  end process;

  process
	variable b1, b2: natural;
	variable val : std_logic_vector(15 downto 0);
  begin
    tb_reset                <= '0';
    -- assert reset
    wait for 5*clk_period;
    tb_reset                <= '1';
    wait for clk_period;
    tb_reset                <= '0';
   
	 tb_test_a 					 <= '1';
	 tb_test_b 					 <= '1';
	 wait until tb_test_a_done = '1' and tb_test_b_done = '1';
	 tb_invalidate_req <= '1';
	 wait until tb_invalidate_done = '1';
	 tb_invalidate_req <= '0';
	 
	 for i in 0 to 2**(ADDRESS_WIDTH - 1) - 1 loop
		b1 := i*2 + 1;
		b2 := i*2 + 2;
		val := std_logic_vector(to_unsigned(b2 mod 256, 8)) & std_logic_vector(to_unsigned(b1 mod 256, 8));
		assert memory(i) = val report "Error verifying memory: " & integer'image(i) & " " & 
			integer'image(to_integer(unsigned(val))) severity error;
	 end loop;
	 
    wait;
  end process;
  
  process 
	variable cacheline : natural;
	variable byte : natural;
  begin
	wait until tb_test_a = '1';
	
	tb_test_a_done <= '0';
	
	-- perform test of a port independently from b
	tb_wr_req_a <= '0';
	tb_rd_req_a <= '0';
	tb_data_sel_a <= '0';
	
	for i in 0 to 2**(ADDRESS_WIDTH - 1) - 1 loop
		cacheline := i / 8;
		byte := i mod 8;
	
		wait until tb_clk = '1';
		tb_address_a <= to_unsigned(cacheline*8*2 + byte, ADDRESS_WIDTH);
		tb_wr_req_a <= '0';
		tb_rd_req_a <= '1';
		wait until tb_rd_ready_a = '1';
		-- deglitch
		wait for 5ns;
		if tb_rd_ready_a /= '1' then
			wait until tb_rd_ready_a = '1';
	   end if;
		wait until tb_clk = '0';
		wait until tb_clk = '1';
		tb_read_data_a <= tb_rd_data_a;
		tb_rd_req_a <= '0';
		tb_wr_req_a <= '1';
		wait until tb_clk = '0';
		wait until tb_clk = '1';
		tb_wr_data_a <= std_logic_vector(unsigned(tb_read_data_a) + 1);
		wait until tb_wr_ready_a = '1';
		wait until tb_clk = '0';
		wait until tb_clk = '1';
	end loop;
	
	tb_wr_req_a <= '0';
	
	tb_test_a_done <= '1';
	
  end process;
  
  process 
	variable cacheline : natural;
	variable byte : natural; 
  begin
  wait until tb_test_b = '1';
	
	tb_test_b_done <= '0';
	
	-- perform test of a port independently from b
	tb_wr_req_b <= '0';
	tb_rd_req_b <= '0';
	tb_data_sel_b <= '0';
	
	for i in 0 to 2**(ADDRESS_WIDTH-1) - 1 loop
		cacheline := i / 8;
	   byte := i mod 8;
    	wait until tb_clk = '1';
		tb_address_b <= to_unsigned((cacheline*2 + 1)*8 + byte, ADDRESS_WIDTH);
		tb_wr_req_b <= '0';
		tb_rd_req_b <= '1';
		wait until tb_rd_ready_b = '1';
		-- deglitch
		wait for 5ns;
		if tb_rd_ready_b /= '1' then
			wait until tb_rd_ready_b = '1';
	   end if;
		wait until tb_clk = '0';
		wait until tb_clk = '1';
		tb_read_data_b <= tb_rd_data_b;
		tb_rd_req_b <= '0';
		tb_wr_req_b <= '1';
		wait until tb_clk = '0';
		wait until tb_clk = '1';
		tb_wr_data_b <= std_logic_vector(unsigned(tb_read_data_b) + 1);
		wait until tb_wr_ready_b = '1';
		wait until tb_clk = '0';
		wait until tb_clk = '1';
	end loop;
	
	tb_wr_req_b <= '0';
	
	tb_test_b_done <= '1';
	
  end process;

  process
  begin

    wait until tb_rd_req_ds = '1';
    tb_rd_grant_ds <= '1';
    wait until tb_n_rd_ds = '0';

    for i in 0 to 3 loop  --2**to_integer(tb_burst_size_ds) - 1 loop
      wait until tb_clk = '0';
      tb_rd_data_ds <= memory(to_integer(tb_address_ds(13 downto 1)) + i);
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
      memory(to_integer(tb_address_ds(13 downto 1)) + i) <= tb_wr_data_ds;
    end loop;

    wait until tb_wr_req_ds = '0';
    tb_wr_grant_ds <= '0';

  end process;

end RTL;
