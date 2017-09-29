--
--      DualPortBlockRamCache.vhd : configurable cache implemented in synchronous block ram
--
--      Cache is designed to be used as a standalone, dual-port cache. At best, single
--      cycle latency for reads (two cycles for writes)
--
--      Cache is dual port. If either port doesn't validate on read or write,
--      the cache will block and load the selected cacheline from memory.
--
--      
--      Downstream, designed to connect to a memory controller.
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DualPortBlockRamCache is
  generic (
    WORD_WIDTH_BITS       : natural := 4;   -- width of data, e.g 16 bit word
    BYTE_WIDTH_BITS       : natural := 3;   -- width of a byte
    ADDRESS_WIDTH         : natural := 24;  -- width of address bus
    CACHE_LINE_WIDTH_BITS : natural := 3;   -- number of bits used to represent
                                            -- cache line size in units of
                                            -- BYTE_WIDTH, e.g 3 -> 2**3 =
                                            -- 8 bytes
    CACHE_LINE_NUM_BITS   : natural := 9    -- E.g. 2**9 = 512 cache lines in
                                            -- L2 cache.
    );
  port (

    clk   : in std_logic;
    reset : in std_logic;

    wr_data_a  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
    rd_data_a  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
    data_sel_a : in  std_logic;         -- '1', address word (address must be
    -- aligned), '0' address byte

    rd_req_a       : in std_logic;
    wr_req_a       : in std_logic;
    flush_req      : in std_logic;  -- flush a single cache line that contains address
    invalidate_req : in std_logic;      -- invalidate entire cache.

    wr_data_b  : in  std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
    rd_data_b  : out std_logic_vector (2**WORD_WIDTH_BITS - 1 downto 0);
    data_sel_b : in  std_logic;         -- '1', address word (address must be
    -- aligned), '0' address byte

    rd_req_b : in std_logic;
    wr_req_b : in std_logic;

    bypass : in std_logic;              -- if '1' cache is bypassed, and L1/L2
    -- caches will be held in reset. If
    -- '0', cache is active and cache
    -- bypass logic will be held in reset.

    rd_ready_a : out std_logic;         -- '1' if cache hit
    wr_ready_a : out std_logic;         -- '1' when data will be written to
    -- cache on next rising edge of clock

    rd_ready_b : out std_logic;         -- '1' if cache hit
    wr_ready_b : out std_logic;         -- '1' when data will be written to
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
    wr_grant_ds   : in  std_logic;      -- request to write granted by memory
    -- controller, so words can now be written
    -- to memory controller
    rd_grant_ds   : in  std_logic;      -- request to read granted by memory
    -- controller, and words are ready to be read
    wr_done_ds    : in  std_logic;  -- write cycle completed by memory controller
    n_rd_ds       : out std_logic;      -- write a word to memory controller
    n_wr_ds       : out std_logic       -- read a word from memory controller

    );
end DualPortBlockRamCache;

architecture RTL of DualPortBlockRamCache is

  constant WORD_WIDTH : natural := 2**WORD_WIDTH_BITS;
  constant BYTE_WIDTH : natural := 2**BYTE_WIDTH_BITS;

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
  constant CACHE_LINE_WORD_BITS      : natural := (CACHE_LINE_WIDTH_BITS - (WORD_WIDTH_BITS - BYTE_WIDTH_BITS));

  constant ADDRESS_FIRST_BYTE_BIT           : natural := 0;
  constant ADDRESS_LAST_BYTE_BIT            : natural := CACHE_LINE_WIDTH_BITS - 1;
  constant ADDRESS_FIRST_WORD_BIT           : natural := (WORD_WIDTH / BYTE_WIDTH / 2);
  constant ADDRESS_LAST_WORD_BIT            : natural := CACHE_LINE_WIDTH_BITS - 1;
  constant ADDRESS_FIRST_CACHE_LINE_SEL_BIT : natural := ADDRESS_LAST_BYTE_BIT + 1;
  constant ADDRESS_LAST_CACHE_LINE_SEL_BIT  : natural :=
    ADDRESS_FIRST_CACHE_LINE_SEL_BIT + CACHE_LINE_NUM_BITS - 1;
  constant ADDRESS_FIRST_TAG_BIT : natural := ADDRESS_LAST_CACHE_LINE_SEL_BIT + 1;
  constant ADDRESS_LAST_TAG_BIT  : natural := ADDRESS_FIRST_TAG_BIT + TAG_WIDTH - 1;

  component DualPortBlockRamCacheMemoryTemplate is
    generic
      (
        DATA_WIDTH : natural := CACHE_LINE_SIZE_BITS;
        ADDR_WIDTH : natural := CACHE_LINE_NUM_BITS
        );
    port
      (
        clk    : in  std_logic;
        addr_a : in  natural range 0 to 2**ADDR_WIDTH - 1;
        addr_b : in  natural range 0 to 2**ADDR_WIDTH - 1;
        data_a : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        data_b : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        we_a   : in  std_logic := '1';
        we_b   : in  std_logic := '1';
        q_a    : out std_logic_vector((DATA_WIDTH -1) downto 0);
        q_b    : out std_logic_vector((DATA_WIDTH -1) downto 0)
        );
  end component;

  subtype cacheline_t is std_logic_vector(CACHE_LINE_SIZE_BITS - 1 downto 0);

  -- cache A
  signal sel_cacheline_a : cacheline_t;

  -- write sequentially (byte by byte) into this cacheline to prepare for write
  -- to cache
  signal cacheline_wr_data_a, cacheline_wr_data_a_next : cacheline_t;
  signal cacheline_wr_data_muxed_a                     : cacheline_t;

  -- wire directly into this for write to cacheline on cache hit
  signal cacheline_wr_data_a2 : cacheline_t;
  signal cacheline_mux_sel_a  : std_logic := '0';
  signal cacheline_wr_a       : std_logic := '0';

  -- cache B
  signal sel_cacheline_b : cacheline_t;

  signal cacheline_wr_data_b, cacheline_wr_data_b_next : cacheline_t;
  signal cacheline_wr_data_muxed_b                     : cacheline_t;
  signal cacheline_wr_data_b2                          : cacheline_t;
  signal cacheline_mux_sel_b                           : std_logic := '0';
  signal cacheline_wr_b                                : std_logic := '0';


  type state_t is (idle, resetCache,
                   flushOutCacheLine_a1, flushOutCacheLine_a2,
                   flushOutCacheLine_b1, flushOutCacheLine_b2,
                   readCacheLine_a1, readCacheLine_a2, readCacheLine_a2_wait,
						 readCacheLine_a3,
                   readCacheLine_b1, readCacheLine_b2, readCacheLine_b2_wait,
						 readCacheLine_b3,
                   invalidate0, invalidate1, invalidate2, invalidate3,
                   invalidate4);
  signal state, next_state : state_t := idle;

  signal flush_return_state, flush_return_state_next : state_t := idle;
  signal read_return_state, read_return_state_next   : state_t := idle;

  -- reset logic

  signal reset_address, reset_address_next : natural range 0 to 2**CACHE_LINE_NUM_BITS - 1;

  signal sel_cacheline_idx_a       : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal sel_cacheline_idx_a_nat   : natural range 0 to 2**CACHE_LINE_NUM_BITS - 1;
  signal sel_tag_a, cache_tag_a    : unsigned (TAG_WIDTH - 1 downto 0);
  signal sel_byte_a                : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal sel_word_a                : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);
  signal sel_cacheline_idx_mux_sel : std_logic;

  signal cache_valid_a, cache_dirty_a : std_logic;

  signal sel_cacheline_idx_b     : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal sel_cacheline_idx_b_nat : natural range 0 to 2**CACHE_LINE_NUM_BITS - 1;
  signal sel_tag_b, cache_tag_b  : unsigned (TAG_WIDTH - 1 downto 0);
  signal sel_byte_b              : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal sel_word_b              : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);

  signal cache_valid_b, cache_dirty_b : std_logic;

  -- these are 1 bit longer than ADDRESS_WIDTH, MSB is "valid" bit
  signal latch_address_a, latch_address_a_next : unsigned (ADDRESS_WIDTH downto 0);
  signal latch_address_b, latch_address_b_next : unsigned (ADDRESS_WIDTH downto 0);

  signal latch_cacheline_idx_a : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal latch_tag_a           : unsigned (TAG_WIDTH - 1 downto 0);
  signal latch_byte_a          : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal latch_word_a          : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);

  signal latch_cacheline_idx_b : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  signal latch_tag_b           : unsigned (TAG_WIDTH - 1 downto 0);
  signal latch_byte_b          : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0);
  signal latch_word_b          : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);

  signal wr_cycle_a, wr_cycle_a_next : std_logic;
  signal wr_cycle_b, wr_cycle_b_next : std_logic;

  signal cache_read_word, cache_read_word_next : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);
  constant TERMINAL_CACHE_READ_WORD            : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0) := (others => '1');

  signal invalidate_word, invalidate_word_next : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0);
  constant TERMINAL_INVALIDATE_WORD            : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0) := (others => '1');

  signal invalidate_line, invalidate_line_next : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0);
  constant TERMINAL_INVALIDATE_LINE            : unsigned (CACHE_LINE_NUM_BITS - 1 downto 0) := (others => '1');

  function write_word_to_next_cacheline (cache_line : cacheline_t;
                                         word       : std_logic_vector (WORD_WIDTH - 1 downto 0);
                                         sel_word   : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0))
    return cacheline_t is
    variable cache_line_next : cacheline_t;
  begin

    cache_line_next := cache_line;

    for i in 0 to 2**CACHE_LINE_WORD_BITS - 1 loop
      if i = to_integer(sel_word) then
        cache_line_next(WORD_WIDTH*(i+1) - 1 downto WORD_WIDTH*i) := word;
      end if;
    end loop;

    return cache_line_next;

  end function write_word_to_next_cacheline;

  function write_byte_to_next_cacheline (cache_line : cacheline_t;
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

  end function write_byte_to_next_cacheline;

  function read_word_from_cacheline (cache_line : cacheline_t;
                                     sel_word   : unsigned (CACHE_LINE_WORD_BITS - 1 downto 0))
    return std_logic_vector is
    variable word : std_logic_vector (WORD_WIDTH - 1 downto 0);
  begin

    for i in 0 to 2**CACHE_LINE_WORD_BITS - 1 loop
      if i = to_integer(sel_word) then
        word := cache_line(WORD_WIDTH*(i+1) - 1 downto WORD_WIDTH*i);
      end if;
    end loop;

    return word;

  end function read_word_from_cacheline;

  function read_byte_from_cacheline (cache_line : cacheline_t;
                                     sel_byte   : unsigned (CACHE_LINE_WIDTH_BITS - 1 downto 0))
    return std_logic_vector is
    variable byte : std_logic_vector (BYTE_WIDTH - 1 downto 0);
  begin
    for i in 0 to 2**CACHE_LINE_WIDTH_BITS - 1 loop
      if i = to_integer(sel_byte) then
        byte := cache_line(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i);
      end if;
    end loop;
    return byte;
  end function read_byte_from_cacheline;

begin

  ram0 : DualPortBlockRamCacheMemoryTemplate
    port map
    (
      clk    => clk,
      addr_a => sel_cacheline_idx_a_nat,
      addr_b => sel_cacheline_idx_b_nat,
      data_a => cacheline_wr_data_muxed_a,
      data_b => cacheline_wr_data_muxed_b,
      we_a   => cacheline_wr_a,
      we_b   => cacheline_wr_b,
      q_a    => sel_cacheline_a,
      q_b    => sel_cacheline_b
      );

  sel_cacheline_idx_a_nat <= to_integer(sel_cacheline_idx_a) when sel_cacheline_idx_mux_sel = '0' else
                             to_integer(invalidate_line);
  sel_cacheline_idx_b_nat <= to_integer(sel_cacheline_idx_b);

  process (clk, reset)
  begin
    if (reset = '1') then
      state <= idle;

      latch_address_a <= (others => '0');
      latch_address_b <= (others => '0');

      wr_cycle_a          <= '0';
      wr_cycle_b          <= '0';
      cache_read_word     <= (others => '0');
      cacheline_wr_data_a <= (others => '0');
      cacheline_wr_data_b <= (others => '0');
      invalidate_word     <= (others => '0');
      invalidate_line     <= (others => '0');

    elsif rising_edge(clk) then
      state <= next_state;

      latch_address_a <= latch_address_a_next;
      latch_address_b <= latch_address_b_next;

      wr_cycle_a          <= wr_cycle_a_next;
      wr_cycle_b          <= wr_cycle_b_next;
      cache_read_word     <= cache_read_word_next;
      cacheline_wr_data_a <= cacheline_wr_data_a_next;
      cacheline_wr_data_b <= cacheline_wr_data_b_next;
      invalidate_word     <= invalidate_word_next;
      invalidate_line     <= invalidate_line_next;

    end if;
  end process;

  cacheline_wr_data_muxed_a <= cacheline_wr_data_a when cacheline_mux_sel_a = '1' else cacheline_wr_data_a2;
  cacheline_wr_data_muxed_b <= cacheline_wr_data_b when cacheline_mux_sel_b = '1' else cacheline_wr_data_b2;

  sel_cacheline_idx_a <= address_a(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  sel_tag_a           <= address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  sel_byte_a          <= address_a(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  sel_word_a          <= address_a(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  latch_cacheline_idx_a <= latch_address_a(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  latch_tag_a           <= latch_address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  latch_byte_a          <= latch_address_a(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  latch_word_a          <= latch_address_a(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  cache_tag_a   <= unsigned(sel_cacheline_a(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT));
  cache_valid_a <= sel_cacheline_a(CACHE_LINE_VALID_BIT);
  cache_dirty_a <= sel_cacheline_a(CACHE_LINE_DIRTY_BIT);

  sel_cacheline_idx_b <= address_b(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  sel_tag_b           <= address_b(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  sel_byte_b          <= address_b(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  sel_word_b          <= address_b(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  latch_cacheline_idx_b <= latch_address_b(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
  latch_tag_b           <= latch_address_b(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT);
  latch_byte_b          <= latch_address_b(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT);
  latch_word_b          <= latch_address_b(ADDRESS_LAST_WORD_BIT downto ADDRESS_FIRST_WORD_BIT);

  cache_tag_b   <= unsigned(sel_cacheline_b(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT));
  cache_valid_b <= sel_cacheline_b(CACHE_LINE_VALID_BIT);
  cache_dirty_b <= sel_cacheline_b(CACHE_LINE_DIRTY_BIT);


  process (state, rd_req_a, rd_req_b, wr_req_a, wr_req_b, latch_address_a, latch_address_b,
           wr_cycle_a, rd_grant_ds, wr_grant_ds, cache_read_word, cacheline_wr_data_a, rd_data_ds,
           address_a, latch_tag_a, sel_tag_a, data_sel_a, sel_cacheline_a, latch_byte_a, latch_word_a,
           cache_valid_a, cache_dirty_a, wr_data_a, cache_tag_a, invalidate_word, invalidate_line,
           latch_cacheline_idx_a, sel_cacheline_idx_a, invalidate_req,
           wr_cycle_b, cacheline_wr_data_b,
           address_b, latch_tag_b, sel_tag_b, data_sel_b, sel_cacheline_b, latch_byte_b, latch_word_b,
           cache_valid_b, cache_dirty_b, wr_data_b, cache_tag_b,
           latch_cacheline_idx_b, sel_cacheline_idx_b)
  begin

    rd_ready_a <= '0';
    rd_ready_b <= '0';

    latch_address_a_next <= latch_address_a;
    latch_address_b_next <= latch_address_b;

    latch_address_a_next(ADDRESS_WIDTH) <= '0';
    latch_address_b_next(ADDRESS_WIDTH) <= '0';

    wr_cycle_a_next <= '0';
    wr_cycle_b_next <= '0';

    cacheline_wr_a      <= '0';
    cacheline_mux_sel_a <= '0';

    cacheline_wr_b      <= '0';
    cacheline_mux_sel_b <= '0';

    rd_data_a <= (others => '0');
    rd_data_b <= (others => '0');

    next_state <= state;

    cache_read_word_next <= (others => '0');

    cacheline_wr_data_a_next <= cacheline_wr_data_a;
    cacheline_wr_data_a2     <= (others => '0');
    wr_ready_a               <= '0';

    cacheline_wr_data_b_next <= cacheline_wr_data_b;
    cacheline_wr_data_b2     <= (others => '0');
    wr_ready_b               <= '0';

    wr_req_ds  <= '0';
    flush_done <= '0';
    rd_req_ds  <= '0';
    n_rd_ds    <= '1';
    wr_data_ds <= (others => '0');
    n_wr_ds    <= '1';

    address_ds <= (others => '0');

    invalidate_word_next <= invalidate_word;
    invalidate_line_next <= invalidate_line;
    invalidate_done      <= '0';

    sel_cacheline_idx_mux_sel <= '0';

    --
    --  When idle and read request, latch address. Block ram will read through.
    --  Add a bit to latched address. (This guards against cache miss when no
    --  data has been fetched from BRAM yet). When '1', address is latched, when '0' no
    --  address latched yet. If address latched, and latch_address_a_next tag
    --  matches tag in cacheline, then rd_ready <= '1', else move to
    --  flushOutCacheLine state.  
    --
    --  B takes precedence over A, write takes precedence over read.
    --

    case state is
      when idle =>

        if invalidate_req = '1' then
          next_state <= invalidate0;
        else

          -- if read request on a
          if (rd_req_a = '1') then
            latch_address_a_next <= '1' & address_a;

            if (latch_address_a(ADDRESS_WIDTH) = '1') then
              if (cache_valid_a = '1' and latch_tag_a = cache_tag_a) then
                rd_ready_a <= '1';
                                        -- output data
                if (data_sel_a = '0') then
                                        -- byte selected
                  rd_data_a(BYTE_WIDTH - 1 downto 0) <= read_byte_from_cacheline(sel_cacheline_a, latch_byte_a);
                else
                                        -- word selected
                  rd_data_a <= read_word_from_cacheline(sel_cacheline_a, latch_word_a);
                end if;
              else
                if (cache_valid_a = '1' and cache_dirty_a = '1') then
                  next_state <= flushOutCacheLine_a1;
                else
                  next_state <= readCacheLine_a1;
                end if;
              end if;
            end if;
          -- if write request on a
          elsif (wr_req_a = '1') then

            if (wr_cycle_a = '0') then
              latch_address_a_next <= '0' & address_a;
              wr_cycle_a_next      <= '1';
            else
              if (cache_valid_a = '1' and latch_tag_a = cache_tag_a) then
                                        -- write data

                if (data_sel_a = '0') then
                                        -- byte access
                  cacheline_wr_data_a2 <= write_byte_to_next_cacheline(sel_cacheline_a,
                                                                       wr_data_a(BYTE_WIDTH - 1 downto 0), latch_byte_a);
                else
                                        -- word access
                  cacheline_wr_data_a2 <= write_word_to_next_cacheline(sel_cacheline_a, wr_data_a, latch_word_a);
                end if;

                cacheline_wr_data_a2(CACHE_LINE_DIRTY_BIT) <= '1';
                cacheline_wr_a                             <= '1';
                wr_ready_a                                 <= '1';
              else
                if (cache_valid_a = '1' and cache_dirty_a = '1') then
                  next_state <= flushOutCacheLine_a1;
                else
                  next_state <= readCacheLine_a1;
                end if;
              end if;
            end if;
          end if;

          -- if read request on b
          if (rd_req_b = '1') then
            latch_address_b_next <= '1' & address_b;

            if (latch_address_b(ADDRESS_WIDTH) = '1') then
              if (cache_valid_b = '1' and latch_tag_b = cache_tag_b) then
                rd_ready_b <= '1';
                                        -- output data
                if (data_sel_b = '0') then
                                        -- byte selected
                  rd_data_b(BYTE_WIDTH - 1 downto 0) <= read_byte_from_cacheline(sel_cacheline_b, latch_byte_b);
                else
                                        -- word selected
                  rd_data_b <= read_word_from_cacheline(sel_cacheline_b, latch_word_b);
                end if;
              else
                if (cache_valid_b = '1' and cache_dirty_b = '1') then
                  next_state <= flushOutCacheLine_b1;
                else
                  next_state <= readCacheLine_b1;
                end if;
              end if;
            end if;
          -- if write request on b
          elsif (wr_req_b = '1') then

            if (wr_cycle_b = '0') then
              latch_address_b_next <= '0' & address_b;
              wr_cycle_b_next      <= '1';
            else
              if (cache_valid_b = '1' and latch_tag_b = cache_tag_b) then
                                        -- write data

                if (data_sel_b = '0') then
                                        -- byte access
                  cacheline_wr_data_b2 <= write_byte_to_next_cacheline(sel_cacheline_b,
                                                                       wr_data_b(BYTE_WIDTH - 1 downto 0), latch_byte_b);
                else
                                        -- word access
                  cacheline_wr_data_b2 <= write_word_to_next_cacheline(sel_cacheline_b, wr_data_b, latch_word_b);
                end if;

                cacheline_wr_data_b2(CACHE_LINE_DIRTY_BIT) <= '1';
                cacheline_wr_b                             <= '1';
                wr_ready_b                                 <= '1';
              else
                if (cache_valid_b = '1' and cache_dirty_b = '1') then
                  next_state <= flushOutCacheLine_b1;
                else
                  next_state <= readCacheLine_b1;
                end if;
              end if;
            end if;
          end if;

        -- TODO: write request on B
        end if;

      -- Flush states
      when flushOutCacheLine_a1 =>
        wr_req_ds <= '1';
        if (wr_grant_ds = '1') then
          next_state <= flushOutCacheLine_a2;
        end if;
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
          <= cache_tag_a(TAG_WIDTH - 1 downto 0);
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_cacheline_idx_a;

      when flushOutCacheLine_a2 =>
        wr_req_ds  <= '1';
        n_wr_ds    <= '0';
        wr_data_ds <= read_word_from_cacheline(sel_cacheline_a, cache_read_word);
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
          <= cache_tag_a(TAG_WIDTH - 1 downto 0);
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_cacheline_idx_a;
        cache_read_word_next <= cache_read_word + 1;
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          flush_done <= '1';
          next_state <= readCacheLine_a1;
        end if;
      -- Read states 
      when readCacheLine_a1 =>
        rd_req_ds <= '1';
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
        if (rd_grant_ds = '1') then
          next_state <= readCacheLine_a2_wait;
        end if;
		when readCacheLine_a2_wait =>
			rd_req_ds <= '1';
			n_rd_ds <= '0';
			 address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
			next_state <= readCacheLine_a2;
      when readCacheLine_a2 =>
        rd_req_ds            <= '1';
        cache_read_word_next <= cache_read_word + 1;
        n_rd_ds              <= '0';
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          next_state <= readCacheLine_a3;
        end if;
        cacheline_wr_data_a_next <=
          write_word_to_next_cacheline(cacheline_wr_data_a, rd_data_ds, cache_read_word);
        cacheline_wr_data_a_next(CACHE_LINE_VALID_BIT) <= '1';
        cacheline_wr_data_a_next(CACHE_LINE_DIRTY_BIT) <= '0';
        cacheline_wr_data_a_next(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT)
          <= std_logic_vector(sel_tag_a);

      when readCacheLine_a3 =>
        cacheline_wr_a      <= '1';
        cacheline_mux_sel_a <= '1';
        next_state          <= idle;

      when flushOutCacheLine_b1 =>
        wr_req_ds <= '1';
        if (wr_grant_ds = '1') then
          next_state <= flushOutCacheLine_b2;
        end if;
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
          <= cache_tag_b(TAG_WIDTH - 1 downto 0);
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_cacheline_idx_b;

      when flushOutCacheLine_b2 =>
        wr_req_ds  <= '1';
        n_wr_ds    <= '0';
        wr_data_ds <= read_word_from_cacheline(sel_cacheline_b, cache_read_word);
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
          <= cache_tag_b(TAG_WIDTH - 1 downto 0);
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_cacheline_idx_b;
        cache_read_word_next <= cache_read_word + 1;
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          flush_done <= '1';
          next_state <= readCacheLine_b1;
        end if;
      -- Read states 
      when readCacheLine_b1 =>
        rd_req_ds <= '1';
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_b(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
        if (rd_grant_ds = '1') then
          next_state <= readCacheLine_b2_wait;
        end if;
	when readCacheLine_b2_wait =>
			rd_req_ds <= '1';
			n_rd_ds <= '0';
			address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_a(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
			next_state <= readCacheLine_b2;
	 when readCacheLine_b2 =>
        rd_req_ds            <= '1';
        cache_read_word_next <= cache_read_word + 1;
        n_rd_ds              <= '0';
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= latch_address_b(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT);
        if (cache_read_word = TERMINAL_CACHE_READ_WORD) then
          next_state <= readCacheLine_b3;
        end if;
        cacheline_wr_data_b_next <=
          write_word_to_next_cacheline(cacheline_wr_data_b, rd_data_ds, cache_read_word);
        cacheline_wr_data_b_next(CACHE_LINE_VALID_BIT) <= '1';
        cacheline_wr_data_b_next(CACHE_LINE_DIRTY_BIT) <= '0';
        cacheline_wr_data_b_next(CACHE_LINE_LAST_TAG_BIT downto CACHE_LINE_FIRST_TAG_BIT)
          <= std_logic_vector(sel_tag_b);

      when readCacheLine_b3 =>
        cacheline_wr_b      <= '1';
        cacheline_mux_sel_b <= '1';
        next_state          <= idle;

      when invalidate0 =>
        sel_cacheline_idx_mux_sel <= '1';
        -- clear line count
        invalidate_line_next      <= (others => '0');
        next_state                <= invalidate1;

      when invalidate1 =>
        sel_cacheline_idx_mux_sel <= '1';
        -- clear word count and 
        -- load cache line
        invalidate_word_next      <= (others => '0');
        next_state                <= invalidate2;
      when invalidate2 =>
        sel_cacheline_idx_mux_sel <= '1';

        if (cache_valid_a /= '1') then
          next_state <= invalidate4;
        else
          -- request write word to memory
          wr_req_ds <= '1';
          if (wr_grant_ds = '1') then
            next_state <= invalidate3;
          end if;
          address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
            <= cache_tag_a(TAG_WIDTH - 1 downto 0);
          address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
            <= invalidate_line;
        end if;
      when invalidate3 =>
        sel_cacheline_idx_mux_sel <= '1';
        -- write words to memory
        invalidate_word_next      <= invalidate_word + 1;

        if (invalidate_word = TERMINAL_INVALIDATE_WORD) then
          next_state <= invalidate4;
        end if;

        wr_req_ds  <= '1';
        n_wr_ds    <= '0';
        wr_data_ds <= read_word_from_cacheline(sel_cacheline_a, invalidate_word);
        address_ds(ADDRESS_LAST_TAG_BIT downto ADDRESS_FIRST_TAG_BIT)
          <= cache_tag_a(TAG_WIDTH - 1 downto 0);
        address_ds(ADDRESS_LAST_CACHE_LINE_SEL_BIT downto ADDRESS_FIRST_CACHE_LINE_SEL_BIT)
          <= invalidate_line;

      when invalidate4 =>
        sel_cacheline_idx_mux_sel <= '1';
        -- increment cache line count and loop back to invalidate1
        invalidate_line_next      <= invalidate_line + 1;

        if (invalidate_line = TERMINAL_INVALIDATE_LINE) then
          next_state      <= idle;
          invalidate_done <= '1';
        else
          next_state <= invalidate1;
        end if;
      when others =>

        next_state <= idle;

    end case;

  end process;

end RTL;
