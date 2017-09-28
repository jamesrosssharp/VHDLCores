--
--      EightPortMemoryController :  control memories with priority
--      scheme
--
--      8 ports, memory space split into 3 : 1 half and 2 quarters, with address
--      decoding to select downstream memory.
--             
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity EightPortMemoryController is
  generic (
    ADDRESS_WIDTH   : natural := 23;
    WORD_WIDTH      : natural := 16;
    BURST_SIZE_BITS : natural := 4
    );
  port (

    clk          : in std_logic;
    reset        : in std_logic;

    address_1    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_1    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_1    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_1 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_1     : in  std_logic;
    rd_req_1     : in  std_logic;
    wr_grant_1   : out std_logic;
    rd_grant_1   : out std_logic;
    wr_done_1    : out std_logic;
    n_rd_1       : in  std_logic;
    n_wr_1       : in  std_logic;

    address_2    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_2    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_2    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_2 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_2     : in  std_logic;
    rd_req_2     : in  std_logic;
    wr_grant_2   : out std_logic;
    rd_grant_2   : out std_logic;
    wr_done_2    : out std_logic;
    n_rd_2       : in  std_logic;
    n_wr_2       : in  std_logic;

    address_3    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_3    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_3    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_3 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_3     : in  std_logic;
    rd_req_3     : in  std_logic;
    wr_grant_3   : out std_logic;
    rd_grant_3   : out std_logic;
    wr_done_3    : out std_logic;
    n_rd_3       : in  std_logic;
    n_wr_3       : in  std_logic;

    address_4    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_4    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_4    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_4 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_4     : in  std_logic;
    rd_req_4     : in  std_logic;
    wr_grant_4   : out std_logic;
    rd_grant_4   : out std_logic;
    wr_done_4    : out std_logic;
    n_rd_4       : in  std_logic;
    n_wr_4       : in  std_logic;

    address_5    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_5    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_5    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_5 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_5     : in  std_logic;
    rd_req_5     : in  std_logic;
    wr_grant_5   : out std_logic;
    rd_grant_5   : out std_logic;
    wr_done_5    : out std_logic;
    n_rd_5       : in  std_logic;
    n_wr_5       : in  std_logic;

    address_6    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_6    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_6    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_6 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_6     : in  std_logic;
    rd_req_6     : in  std_logic;
    wr_grant_6   : out std_logic;
    rd_grant_6   : out std_logic;
    wr_done_6    : out std_logic;
    n_rd_6       : in  std_logic;
    n_wr_6       : in  std_logic;

    address_7    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_7    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_7    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_7 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_7     : in  std_logic;
    rd_req_7     : in  std_logic;
    wr_grant_7   : out std_logic;
    rd_grant_7   : out std_logic;
    wr_done_7    : out std_logic;
    n_rd_7       : in  std_logic;
    n_wr_7       : in  std_logic;

    address_8    : in  unsigned (ADDRESS_WIDTH - 1 downto 0);
    wr_data_8    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    rd_data_8    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    burst_size_8 : in  std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    wr_req_8     : in  std_logic;
    rd_req_8     : in  std_logic;
    wr_grant_8   : out std_logic;
    rd_grant_8   : out std_logic;
    wr_done_8    : out std_logic;
    n_rd_8       : in  std_logic;
    n_wr_8       : in  std_logic;

    -- half address space mapped to ds port 1
    ds_address_1    : out unsigned (ADDRESS_WIDTH - 2 downto 0);
    ds_wr_data_1    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_rd_data_1    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_burst_size_1 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    ds_wr_req_1     : out std_logic;
    ds_rd_req_1     : out std_logic;
    ds_wr_grant_1   : in  std_logic;
    ds_rd_grant_1   : in  std_logic;
    ds_wr_done_1    : in  std_logic;
    ds_n_rd_1       : out std_logic;
    ds_n_wr_1       : out std_logic;

    -- one quarter address space mapped to each of ds ports 2 and 3
    ds_address_2    : out unsigned (ADDRESS_WIDTH - 3 downto 0);
    ds_wr_data_2    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_rd_data_2    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_burst_size_2 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    ds_wr_req_2     : out std_logic;
    ds_rd_req_2     : out std_logic;
    ds_wr_grant_2   : in  std_logic;
    ds_rd_grant_2   : in  std_logic;
    ds_wr_done_2    : in  std_logic;
    ds_n_rd_2       : out std_logic;
    ds_n_wr_2       : out std_logic;

    ds_address_3    : out unsigned (ADDRESS_WIDTH - 3 downto 0);
    ds_wr_data_3    : out std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_rd_data_3    : in  std_logic_vector (WORD_WIDTH - 1 downto 0);
    ds_burst_size_3 : out std_logic_vector(BURST_SIZE_BITS - 1 downto 0);
    ds_wr_req_3     : out std_logic;
    ds_rd_req_3     : out std_logic;
    ds_wr_grant_3   : in  std_logic;
    ds_rd_grant_3   : in  std_logic;
    ds_wr_done_3    : in  std_logic;
    ds_n_rd_3       : out std_logic;
    ds_n_wr_3       : out std_logic

    );
end EightPortMemoryController;

architecture RTL of EightPortMemoryController is

  type state_t is (idle, read_port_1, write_port_1,
                   read_port_2, write_port_2,
                   read_port_3, write_port_3,
                   read_port_4, write_port_4,
                   read_port_5, write_port_5,
                   read_port_6, write_port_6,
                   read_port_7, write_port_7,
                   read_port_8, write_port_8);

  signal state, next_state : state_t := idle;
  
  signal sel_address : unsigned(ADDRESS_WIDTH - 1 downto 0);
  signal sel_rd_data : std_logic_vector(WORD_WIDTH - 1 downto 0);

  signal sel_wr_grant : std_logic;
  signal sel_rd_grant : std_logic;
  signal sel_wr_done  : std_logic;

  signal sel_wr_data    : std_logic_vector (WORD_WIDTH - 1 downto 0);
  signal sel_burst_size : std_logic_vector (BURST_SIZE_BITS - 1 downto 0);
  signal sel_wr_req     : std_logic;
  signal sel_rd_req     : std_logic;
  signal sel_n_rd       : std_logic;
  signal sel_n_wr       : std_logic;


begin

  -- multiplex downstream ports

  process (sel_address,
           ds_rd_data_1, ds_wr_grant_1,  ds_rd_grant_1, ds_wr_done_1,
           ds_rd_data_2, ds_wr_grant_2,  ds_rd_grant_2, ds_wr_done_2,
           ds_rd_data_3, ds_wr_grant_3,  ds_rd_grant_3, ds_wr_done_3,
			  sel_wr_data,  sel_burst_size, sel_wr_req, 	  sel_rd_req, 
			  sel_wr_grant, sel_rd_grant,   sel_wr_done,   wr_data_1,
			  burst_size_1, n_rd_1, n_wr_1, address_1,     sel_rd_data,
			  wr_data_2, burst_size_2, n_rd_2, n_wr_2, address_2,
			  wr_data_3, burst_size_3, n_rd_3, n_wr_3, address_3,
			  wr_data_4, burst_size_4, n_rd_4, n_wr_4, address_4,
			  wr_data_5, burst_size_5, n_rd_5, n_wr_5, address_5,
			  wr_data_6, burst_size_6, n_rd_6, n_wr_6, address_6,
			  wr_data_7, burst_size_7, n_rd_7, n_wr_7, address_7,
			  wr_data_8, burst_size_8, n_rd_8, n_wr_8, address_8,
			  sel_n_rd, sel_n_wr
			  
           )
  begin

    sel_rd_data  <= (others => '0');
    sel_wr_grant <= '0';
    sel_rd_grant <= '0';
    sel_wr_done  <= '0';

    ds_address_1    <= (others => '0');
    ds_wr_data_1    <= (others => '0');
    ds_burst_size_1 <= (others => '0');
    ds_wr_req_1     <= '0';
    ds_rd_req_1     <= '0';
    ds_n_rd_1       <= '1';
    ds_n_wr_1       <= '1';

    ds_address_2    <= (others => '0');
    ds_wr_data_2    <= (others => '0');
    ds_burst_size_2 <= (others => '0');
    ds_wr_req_2     <= '0';
    ds_rd_req_2     <= '0';
    ds_n_rd_2       <= '1';
    ds_n_wr_2       <= '1';

    ds_address_3    <= (others => '0');
    ds_wr_data_3    <= (others => '0');
    ds_burst_size_3 <= (others => '0');
    ds_wr_req_3     <= '0';
    ds_rd_req_3     <= '0';
    ds_n_rd_3       <= '1';
    ds_n_wr_3       <= '1';

    if sel_address(ADDRESS_WIDTH - 1) = '1' then
      -- ds port 1
      ds_address_1    <= sel_address(ADDRESS_WIDTH - 2 downto 0);
      ds_wr_data_1    <= sel_wr_data;
      ds_burst_size_1 <= sel_burst_size;
      ds_wr_req_1     <= sel_wr_req;
      ds_rd_req_1     <= sel_rd_req;
      ds_n_rd_1       <= sel_n_rd;
      ds_n_wr_1       <= sel_n_wr;

      sel_rd_data  <= ds_rd_data_1;
      sel_wr_grant <= ds_wr_grant_1;
      sel_rd_grant <= ds_rd_grant_1;
      sel_wr_done  <= ds_wr_done_1;

    else

      if sel_address(ADDRESS_WIDTH - 2) = '1' then
        -- ds port 2

        ds_address_2    <= sel_address(ADDRESS_WIDTH - 3 downto 0);
        ds_wr_data_2    <= sel_wr_data;
        ds_burst_size_2 <= sel_burst_size;
        ds_wr_req_2     <= sel_wr_req;
        ds_rd_req_2     <= sel_rd_req;
        ds_n_rd_2       <= sel_n_rd;
        ds_n_wr_2       <= sel_n_wr;

        sel_rd_data  <= ds_rd_data_2;
        sel_wr_grant <= ds_wr_grant_2;
        sel_rd_grant <= ds_rd_grant_2;
        sel_wr_done  <= ds_wr_done_2;

      else
        -- ds port 3

        ds_address_3    <= sel_address(ADDRESS_WIDTH - 3 downto 0);
        ds_wr_data_3    <= sel_wr_data;
        ds_burst_size_3 <= sel_burst_size;
        ds_wr_req_3     <= sel_wr_req;
        ds_rd_req_3     <= sel_rd_req;
        ds_n_rd_3       <= sel_n_rd;
        ds_n_wr_3       <= sel_n_wr;

        sel_rd_data  <= ds_rd_data_3;
        sel_wr_grant <= ds_wr_grant_3;
        sel_rd_grant <= ds_rd_grant_3;
        sel_wr_done  <= ds_wr_done_3;

      end if;

    end if;

  end process;

  -- synchronous transitions

  process (clk, reset)
  begin
    if reset = '1' then
      state <= idle;
    elsif rising_edge(clk) then
      state <= next_state;
    end if;
  end process;
    
  -- state machine

  process (rd_req_1, wr_req_1, rd_req_2, wr_req_2,
           rd_req_3, wr_req_3, rd_req_4, wr_req_4,
           rd_req_5, wr_req_5, rd_req_6, wr_req_6,
           rd_req_7, wr_req_7, rd_req_8, wr_req_8,
           state, sel_rd_data, sel_wr_grant, sel_wr_done,
			  wr_data_1, sel_rd_grant, burst_size_1, n_rd_1,
			  n_wr_1, address_1, 
			  wr_data_2, burst_size_2, n_rd_2, n_wr_2,
			  address_2,
			  wr_data_3, burst_size_3, n_rd_3, n_wr_3,
			  address_3,
			  wr_data_4, burst_size_4, n_rd_4, n_wr_4,
			  address_4,
			  wr_data_5, burst_size_5, n_rd_5, n_wr_5,
			  address_5,
			  wr_data_6, burst_size_6, n_rd_6, n_wr_6,
			  address_6,
			  wr_data_7, burst_size_7, n_rd_7, n_wr_7,
			  address_7,
			  wr_data_8, burst_size_8, n_rd_8, n_wr_8,
			  address_8
			  )
  begin

    rd_data_1    <= (others => '0');
    wr_grant_1   <= '0';
    rd_grant_1   <= '0';
    wr_done_1    <= '0';

    rd_data_2    <= (others => '0');
    wr_grant_2   <= '0';
    rd_grant_2   <= '0';
    wr_done_2    <= '0';

    rd_data_3    <= (others => '0');
    wr_grant_3   <= '0';
    rd_grant_3   <= '0';
    wr_done_3    <= '0';

    rd_data_4    <= (others => '0');
    wr_grant_4   <= '0';
    rd_grant_4   <= '0';
    wr_done_4    <= '0';

    rd_data_5    <= (others => '0');
    wr_grant_5   <= '0';
    rd_grant_5   <= '0';
    wr_done_5    <= '0';

    rd_data_6    <= (others => '0');
    wr_grant_6   <= '0';
    rd_grant_6   <= '0';
    wr_done_6    <= '0';

    rd_data_7    <= (others => '0');
    wr_grant_7   <= '0';
    rd_grant_7   <= '0';
    wr_done_7    <= '0';

    rd_data_8    <= (others => '0');
    wr_grant_8   <= '0';
    rd_grant_8   <= '0';
    wr_done_8    <= '0';

    sel_wr_data    <= (others => '0');
    sel_burst_size <= (others => '0');
    sel_wr_req     <= '0';
    sel_rd_req     <= '0';
    sel_n_rd       <= '1';
    sel_n_wr       <= '1';

    sel_address    <= (others => '0');

    next_state <= state;
    
    case state is
      when idle =>
        if rd_req_1 = '1' then
          next_state <= read_port_1;
        elsif wr_req_1 = '1' then
          next_state <= write_port_1;
        elsif rd_req_2 = '1' then
          next_state <= read_port_2;
        elsif wr_req_2 = '1' then
          next_state <= write_port_2;
        elsif rd_req_3 = '1' then
          next_state <= read_port_3;
        elsif wr_req_3 = '1' then
          next_state <= write_port_3;
        elsif rd_req_4 = '1' then
          next_state <= read_port_4;
        elsif wr_req_4 = '1' then
          next_state <= write_port_4;
        elsif rd_req_5 = '1' then
          next_state <= read_port_5;
        elsif wr_req_5 = '1' then
          next_state <= write_port_5;
        elsif rd_req_6 = '1' then
          next_state <= read_port_6;
        elsif wr_req_6 = '1' then
          next_state <= write_port_6;
        elsif rd_req_7 = '1' then
          next_state <= read_port_7;
        elsif wr_req_7 = '1' then
          next_state <= write_port_7;
		  elsif rd_req_8 = '1' then
          next_state <= read_port_8;
        elsif wr_req_8 = '1' then
          next_state <= write_port_8;
        end if;
      when read_port_1 =>
         rd_data_1    <= sel_rd_data;
         wr_grant_1   <= sel_wr_grant;
         rd_grant_1   <= sel_rd_grant;
         wr_done_1    <= sel_wr_done;
         sel_wr_data    <= wr_data_1;
         sel_burst_size <= burst_size_1;
         sel_wr_req     <= wr_req_1;
         sel_rd_req     <= rd_req_1;
         sel_n_rd       <= n_rd_1;
         sel_n_wr       <= n_wr_1;
         sel_address    <= address_1;
         if rd_req_1 = '0' then
           next_state <= idle;
         end if;
      when write_port_1 =>
         rd_data_1    <= sel_rd_data;
         wr_grant_1   <= sel_wr_grant;
         rd_grant_1   <= sel_rd_grant;
         wr_done_1    <= sel_wr_done;
         sel_wr_data    <= wr_data_1;
         sel_burst_size <= burst_size_1;
         sel_wr_req     <= wr_req_1;
         sel_rd_req     <= rd_req_1;
         sel_n_rd       <= n_rd_1;
         sel_n_wr       <= n_wr_1;
         sel_address    <= address_1;
         if wr_req_1 = '0' then
           next_state <= idle;
         end if;       
       when read_port_2 =>
         rd_data_2    <= sel_rd_data;
         wr_grant_2   <= sel_wr_grant;
         rd_grant_2   <= sel_rd_grant;
         wr_done_2    <= sel_wr_done;
         sel_wr_data    <= wr_data_2;
         sel_burst_size <= burst_size_2;
         sel_wr_req     <= wr_req_2;
         sel_rd_req     <= rd_req_2;
         sel_n_rd       <= n_rd_2;
         sel_n_wr       <= n_wr_2;
         sel_address    <= address_2;
         if rd_req_2 = '0' then
           next_state <= idle;
         end if;
      when write_port_2 =>
         rd_data_2    <= sel_rd_data;
         wr_grant_2   <= sel_wr_grant;
         rd_grant_2   <= sel_rd_grant;
         wr_done_2    <= sel_wr_done;
         sel_wr_data    <= wr_data_2;
         sel_burst_size <= burst_size_2;
         sel_wr_req     <= wr_req_2;
         sel_rd_req     <= rd_req_2;
         sel_n_rd       <= n_rd_2;
         sel_n_wr       <= n_wr_2;
         sel_address    <= address_2;
         if wr_req_2 = '0' then
           next_state <= idle;
         end if; 
      when read_port_3 =>
         rd_data_3    <= sel_rd_data;
         wr_grant_3   <= sel_wr_grant;
         rd_grant_3   <= sel_rd_grant;
         wr_done_3    <= sel_wr_done;
         sel_wr_data    <= wr_data_3;
         sel_burst_size <= burst_size_3;
         sel_wr_req     <= wr_req_3;
         sel_rd_req     <= rd_req_3;
         sel_n_rd       <= n_rd_3;
         sel_n_wr       <= n_wr_3;
         sel_address    <= address_3;
         if rd_req_3 = '0' then
           next_state <= idle;
         end if;
      when write_port_3 =>
         rd_data_3    <= sel_rd_data;
         wr_grant_3   <= sel_wr_grant;
         rd_grant_3   <= sel_rd_grant;
         wr_done_3    <= sel_wr_done;
         sel_wr_data    <= wr_data_3;
         sel_burst_size <= burst_size_3;
         sel_wr_req     <= wr_req_3;
         sel_rd_req     <= rd_req_3;
         sel_n_rd       <= n_rd_3;
         sel_n_wr       <= n_wr_3;
         sel_address    <= address_3;
         if wr_req_3 = '0' then
           next_state <= idle;
         end if; 
      when read_port_4 =>
         rd_data_4    <= sel_rd_data;
         wr_grant_4   <= sel_wr_grant;
         rd_grant_4   <= sel_rd_grant;
         wr_done_4    <= sel_wr_done;
         sel_wr_data    <= wr_data_4;
         sel_burst_size <= burst_size_4;
         sel_wr_req     <= wr_req_4;
         sel_rd_req     <= rd_req_4;
         sel_n_rd       <= n_rd_4;
         sel_n_wr       <= n_wr_4;
         sel_address    <= address_4;
         if rd_req_4 = '0' then
           next_state <= idle;
         end if;
      when write_port_4 =>
         rd_data_4    <= sel_rd_data;
         wr_grant_4   <= sel_wr_grant;
         rd_grant_4   <= sel_rd_grant;
         wr_done_4    <= sel_wr_done;
         sel_wr_data    <= wr_data_4;
         sel_burst_size <= burst_size_4;
         sel_wr_req     <= wr_req_4;
         sel_rd_req     <= rd_req_4;
         sel_n_rd       <= n_rd_4;
         sel_n_wr       <= n_wr_4;
         sel_address    <= address_4;
         if wr_req_4 = '0' then
           next_state <= idle;
         end if; 
      when read_port_5 =>
         rd_data_5    <= sel_rd_data;
         wr_grant_5   <= sel_wr_grant;
         rd_grant_5   <= sel_rd_grant;
         wr_done_5    <= sel_wr_done;
         sel_wr_data    <= wr_data_5;
         sel_burst_size <= burst_size_5;
         sel_wr_req     <= wr_req_5;
         sel_rd_req     <= rd_req_5;
         sel_n_rd       <= n_rd_5;
         sel_n_wr       <= n_wr_5;
         sel_address    <= address_5;
         if rd_req_5 = '0' then
           next_state <= idle;
         end if;
      when write_port_5 =>
         rd_data_5    <= sel_rd_data;
         wr_grant_5   <= sel_wr_grant;
         rd_grant_5   <= sel_rd_grant;
         wr_done_5    <= sel_wr_done;
         sel_wr_data    <= wr_data_5;
         sel_burst_size <= burst_size_5;
         sel_wr_req     <= wr_req_5;
         sel_rd_req     <= rd_req_5;
         sel_n_rd       <= n_rd_5;
         sel_n_wr       <= n_wr_5;
         sel_address    <= address_5;
         if wr_req_5 = '0' then
           next_state <= idle;
         end if; 
       when read_port_6 =>
         rd_data_6    <= sel_rd_data;
         wr_grant_6   <= sel_wr_grant;
         rd_grant_6   <= sel_rd_grant;
         wr_done_6    <= sel_wr_done;
         sel_wr_data    <= wr_data_6;
         sel_burst_size <= burst_size_6;
         sel_wr_req     <= wr_req_6;
         sel_rd_req     <= rd_req_6;
         sel_n_rd       <= n_rd_6;
         sel_n_wr       <= n_wr_6;
         sel_address    <= address_6;
         if rd_req_6 = '0' then
           next_state <= idle;
         end if;
      when write_port_6 =>
         rd_data_6    <= sel_rd_data;
         wr_grant_6   <= sel_wr_grant;
         rd_grant_6   <= sel_rd_grant;
         wr_done_6    <= sel_wr_done;
         sel_wr_data    <= wr_data_6;
         sel_burst_size <= burst_size_6;
         sel_wr_req     <= wr_req_6;
         sel_rd_req     <= rd_req_6;
         sel_n_rd       <= n_rd_6;
         sel_n_wr       <= n_wr_6;
         sel_address    <= address_6;
         if wr_req_6 = '0' then
           next_state <= idle;
         end if;
      when read_port_7 =>
         rd_data_7    <= sel_rd_data;
         wr_grant_7   <= sel_wr_grant;
         rd_grant_7   <= sel_rd_grant;
         wr_done_7    <= sel_wr_done;
         sel_wr_data    <= wr_data_7;
         sel_burst_size <= burst_size_7;
         sel_wr_req     <= wr_req_7;
         sel_rd_req     <= rd_req_7;
         sel_n_rd       <= n_rd_7;
         sel_n_wr       <= n_wr_7;
         sel_address    <= address_7;
         if rd_req_7 = '0' then
           next_state <= idle;
         end if;
      when write_port_7 =>
         rd_data_7    <= sel_rd_data;
         wr_grant_7   <= sel_wr_grant;
         rd_grant_7   <= sel_rd_grant;
         wr_done_7    <= sel_wr_done;
         sel_wr_data    <= wr_data_7;
         sel_burst_size <= burst_size_7;
         sel_wr_req     <= wr_req_7;
         sel_rd_req     <= rd_req_7;
         sel_n_rd       <= n_rd_7;
         sel_n_wr       <= n_wr_7;
         sel_address    <= address_7;
         if wr_req_7 = '0' then
           next_state <= idle;
         end if; 
       when read_port_8 =>
         rd_data_8    <= sel_rd_data;
         wr_grant_8   <= sel_wr_grant;
         rd_grant_8   <= sel_rd_grant;
         wr_done_8    <= sel_wr_done;
         sel_wr_data    <= wr_data_8;
         sel_burst_size <= burst_size_8;
         sel_wr_req     <= wr_req_8;
         sel_rd_req     <= rd_req_8;
         sel_n_rd       <= n_rd_8;
         sel_n_wr       <= n_wr_8;
         sel_address    <= address_8;
         if rd_req_8 = '0' then
           next_state <= idle;
         end if;
      when write_port_8 =>
         rd_data_8    <= sel_rd_data;
         wr_grant_8   <= sel_wr_grant;
         rd_grant_8   <= sel_rd_grant;
         wr_done_8    <= sel_wr_done;
         sel_wr_data    <= wr_data_8;
         sel_burst_size <= burst_size_8;
         sel_wr_req     <= wr_req_8;
         sel_rd_req     <= rd_req_8;
         sel_n_rd       <= n_rd_8;
         sel_n_wr       <= n_wr_8;
         sel_address    <= address_8;
         if wr_req_8 = '0' then
           next_state <= idle;
         end if; 
		end case;
  end process;

end RTL;
