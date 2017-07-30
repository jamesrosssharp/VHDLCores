--
--      Fifo implemented using ring buffer
--
--              See Chu, "FPGA Prototyping by VHDL Examples"
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Fifo is
  generic (
    DEPTH : INTEGER;  -- FIFO is 2**DEPTH deep        
    BITS  : INTEGER
    );
  port (
    CLK     : IN  STD_LOGIC;
    nRST    : IN  STD_LOGIC;
    WR_DATA : IN  STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
    n_WR    : IN  STD_LOGIC;
    RD_DATA : OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
    n_RD    : IN  STD_LOGIC;
    full    : OUT STD_LOGIC;
    empty   : OUT STD_LOGIC
    ); 
end Fifo;

architecture RTL of Fifo is

  type FIFO_ARRAY is array(0 to 2**DEPTH - 1) of STD_LOGIC_VECTOR (BITS - 1 downto 0);

  signal ring_buffer : FIFO_ARRAY;

  signal wr_ptr : unsigned (DEPTH - 1 downto 0);
  signal rd_ptr : unsigned (DEPTH - 1 downto 0);

  signal wr_ptr_next : unsigned (DEPTH - 1 downto 0);
  signal rd_ptr_next : unsigned (DEPTH - 1 downto 0);

  signal wr_ptr_succ : unsigned (DEPTH - 1 downto 0);
  signal rd_ptr_succ : unsigned (DEPTH - 1 downto 0);

  signal sig_full  : STD_LOGIC;
  signal sig_empty : STD_LOGIC;

  signal sig_full_next  : STD_LOGIC := '0';
  signal sig_empty_next : STD_LOGIC := '1';

  signal wr_en : STD_LOGIC;

  signal n_rdwr : STD_LOGIC_VECTOR (1 downto 0);
  
begin

  process (CLK, nRST)
  begin

    if (nRST = '0') then
      
      for i in ring_buffer'range loop
        ring_buffer(i) <= (others => '0');
      end loop;

      wr_ptr <= to_unsigned(0, DEPTH);
      rd_ptr <= to_unsigned(0, DEPTH);

      sig_empty <= '1';
      sig_full  <= '0';
      
    elsif CLK'event and CLK = '1' then
      
      if (wr_en = '1') then
        ring_buffer(to_integer(wr_ptr)) <= WR_DATA;
      end if;

      wr_ptr <= wr_ptr_next;
      rd_ptr <= rd_ptr_next;

      sig_empty <= sig_empty_next;
      sig_full  <= sig_full_next;
      
    end if;
    
  end process;

  RD_DATA <= ring_buffer(to_integer(rd_ptr));
  wr_en   <= not n_WR and not sig_full;

  wr_ptr_succ <= wr_ptr + 1;
  rd_ptr_succ <= rd_ptr + 1;

  n_rdwr <= n_WR & n_RD;

  process (n_rdwr, rd_ptr, wr_ptr, sig_empty, sig_full, wr_ptr_succ, rd_ptr_succ)
  begin
    
    wr_ptr_next <= wr_ptr;
    rd_ptr_next <= rd_ptr;

    sig_empty_next <= sig_empty;
    sig_full_next  <= sig_full;

    case n_rdwr is
      when "11" =>
        null;
      when "10" =>    -- read
        
        if (sig_empty = '0') then
          
          sig_full_next <= '0';
          rd_ptr_next   <= rd_ptr_succ;

          if (rd_ptr_succ = wr_ptr) then
            sig_empty_next <= '1';
          end if;
          
        end if;
        
      when "01" =>    -- write
        
        if (sig_full = '0') then
          
          sig_empty_next <= '0';

          wr_ptr_next <= wr_ptr_succ;

          if (wr_ptr_succ = rd_ptr) then
            sig_full_next <= '1';
          end if;
          
        end if;
        
      when others =>  -- read / write
        
        wr_ptr_next <= wr_ptr_succ;
        rd_ptr_next <= rd_ptr_succ;
        
    end case;
    
  end process;


  empty <= sig_empty;
  full  <= sig_full;

end RTL;
