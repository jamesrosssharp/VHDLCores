--
--      BlockRamMemoryController : memory controller for block ram
--      
--      Memory template defined externally and mapped to external memory ports.
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity BlockRamMemoryController is
  generic (
    ADDRESS_WIDTH    : natural := 12;   -- 4096 word memory
    BR_ADDRESS_WIDTH : natural := 4;    -- 16 word memory
    WORD_WIDTH       : natural := 16;
    BURST_SIZE_BITS  : natural := 4
    );
  port (

    clk   : in std_logic;
    reset : in std_logic;

    address    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    -- burst size is number of words to read - 1, e.g. 1111 = 15 = 16 words
    burst_size : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req     : in  std_logic;
    rd_req     : in  std_logic;
    wr_grant   : out std_logic;
    rd_grant   : out std_logic;
    wr_done    : out std_logic;
    n_rd       : in  std_logic;
    n_wr       : in  std_logic;

    br_address : out natural range 0 to 2**BR_ADDRESS_WIDTH - 1;
    br_wr_data : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    br_rd_data : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    br_wr      : out std_logic

    );
end BlockRamMemoryController;

architecture RTL of BlockRamMemoryController is

  type state_t is (idle, read_data, write_data);

  signal state, next_state                   : state_t := idle;
  signal sig_br_address, sig_br_address_next : natural range 0 to 2**BR_ADDRESS_WIDTH - 1;

  signal burst_idx, burst_idx_next : natural range 0 to 2**BURST_SIZE_BITS - 1;
   
begin

  br_address <= sig_br_address;

  process (clk, reset)
  begin
    if reset = '1' then
      state          <= idle;
      sig_br_address <= 0;
      burst_idx <= 0;
	 elsif rising_edge(clk) then
      state          <= next_state;
      sig_br_address <= sig_br_address_next;
      burst_idx <= burst_idx_next;
    end if;
  end process;

  rd_data <= br_rd_data;
  br_wr_data <= wr_data;
  
  process (wr_data, burst_size, wr_req, rd_req, n_rd, n_wr, br_rd_data, 
			  sig_br_address, burst_idx, state, address)
  begin

    next_state          <= state;
    sig_br_address_next <= sig_br_address;
    burst_idx_next <= burst_idx;
	 
    rd_grant <= '0';
    wr_grant <= '0';
    br_wr <= '0';
	 wr_done <= '0';
    
    case state is
      when idle =>
        if rd_req = '1' then
          sig_br_address_next <= to_integer(address(BR_ADDRESS_WIDTH - 1 downto 0));
          next_state          <= read_data;
		  elsif wr_req = '1' then
          sig_br_address_next <= to_integer(address(BR_ADDRESS_WIDTH - 1 downto 0));
          next_state          <= write_data;
        end if;
      when read_data =>
		  rd_grant <= '1';
		  if n_rd = '0' then
          sig_br_address_next <= sig_br_address + 1;
		  end if;
		  if rd_req = '0' then
          next_state <= idle;
        end if;
      when write_data =>
        wr_grant <= '1';
        if n_wr = '0' then
          sig_br_address_next <= sig_br_address + 1;
          burst_idx_next <= burst_idx + 1;
          br_wr <= '1';
        end if;

        if burst_idx = to_integer(unsigned(burst_size)) then
          wr_done <= '1';
        end if;

        if wr_req = '0' then
          next_state <= idle;
        end if;

      when others =>
        next_state <= idle;
    end case;
  end process;

end RTL;
