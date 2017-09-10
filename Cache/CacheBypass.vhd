--
--      Cache bypass logic - allows direct memory access, bypassing the cache.
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity CacheBypass is
  generic (
    WORD_WIDTH    : natural := 16;      -- width of data, e.g 16 bit word
    BYTE_WIDTH    : natural := 8;       -- width of a byte
    ADDRESS_WIDTH : natural := 24       -- width of address bus
    );
  port (

    clk   : in std_logic;
    reset : in std_logic;

    wr_data  : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data  : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    data_sel : in  std_logic;           -- '1', address word (address must be
    -- aligned), '0' address byte

    rd_req : in std_logic;
    wr_req : in std_logic;

    rd_ready : out std_logic;           -- '1' if cache hit
    wr_ready : out std_logic;           -- '1' when data will be written to
    -- cache on next rising edge of clock

    address : in unsigned (ADDRESS_WIDTH - 1 downto 0);

    -- connection to memory controller

    address_ds    : out unsigned (ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH downto 0);
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
end CacheBypass;

architecture RTL of CacheBypass is

  --
  --    If idle and rd_req, read word from memory, latch, and proceed to outputword.
  --    In output word, latched data appears at rd_data, and byte is selected
  --    if data_sel is zero. rd_ready <= '1'
  --    If idle and wr_req and data_sel = '1', then write word directy. Else if
  --    data_sel = '0', then read the word, latch with appropriate byte, then
  --    proceed to writeWord, and write the word out.
  --

  type state_t is (idle, readWord, readWord2, outputWord, writeWord, writeWord2);
  signal state, next_state, read_return_state, read_return_state_next : state_t := idle;

  subtype word_t is std_logic_vector(WORD_WIDTH - 1 downto 0);
  signal read_word, read_word_next : word_t;

  --    if 16 and 8, last bit is bit 0.
  --    if 32 and 8, last bit is bit 1.
  constant ADDRESS_LAST_BYTE_BIT  : natural := WORD_WIDTH / BYTE_WIDTH / 2 - 1;
  constant ADDRESS_FIRST_BYTE_BIT : natural := 0;
  constant ADDRESS_NUM_BYTE_BITS  : natural := ADDRESS_LAST_BYTE_BIT - ADDRESS_FIRST_BYTE_BIT + 1;

  -- write_byte_to_rd_data

  function write_byte_to_rd_data (rd_data : word_t;
                                  wr_data : word_t;
                                 sel_byte   : unsigned (ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT))
    return std_logic_vector is
    variable word : std_logic_vector (WORD_WIDTH - 1 downto 0);
  begin
    word := rd_data;

    for i in 0 to 2**ADDRESS_NUM_BYTE_BITS - 1 loop
      if i = to_integer(sel_byte) then
        word(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) := wr_data(BYTE_WIDTH - 1 downto 0);
      end if;
    end loop;

    return word;
  
  end write_byte_to_rd_data;
  
  -- read_byte_from_rd_data

 function read_byte_from_rd_data (rd_data : word_t;
                                 sel_byte   : unsigned (ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT))
    return std_logic_vector is
    variable byte : std_logic_vector (BYTE_WIDTH - 1 downto 0);
  begin
    byte := (others => '0');

    for i in 0 to 2**ADDRESS_NUM_BYTE_BITS - 1 loop
      if i = to_integer(sel_byte) then
        byte(BYTE_WIDTH - 1 downto 0) := rd_data(BYTE_WIDTH*(i + 1) - 1 downto BYTE_WIDTH*i);
      end if;
    end loop;

    return byte;
    
  end read_byte_from_rd_data;
 
begin

  -- get word address
  address_ds <= address(ADDRESS_WIDTH - WORD_WIDTH / BYTE_WIDTH + 1 downto WORD_WIDTH / BYTE_WIDTH - 1);
  wr_data_ds <= read_word;

  -- single word bursts
  burst_size_ds <= "0001";

  process (clk, reset)
  begin
    if reset = '1' then
      state             <= idle;
      read_return_state <= idle;
      read_word         <= (others => '0');
    elsif rising_edge(clk) then
      state             <= next_state;
      read_return_state <= read_return_state_next;
      read_word         <= read_word_next;
    end if;
  end process;

  process (state, read_return_state, wr_done_ds, wr_grant_ds, rd_grant_ds, address,
			  rd_req, wr_req, data_sel, wr_data, rd_data_ds, read_word)
  begin

    next_state             <= state;
    read_return_state_next <= read_return_state;

    wr_req_ds <= '0';
    n_wr_ds   <= '1';
    rd_req_ds <= '0';
    n_rd_ds   <= '1';

    wr_ready <= '0';
    rd_ready  <= '0';
	 
	 rd_data <= (others => '0');
	 
	 read_word_next <= read_word;

    case state is
      when idle =>
        if rd_req = '1' then
          next_state             <= readWord;
          read_return_state_next <= outputWord;
        elsif wr_req = '1' then
          if data_sel = '1' then
            -- write complete word from wr_data to memory
            next_state     <= writeWord;
            read_word_next <= wr_data;
          else
            next_state             <= readWord;
            read_return_state_next <= writeWord;
          end if;
        end if;
      when readWord =>
        rd_req_ds <= '1';
        if (rd_grant_ds = '1') then
          next_state <= readWord2;
        end if;
      when readWord2 =>
        rd_req_ds <= '1';
        n_rd_ds     <= '0';

        if (wr_req = '1') then
          -- data sel must have been zero.
          -- map byte into read_word
          read_word_next <= write_byte_to_rd_data(rd_data_ds, wr_data,
                                                  address(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT));
        else
          read_word_next <= rd_data_ds;
        end if;
        next_state <= read_return_state;
      when outputWord =>
        if (data_sel = '0') then
          rd_data(BYTE_WIDTH - 1 downto 0)
            <= read_byte_from_rd_data(read_word, address(ADDRESS_LAST_BYTE_BIT downto ADDRESS_FIRST_BYTE_BIT));
        else
          rd_data <= read_word;
        end if;
        rd_ready <= '1';
        next_state <= idle;
      when writeWord =>
        wr_req_ds <= '1';
        if (wr_grant_ds = '1') then
          next_state <= writeWord2;
        end if;
      when writeWord2 =>
        wr_req_ds <= '1';
        n_wr_ds   <= '0';
        if (wr_done_ds = '1') then
          wr_ready   <= '1';
          next_state <= idle;
        end if;
      when others =>
        next_state <= idle;
    end case;

  end process;

end RTL;
