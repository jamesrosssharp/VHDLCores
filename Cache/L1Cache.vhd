--
--      L1Cache.vhd : configurable L1 cache implemented in FPGA fabric
--      (not synchronous block ram)
--
--      Note: can address a byte (e.g. 8 bits), or a word (e.g. 16 bits), selectable
--      using DATA_SEL (0 = byte, 1 = word).
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity L1Cache is
  generic (
    WORD_WIDTH            : natural := 16;  -- width of data, e.g 16 bit word
    BYTE_WIDTH            : natural := 8;  -- width of a byte
    CACHE_LINE_WIDTH_BITS : natural := 2;  -- number of bits used to represent
                                           -- cache line size in units of
                                           -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                           -- 8 bytes
    CACHE_LINE_NUM_BITS   : natural := 1;  -- E.g. 2**2 = 4 cache lines in cache.
    ADDRESS_WIDTH         : natural := 24  -- width of address bus
    );
  port (

    clk   : in std_logic;
    reset : in std_logic;

    wr_data  : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data  : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    data_sel : in  std_logic;           -- '1', address word (address must be
    -- aligned), '0' address byte

    rd_req    : in std_logic;
    wr_req    : in std_logic;
    flush_req : in std_logic;           -- '1' flush cache line

    rd_ready   : out std_logic;         -- '1' if cache hit
    wr_ready   : out std_logic;         -- '1' when data will be written to
    -- cache on next rising edge of clock
    flush_done : out std_logic;         -- '1' when flush operation is complete

    address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

    -- connection to downstream cache

    address_ds : out unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_ds : out std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);
    rd_data_ds : in  std_logic_vector (2**CACHE_LINE_WIDTH_BITS * BYTE_WIDTH - 1 downto 0);

    wr_ready_ds   : in  std_logic;
    rd_ready_ds   : in  std_logic;
    flush_done_ds : in  std_logic;
    flush_req_ds  : out std_logic;
    wr_req_ds     : out std_logic;
    rd_req_ds     : out std_logic

    );
end L1Cache;

architecture RTL of L1Cache is

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

  --
  -- States:
  -- *  when idle and read req asserted, data from selected cache line is sent to
  --    rd_data and rd_ready set to comparison of cache line tag anded with cache
  --    line valid. If the cache "hits", no action is taken. If the cache misses,
  --    then if the cache entry is valid and dirty, it is flushed to downstream
  --    (L2) cache. if either not valid or not dirty, no flush to the downstream
  --    is performed.
  --
  -- *  when idle and write req asserted, wr_ready is set to comparison of cache
  --    line tag anded with cache line valid. If the cache hits, the cache line
  --    is updated and dirty bit is set. If the cache misses, then if the cache
  --    line is valid and dirty, it is flushed to the downstream (L2) cache. 
  --    Then the cache line is filled from the downstream cache. Then the cache
  --    line is updated, and wr_ready is set to '1'. wr_data must remain valid
  --    until this time.
  --

  type state_t is (idle, flushOutCacheEntry, readNewCacheEntry, writeCacheEntry,
                   flushDownstreamCache);

  signal state, next_state, read_return_state, read_return_state_next,
    flush_return_state, flush_return_state_next : state_t := idle;

  subtype cacheline_t is std_logic_vector(CACHE_LINE_SIZE_BITS - 1 downto 0);
  type cache_array_t is array(2**CACHE_LINE_NUM_BITS - 1 downto 0) of cacheline_t;

  signal cache_array : cache_array_t := (others => (others => '0'));

  signal sel_cache_line_idx : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal sel_tag, cache_tag : unsigned (TAG_WIDTH - 1 downto 0);
  signal sel_byte           : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal sel_word           : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);

  signal sel_cache_line, sel_cache_line_next : cacheline_t;

  signal cache_valid : std_logic;
  signal cache_dirty : std_logic;
  signal cache_wr    : std_logic := '0';

  -- functions to retrieve a byte from a cache line

  function get_byte_from_cache_line(cache_line : cacheline_t;
                                    sel_byte   : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0))
    return std_logic_vector is
    variable byte : std_logic_vector(BYTE_WIDTH - 1 downto 0);
  begin

    for i in 0 to 2**CACHE_LINE_WIDTH_BITS - 1 loop
      if i = to_integer(sel_byte) then
        byte := cache_line(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i);
      end if;
    end loop;

    return byte;

  end function get_byte_from_cache_line;

  function get_word_from_cache_line(cache_line : cacheline_t;
                                    sel_word   : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0))
    return std_logic_vector is
    variable word : std_logic_vector(WORD_WIDTH - 1 downto 0);
  begin

    for i in 0 to 2**CACHE_LINE_WORD_BITS - 1 loop
      if i = to_integer(sel_word) then
        word := cache_line(WORD_WIDTH*(i+1) - 1 downto WORD_WIDTH*i);
      end if;
    end loop;

    return word;

  end function get_word_from_cache_line;

  function create_cache_line_from_byte (cache_line : cacheline_t;
                                        byte       : std_logic_vector (BYTE_WIDTH - 1 downto 0);
                                        sel_byte   : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0))
    return cacheline_t is
    variable cache_line_next : cacheline_t;
  begin

    cache_line_next := cache_line;

    for i in 0 to 2**CACHE_LINE_WIDTH_BITS - 1 loop
      if i = to_integer(sel_byte) then
        cache_line_next(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) := byte;
      end if;
    end loop;

    return cache_line_next;

  end function create_cache_line_from_byte;

  function create_cache_line_from_word (cache_line : cacheline_t;
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

  end function create_cache_line_from_word;


begin

  sel_cache_line_idx <= address(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  sel_tag            <= address(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  sel_byte           <= address(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  sel_word           <= address(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  sel_cache_line <= cache_array(to_integer(sel_cache_line_idx));
  cache_tag      <= unsigned(sel_cache_line(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT));

  cache_valid <= sel_cache_line(CACHE_LINE_VALID_BIT);
  cache_dirty <= sel_cache_line(CACHE_LINE_DIRTY_BIT);

  process (clk, reset)
  begin
    if (reset = '1') then
      state              <= idle;
      read_return_state  <= idle;
      flush_return_state <= idle;
      for i in 2**CACHE_LINE_NUM_BITS - 1 downto 0 loop
        cache_array(0)(CACHE_LINE_VALID_BIT) <= '0';
      end loop;
    elsif rising_edge(clk) then
      state              <= next_state;
      read_return_state  <= read_return_state_next;
      flush_return_state <= flush_return_state_next;
      if cache_wr = '1' then
        cache_array(to_integer(sel_cache_line_idx)) <= sel_cache_line_next;
      end if;
    end if;
  end process;

  process (state, rd_req, wr_req, address, sel_cache_line, data_sel, sel_byte, sel_word,
           read_return_state, flush_return_state, sel_tag, cache_tag, cache_valid, cache_dirty,
           sel_cache_line_next, flush_req, wr_data, sel_cache_line_idx, wr_ready_ds, rd_ready_ds,
           rd_data_ds, flush_done_ds)
  begin

    cache_wr <= '0';

    wr_req_ds <= '0';
    rd_req_ds <= '0';

    read_return_state_next  <= read_return_state;
    flush_return_state_next <= flush_return_state;

    sel_cache_line_next <= sel_cache_line;

    next_state <= state;

    address_ds <= (others => '0');

    rd_ready   <= '0';
    wr_ready   <= '0';
    flush_done <= '0';

    rd_data      <= (others => '0');
    wr_data_ds   <= (others => '0');
    flush_req_ds <= '0';

    case state is
      when idle =>
        if (rd_req = '1') then

          if sel_tag = cache_tag and cache_valid = '1' then
            rd_ready <= '1';

            if (data_sel = '0') then
              rd_data(BYTE_WIDTH - 1 downto 0) <= get_byte_from_cache_line(sel_cache_line, sel_byte);
            else
              rd_data(WORD_WIDTH - 1 downto 0) <= get_word_from_cache_line(sel_cache_line, sel_word);
            end if;

          else

            -- is cache line valid?
            if cache_valid = '1' and cache_dirty = '1' then
              read_return_state_next  <= idle;
              flush_return_state_next <= readNewCacheEntry;
              next_state              <= flushOutCacheEntry;
            else
              read_return_state_next <= idle;
              next_state             <= readNewCacheEntry;
            end if;

          end if;

        elsif (wr_req = '1') then

          if sel_tag = cache_tag and cache_valid = '1' then
            wr_ready <= '1';
            cache_wr <= '1';

            -- get data to write
            if (data_sel = '0') then
              sel_cache_line_next <= create_cache_line_from_byte(sel_cache_line, wr_data(BYTE_WIDTH - 1 downto 0), sel_byte);
            else
              sel_cache_line_next <= create_cache_line_from_word(sel_cache_line, wr_data(WORD_WIDTH - 1 downto 0), sel_word);
            end if;

            sel_cache_line_next(CACHE_LINE_DIRTY_BIT) <= '1';

          else

            -- is cache line valid?
            if cache_valid = '1' and cache_dirty = '1' then
              read_return_state_next  <= writeCacheEntry;
              flush_return_state_next <= readNewCacheEntry;
              next_state              <= flushOutCacheEntry;
            else
              read_return_state_next  <= writeCacheEntry;
              flush_return_state_next <= readNewCacheEntry;
              next_state              <= readNewCacheEntry;
            end if;
          end if;
        elsif flush_req = '1' then

          -- we need to flush the cache line, and trigger a flush in the
          -- downstream cache

          flush_return_state_next <= flushDownstreamCache;
          next_state              <= flushOutCacheEntry;

        end if;
      when flushOutCacheEntry =>
        wr_data_ds <= sel_cache_line(CACHE_LINE_LAST_DATA_BIT downto CACHE_LINE_FIRST_DATA_BIT);
        wr_req_ds  <= '1';

        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)                       <= cache_tag;
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT) <= sel_cache_line_idx;

        if (wr_ready_ds = '1') then
          next_state <= flush_return_state;
        end if;

      when readNewCacheEntry =>

        address_ds(ADDRESS_WIDTH - 1 downto CACHE_LINE_WIDTH_BITS) <=
          address(ADDRESS_WIDTH - 1 downto CACHE_LINE_WIDTH_BITS);

        rd_req_ds <= '1';

        if (rd_ready_ds = '1') then

          cache_wr <= '1';

          sel_cache_line_next(CACHE_LINE_LAST_DATA_BIT downto CACHE_LINE_FIRST_DATA_BIT) <= rd_data_ds;
          sel_cache_line_next(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT)   <= std_logic_vector(sel_tag);
          sel_cache_line_next(CACHE_LINE_VALID_BIT)                                      <= '1';
          sel_cache_line_next(CACHE_LINE_DIRTY_BIT)                                      <= '0';

          next_state <= read_return_state;  -- if we return to idle, read_ready will
        -- be set on next cycle
        end if;

      when writeCacheEntry =>

        cache_wr <= '1';

        -- get data to write
        if (data_sel = '0') then
          sel_cache_line_next <= create_cache_line_from_byte(sel_cache_line, wr_data(BYTE_WIDTH - 1 downto 0), sel_byte);
        else
          sel_cache_line_next <= create_cache_line_from_word(sel_cache_line, wr_data(WORD_WIDTH - 1 downto 0), sel_word);
        end if;

        sel_cache_line_next(CACHE_LINE_DIRTY_BIT) <= '1';
        next_state                                <= idle;

        wr_ready <= '1';

      when flushDownstreamCache =>

        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)                       <= cache_tag;
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT) <= sel_cache_line_idx;

        flush_req_ds <= '1';

        if (flush_done_ds = '1') then
          next_state <= idle;
          flush_done <= '1';
        end if;

      when others =>
        next_state <= idle;
    end case;
  end process;

end RTL;
