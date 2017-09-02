--
--      L2Cache.vhd : configurable L2 cache implemented in synchronous block ram
--
--      Cache is designed to be used with an L1 cache sized identically, so a single
--      cache line can be transferred in one transaction.
--
--      Downstream, designed to connect to a memory controller.
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity L2Cache is
  generic (
    WORD_WIDTH            : natural := 16;  -- width of data, e.g 16 bit word
    BYTE_WIDTH            : natural := 8;  -- width of a byte
    CACHE_LINE_WIDTH_BITS : natural := 3;  -- number of bits used to represent
                                           -- cache line size in units of
                                           -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                           -- 8 bytes
    CACHE_LINE_NUM_BITS   : natural := 9;  -- E.g. 2**9 = 512 cache lines in cache.
    ADDRESS_WIDTH         : natural := 24  -- width of address bus
    );
  port (

    clk   : in  std_logic;
    reset : in  std_logic;
    busy  : out std_logic;

    wr_data : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);
    rd_data : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS*BYTE_WIDTH - 1 downto 0);

    rd_req    : in std_logic;
    wr_req    : in std_logic;
    flush_req : in std_logic;           -- '1' flush cache line

    rd_ready   : out std_logic;         -- '1' if cache hit
    wr_ready   : out std_logic;         -- '1' when data will be written to
    -- cache on next rising edge of clock
    flush_done : out std_logic;         -- '1' when flush operation is complete

    address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

    -- connection to memory controller

    address_ds : out unsigned (ADDRESS_WIDTH - 2 downto 0);
    wr_data_ds : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_ds : in  std_logic_vector (WORD_WIDTH - 1 downto 0);

    burst_size_ds : out std_logic_vector(3 downto 0);  -- 1, 2, 4, 8 word bursts
                                        -- to downstream memory controller

    wr_req_ds   : out std_logic;  -- request to write from L2 to memory controller
    rd_req_ds   : out std_logic;  -- request to read from L2 to memory controller
    wr_grant_ds : in  std_logic;        -- request to write granted by memory
    -- controller, so words can now be written
    -- to memory controller
    rd_grant_ds : in  std_logic;        -- request to read granted by memory
    -- controller, and words are ready to be read
    wr_done_ds  : in  std_logic;  -- write cycle completed by memory controller
    n_rd_ds     : out std_logic;        -- write a word to memory controller
    n_wr_ds     : out std_logic         -- read a word from memory controller

    );
end L2Cache;

architecture RTL of L2Cache is

  constant TAG_WIDTH : natural :=
    ADDRESS_WIDTH - CACHE_LINE_NUM_BITS - CACHE_LINE_WIDTH_BITS;
  constant CACHE_LINE_SIZE_BITS : natural :=
    2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH + TAG_WIDTH + 2;  -- plus valid and
                                                            -- dirty bits
  constant CACHE_LINE_FIRST_DATA_BIT : natural := 0;
  constant CACHE_LINE_LAST_DATA_BIT  : natural := 2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1;
  constant CACHE_LINE_FIRST_TAG_BIT  : natural := CACHE_LINE_LAST_DATA_BIT + 1;
  constant CACHE_LINE_LAST_TAG_BIT   : natural := CACHE_LINE_FIRST_TAG_BIT + TAG_WIDTH - 1;
  constant CACHE_LINE_DIRTY_BIT      : natural := CACHE_LINE_LAST_TAG_BIT + 1;
  constant CACHE_LINE_VALID_BIT      : natural := CACHE_LINE_DIRTY_BIT + 1;
  constant CACHE_LINE_WORD_BITS      : natural := (CACHE_LINE_WIDTH_BITS - (WORD_WIDTH / BYTE_WIDTH / 2));

  constant ADDRESS_FIRST_BYTE_BIT           : natural := 0;
  constant ADDRESS_LAST_BYTE_BIT            : natural := CACHE_LINE_WIDTH_BITS - 1;
  constant ADDRESS_FIRST_WORD_BIT           : natural := (WORD_WIDTH / BYTE_WIDTH / 2);
  constant ADDRESS_LAST_WORD_BIT            : natural := CACHE_LINE_WIDTH_BITS - 1;
  constant ADDRESS_FIRST_CACHE_LINE_SEL_BIT : natural := ADDRESS_LAST_BYTE_BIT + 1;
  constant ADDRESS_LAST_CACHE_LINE_SEL_BIT  : natural :=
    ADDRESS_FIRST_CACHE_LINE_SEL_BIT + CACHE_LINE_NUM_BITS - 1;
  constant ADDRESS_FIRST_TAG_BIT : natural := ADDRESS_LAST_CACHE_LINE_SEL_BIT + 1;
  constant ADDRESS_LAST_TAG_BIT  : natural := ADDRESS_FIRST_TAG_BIT + TAG_WIDTH - 1;

  component L2CacheMemoryTemplate is

    generic
      (
        DATA_WIDTH : natural := CACHE_LINE_SIZE_BITS;
        ADDR_WIDTH : natural := CACHE_LINE_NUM_BITS
        );

    port
      (
        clk  : in  std_logic;
        addr : in  natural range 0 to (2**ADDR_WIDTH - 1);
        data : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
        we   : in  std_logic;
        q    : out std_logic_vector((DATA_WIDTH - 1) downto 0)
        );

  end component;

  subtype cacheline_t is std_logic_vector(CACHE_LINE_SIZE_BITS - 1 downto 0);

  signal sel_cacheline_addr : natural range 0 to 2**CACHE_LINE_NUM_BITS - 1;
  signal sel_cacheline      : cacheline_t;

  signal cacheline_wr_data, cacheline_wr_data_next, cacheline_muxed_wr_data, cacheline_wr_data2 : cacheline_t;
  signal cacheline_wr                                                                           : std_logic := '0';
  signal cacheline_mux_sel                                                                      : std_logic := '0';

  type state_t is (idle, resetCache, prefetchCacheLine,
                   flushOutCacheLine, flushOutCacheLine2,
                   readNewCacheLine, readNewCacheLine2, readNewCacheLine3,
                   writeCacheLine);
  signal state, next_state : state_t := idle;

  signal flush_return_state, flush_return_state_next : state_t := idle;
  signal read_return_state, read_return_state_next   : state_t := idle;

  -- reset logic

  signal reset_address, reset_address_next : natural range 0 to 2**CACHE_LINE_NUM_BITS - 1;

  signal sel_cache_line_idx : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal sel_tag, cache_tag : unsigned (TAG_WIDTH - 1 downto 0);
  signal sel_byte           : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal sel_word           : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);

  signal cache_valid, cache_dirty : std_logic;

  signal cache_read_word, cache_read_word_next : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);
  constant TERMINAL_CACHE_READ_WORD            : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0) := (others => '1');

  function write_word_to_next_cacheline (cache_line : cacheline_t;
                                         word       : std_logic_vector (word_WIDTH - 1 downto 0);
                                         sel_byte   : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0))
    return cacheline_t is
    variable cache_line_next : cacheline_t;
  begin

    cache_line_next := cache_line;

    for i in 0 to 2**CACHE_LINE_WORD_BITS - 1 loop
      if i = to_integer(sel_byte) then
        cache_line_next(WORD_WIDTH*(i+1) - 1 downto WORD_WIDTH*i) := word;
      end if;
    end loop;

    return cache_line_next;

  end function write_word_to_next_cacheline;

  function read_word_from_cacheline (cache_line : cacheline_t;
                                     sel_byte   : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0))
    return std_logic_vector is
    variable word : std_logic_vector (WORD_WIDTH - 1 downto 0);
  begin

    for i in 0 to 2**CACHE_LINE_WORD_BITS - 1 loop
      if i = to_integer(sel_byte) then
        word := cache_line(WORD_WIDTH*(i+1) - 1 downto WORD_WIDTH*i);
      end if;
    end loop;

    return word;

  end function read_word_from_cacheline;

begin

  ram0 : L2CacheMemoryTemplate port map (
    clk  => clk,
    addr => sel_cacheline_addr,
    data => cacheline_muxed_wr_data,
    we   => cacheline_wr,
    q    => sel_cacheline
    );

  cacheline_muxed_wr_data <= cacheline_wr_data when cacheline_mux_sel = '0' else
                             cacheline_wr_data2;

  sel_cache_line_idx <= address(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  sel_tag            <= address(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  sel_byte           <= address(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  sel_word           <= address(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  cache_tag   <= unsigned(sel_cacheline(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT));
  cache_valid <= sel_cacheline(CACHE_LINE_VALID_BIT);
  cache_dirty <= sel_cacheline(CACHE_LINE_DIRTY_BIT);

  rd_data <= sel_cacheline(CACHE_LINE_LAST_DATA_BIT downto CACHE_LINE_FIRST_DATA_BIT);

  address_ds(ADDRESS_FIRST_CACHE_LINE_SEL_BIT - 2 downto 0) <= (others => '0');
  address_ds(ADDRESS_LAST_TAG_BIT - 1 downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT - 1)
    <= address(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);

  process (clk, reset)
  begin
    if (reset = '1') then
      state              <= resetCache;
      reset_address      <= 0;
      flush_return_state <= idle;
      read_return_state  <= idle;
      cacheline_wr_data  <= (others => '0');
      cache_read_word    <= (others => '0');
    elsif rising_edge(clk) then
      state              <= next_state;
      reset_address      <= reset_address_next;
      flush_return_state <= flush_return_state_next;
      read_return_state  <= read_return_state_next;
      if (cacheline_wr = '0') then
        cacheline_wr_data <= cacheline_wr_data_next;
      end if;
      cache_read_word <= cache_read_word_next;
    end if;
  end process;

  process (state, reset_address, flush_return_state, read_return_state,
           rd_req, wr_req, flush_req, cache_valid, cache_dirty, sel_cache_line_idx,
           sel_tag, cache_tag, cache_read_word, cacheline_wr_data, rd_data_ds, rd_grant_ds,
			  wr_grant_ds)
  begin

    busy                    <= '0';
    sel_cacheline_addr      <= 0;
    next_state              <= state;
    cacheline_wr            <= '0';
    flush_return_state_next <= flush_return_state;
    read_return_state_next  <= read_return_state;
    sel_cacheline_addr      <= to_integer(sel_cache_line_idx);
    reset_address_next      <= reset_address;

    cache_read_word_next   <= (others => '0');
    cacheline_wr_data_next <= cacheline_wr_data;

    cacheline_wr_data2(CACHE_LINE_LAST_DATA_BIT downto CACHE_LINE_FIRST_DATA_BIT) <= wr_data;
    cacheline_wr_data2(CACHE_LINE_VALID_BIT)                                      <= '1';
    cacheline_wr_data2(CACHE_LINE_DIRTY_BIT)                                      <= '1';
    cacheline_wr_data2(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT)
      <= std_logic_vector(sel_tag);
    cacheline_mux_sel <= '0';

    rd_ready <= '0';
	 wr_ready <= '0';

    n_rd_ds   <= '1';
    rd_req_ds <= '0';
    n_wr_ds   <= '1';
    wr_req_ds <= '0';

    case state is
      when idle =>
        if (rd_req = '1') then
          next_state <= prefetchCacheline;
        elsif (wr_req = '1') then
          next_state <= prefetchCacheline;
        elsif (flush_req = '1') then
          flush_return_state_next <= idle;
          next_state              <= flushOutCacheLine;
        end if;
      when resetCache =>
        busy               <= '1';
        sel_cacheline_addr <= reset_address;
        cacheline_wr       <= '1';
        if (reset_address = 2**CACHE_LINE_NUM_BITS - 1) then
          next_state <= idle;
        else
          reset_address_next <= reset_address + 1;
        end if;
      when prefetchCacheLine =>
        if (rd_req = '1') then
          if (sel_tag = cache_tag and cache_valid = '1') then
            rd_ready   <= '1';
            next_state <= idle;
          else
            if (cache_dirty = '1' and cache_valid = '1') then
              next_state              <= flushOutCacheline;
              flush_return_state_next <= readNewCacheLine;
            else
              next_state <= readNewCacheline;
            end if;
          end if;
        elsif (wr_req = '1') then
          if (sel_tag = cache_tag and cache_valid = '1') then
            -- cache hit. No need to flush out cacheline. Prepare
            -- data to write to cacheline
            cacheline_mux_sel <= '1';
            cacheline_wr      <= '1';
            next_state        <= idle;
            wr_ready           <= '1';
          else
            -- cache missed. Flush out cache line and load in new data.
            next_state              <= flushOutCacheLine;
            flush_return_state_next <= writeCacheline;
          end if;
        else
          -- invalid state. go back to idle
          next_state <= idle;
        end if;
      when flushOutCacheLine =>
        wr_req_ds <= '1';
        if (wr_grant_ds = '1') then
          next_state <= flushOutCacheLine2;
        end if;
      when flushOutCacheLine2 =>
        wr_req_ds            <= '1';
        n_wr_ds              <= '0';
        wr_data_ds           <= read_word_from_cacheline(sel_cacheline, cache_read_word);
        cache_read_word_next <= cache_read_word + 1;
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          flush_done <= '1';
          next_state <= flush_return_state;
        end if;
      when readNewCacheLine =>
        rd_req_ds <= '1';
        if (rd_grant_ds = '1') then
          next_state <= readNewCacheLine2;
        end if;
      when readNewCacheLine2 =>
        rd_req_ds            <= '1';
        cache_read_word_next <= cache_read_word + 1;
        n_rd_ds              <= '0';
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          next_state <= readNewCacheLine3;
        end if;
        cacheline_wr_data_next <=
          write_word_to_next_cacheline(cacheline_wr_data, rd_data_ds, cache_read_word);
        cacheline_wr_data_next(CACHE_LINE_VALID_BIT) <= '1';
        cacheline_wr_data_next(CACHE_LINE_DIRTY_BIT) <= '0';
        cacheline_wr_data_next(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT)
          <= std_logic_vector(sel_tag);

      when readNewCacheLine3 =>
        cacheline_wr <= '1';
        next_state   <= idle;
      when writeCacheline =>
        cacheline_mux_sel <= '1';
        cacheline_wr      <= '1';
        next_state        <= idle;
        wr_ready           <= '1';
      when others =>
        next_state <= idle;
    end case;
  end process;

end RTL;
