--
--
--      Synthesizable top level to test SDCardSPI on FPGA board 
--
-- Performs CMDs on card and prints responses to terminal using UART
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SDCardSPITester
is
  generic (
    CLOCK_FREQ : REAL := 50000000.0     -- frequency of driving clock
    );
  port (

    -- SD Card pins
    SD_DAT  : IN    STD_LOGIC;          -- MISO
    SD_CMD  : OUT   STD_LOGIC;          -- MOSI
    SD_CLK  : OUT   STD_LOGIC;          -- CLK
    SD_DAT3 : INOUT STD_LOGIC;          -- \CS / card present

    -- UART Pins
    UART_TXD : OUT STD_LOGIC;
    UART_RXD : IN  STD_LOGIC;

    -- main clock
    CLOCK_50 : IN STD_LOGIC;

    -- KEY[0] used as asynchronous reset 
    KEY : IN STD_LOGIC_VECTOR (3 DOWNTO 0)

    );
end SDCardSPITester;

architecture RTL of SDCardSPITester is

  -- SDCardSPI core

  --component SDCardSPI is
  --        generic (
  --                CLOCK_FREQ : REAL := CLOCK_FREQ
  --        );
  --        port (
  --                SD_DAT  : IN     STD_LOGIC;             -- MISO
  --                SD_CMD  : OUT    STD_LOGIC;             -- MOSI
  --                SD_CLK  : OUT    STD_LOGIC;             -- CLK
  --                SD_DAT3 : INOUT  STD_LOGIC;              -- \CS / card present

  --                CLK     : IN   STD_LOGIC;
  --                nRST    : IN   STD_LOGIC;

  --        );
  --end component;


  -- UART core
  
  component UART is
    generic (
      TX_FIFO_DEPTH : INTEGER;
      RX_FIFO_DEPTH : INTEGER
      );
    port (

      TX   : OUT STD_LOGIC;
      RX   : IN  STD_LOGIC;
      CLK  : IN  STD_LOGIC;
      nRST : IN  STD_LOGIC;

      -- Register interface (bus slave)

      WR_DATA : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
      RD_DATA : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);

      ADDR : IN STD_LOGIC_VECTOR (1 DOWNTO 0);  -- 4 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = CTRL, 3 = STATUS

      n_WR : IN STD_LOGIC;              -- active low, write to register 
      n_RD : IN STD_LOGIC               -- active low, read from register

      );
  end component;

  signal uart_wr_reg      : STD_LOGIC := '1';
  signal uart_wr_reg_next : STD_LOGIC := '1';

  signal uart_addr      : STD_LOGIC_VECTOR (1 DOWNTO 0);
  signal uart_addr_next : STD_LOGIC_VECTOR (1 DOWNTO 0);

  signal uart_wr_data      : STD_LOGIC_VECTOR (31 DOWNTO 0);
  signal uart_wr_data_next : STD_LOGIC_VECTOR (31 DOWNTO 0);

  signal uart_rd_reg      : STD_LOGIC := '1';
  signal uart_rd_reg_next : STD_LOGIC := '1';
  signal uart_rd_data     : STD_LOGIC_VECTOR (31 DOWNTO 0);

  signal n_uartRst : STD_LOGIC := '1';

  signal sd_wr_reg      : STD_LOGIC := '1';
  signal sd_wr_reg_next : STD_LOGIC := '1';

  signal sd_addr      : STD_LOGIC_VECTOR (1 DOWNTO 0);
  signal sd_addr_next : STD_LOGIC_VECTOR (1 DOWNTO 0);

  signal sd_wr_data      : STD_LOGIC_VECTOR (31 DOWNTO 0);
  signal sd_wr_data_next : STD_LOGIC_VECTOR (31 DOWNTO 0);

  signal sd_rd_reg      : STD_LOGIC := '1';
  signal sd_rd_reg_next : STD_LOGIC := '1';
  signal sd_rd_data     : STD_LOGIC_VECTOR (31 DOWNTO 0);

  signal n_sdRst : STD_LOGIC;
  
  type state_type is (reset, writeBanner, sendCMD0, sendCMD8, processCMD8Response,
                      sendCMD58, processCMD58Response, sendCMD55, processCMD55Response,
                      sendCMD41, processACMD41Response, sendCMD17, getBlockData, printRXData);                        

  signal state : state_type            := reset;
  signal count : unsigned (4 DOWNTO 0) := "00000";  -- counter used as sub-state

  signal next_state : state_type            := reset;
  signal next_count : unsigned (4 DOWNTO 0) := "00000";

  signal nRESET : STD_LOGIC := '1';

  function char_2_std_logic_vector(ch : character)
    return std_logic_vector is
    variable out_vector : std_logic_vector(7 downto 0);
  begin
    out_vector := std_logic_vector (to_unsigned(character'pos(ch), 8)); 
    return out_vector;
  end char_2_std_logic_vector;
    
begin
  
  u0 : UART
    generic map (TX_FIFO_DEPTH => 4,    -- 2**4 = 16 character FIFO
                 RX_FIFO_DEPTH => 4)
    port map (
      TX      => UART_TXD,
      RX      => UART_RXD,
      CLK     => CLOCK_50,
      nRST    => n_uartRst,
      WR_DATA => uart_wr_data,
      RD_DATA => uart_rd_data,
      ADDR    => uart_addr,
      n_WR    => uart_wr_reg,
      n_RD    => uart_rd_reg
      );

  nRESET <= KEY(0);

  process (CLOCK_50, nRESET)
  begin
    if (nRESET = '0') then
      uart_wr_reg  <= '1';
      uart_rd_reg  <= '1';
      uart_wr_data <= (others => '0');
      uart_rd_data <= (others => '0');
      state        <= reset;
    elsif (CLOCK_50'event and CLOCK_50 = '1') then
      state <= next_state;
                count        <= next_count;
                uart_addr    <= uart_addr_next;
                uart_wr_data <= uart_wr_data_next;
                uart_wr_reg  <= uart_wr_reg_next;
                uart_rd_reg  <= uart_rd_reg_next;
    end if;

  end process;


  process (state, count, uart_rd_data, uart_wr_data)
  begin
    next_state        <= state;
    next_count        <= count;
    uart_addr_next    <= (others => '0');
    uart_wr_data_next <= uart_wr_data;
    uart_wr_reg_next  <= '1';
    uart_rd_reg_next  <= '1';
    n_uartRst         <= '1';

    case state is
      when reset =>
        case to_integer(count) is
          when 0 =>
            next_count <= count + 1;
            n_uartRst  <= '0';
          when 1 =>
            next_count <= count + 1;
            n_uartRst  <= '1';
          when 2 =>
            next_count                     <= count + 1;
            uart_addr_next                 <= "10";
            uart_wr_reg_next               <= '0';
            uart_wr_data_next (7 DOWNTO 0) <= "10010100";  -- control reg : 115200 baud, even parity, 1 stop bits
          when 3 =>
            next_count <= count + 1;
          when others =>
            next_state <= writeBanner;
            next_count <= "00000";
        end case;
      when writeBanner =>
        -- Write prompt (SDTest>)
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('S');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('D');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('T');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 3 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('e');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('s');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 5 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('t');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('>');
            uart_wr_reg_next  <= '0';
            next_count        <= "00000";
            next_state        <= sendCMD0;
        end case;
      when others =>
        null;
    end case;
  end process;
  
end RTL;

