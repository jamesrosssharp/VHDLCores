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
    CLOCK_FREQ : real := 50000000.0     -- frequency of driving clock
    );
  port (

    -- SD Card pins
    SD_DAT  : in    std_logic;          -- MISO
    SD_CMD  : out   std_logic;          -- MOSI
    SD_CLK  : out   std_logic;          -- CLK
    SD_DAT3 : inout std_logic;          -- \CS / card present

    -- UART Pins
    UART_TXD : out std_logic;
    UART_RXD : in  std_logic;

    -- main clock
    CLOCK_50 : in std_logic;

    -- KEY[0] used as asynchronous reset 
    KEY : in std_logic_vector (3 downto 0)

    );
end SDCardSPITester;

architecture RTL of SDCardSPITester is

  -- SDCardSPI core

  component SDCardSPI is
    generic (
      CLOCK_FREQ : real := CLOCK_FREQ
      );
    port (
      SD_DAT  : in    std_logic;        -- MISO
      SD_CMD  : out   std_logic;        -- MOSI
      SD_CLK  : out   std_logic;        -- CLK
      SD_DAT3 : inout std_logic;        -- \CS / card present

      CLK  : in std_logic;
      nRST : in std_logic;

      -- register interface (command, argument, etc)
      wr_data : in std_logic_vector (31 downto 0);
      n_WR    : in std_logic;

      rd_data : out std_logic_vector (31 downto 0);
      n_RD    : in  std_logic;

      addr : in std_logic_vector (2 downto 0);

      -- direct memory transfer interface for block reads

      dm_wr_data : out std_logic_vector (7 downto 0);
      dm_n_WR    : out std_logic

      -- direct memory transfer interface for block writes

      -- TODO

      );
  end component;


  -- UART core

  component UART is
    generic (
      TX_FIFO_DEPTH : integer;
      RX_FIFO_DEPTH : integer
      );
    port (

      TX   : out std_logic;
      RX   : in  std_logic;
      CLK  : in  std_logic;
      nRST : in  std_logic;

      -- Register interface (bus slave)

      WR_DATA : in  std_logic_vector (31 downto 0);
      RD_DATA : out std_logic_vector (31 downto 0);

      ADDR : in std_logic_vector (1 downto 0);  -- 4 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = CTRL, 3 = STATUS

      n_WR : in std_logic;              -- active low, write to register 
      n_RD : in std_logic               -- active low, read from register

      );
  end component;

  -- altera ram template

  component simple_dual_port_ram_single_clock is
    generic
      (
        DATA_WIDTH : natural := 8;
        ADDR_WIDTH : natural := 6
        );

    port
      (
        clk   : in  std_logic;
        raddr : in  natural range 0 to 2**ADDR_WIDTH - 1;
        waddr : in  natural range 0 to 2**ADDR_WIDTH - 1;
        data  : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        we    : in  std_logic := '1';
        q     : out std_logic_vector((DATA_WIDTH -1) downto 0)
        );
  end component;

  signal uart_wr_reg      : std_logic := '1';
  signal uart_wr_reg_next : std_logic := '1';

  signal uart_addr      : std_logic_vector (1 downto 0);
  signal uart_addr_next : std_logic_vector (1 downto 0);

  signal uart_wr_data      : std_logic_vector (31 downto 0);
  signal uart_wr_data_next : std_logic_vector (31 downto 0);

  signal uart_rd_reg      : std_logic := '1';
  signal uart_rd_reg_next : std_logic := '1';
  signal uart_rd_data     : std_logic_vector (31 downto 0);

  signal n_uartRst : std_logic := '1';

  signal sd_wr_reg      : std_logic := '1';
  signal sd_wr_reg_next : std_logic := '1';

  signal sd_addr      : std_logic_vector (2 downto 0) := "000";
  signal sd_addr_next : std_logic_vector (2 downto 0) := "000";

  signal sd_wr_data      : std_logic_vector (31 downto 0);
  signal sd_wr_data_next : std_logic_vector (31 downto 0);

  signal sd_rd_reg      : std_logic                      := '1';
  signal sd_rd_reg_next : std_logic                      := '1';
  signal sd_rd_data     : std_logic_vector (31 downto 0) := (others => '0');

  signal sd_dm_wr_data : std_logic_vector (7 downto 0);
  signal sd_dm_n_WR    : std_logic;
  signal sd_dm_WR      : std_logic;  -- altera ram template uses inverted logic

  signal n_sdRst : std_logic := '1';

  type state_type is (reset, writeBanner, waitForCard, sendCMD0, processCMD0Response,
                      waitForResponse, printCommand, printStatus,
                      printResponseByte, printResponseWord, printNewLine, waitTxFifoEmpty,
                      printTimedOut,
                      sendCMD8, processCMD8Response, sendCMD58, processCMD58Response,
                      sendCMD55, processCMD55Response, sendCMD41, processCMD41Response,
                      sendCMD17, processCMD17Response, printRamByte, waitForEver);

  signal state : state_type            := reset;
  signal count : unsigned (4 downto 0) := "00000";  -- counter used as sub-state

  signal next_state : state_type            := reset;
  signal next_count : unsigned (4 downto 0) := "00000";

  -- we reuse some state code and store the state to return to at the end of a
  -- sequence.

  signal return_from_response_handling      : state_type := reset;
  signal return_from_response_handling_next : state_type := reset;

  signal return_from_wait_tx_fifo      : state_type := reset;
  signal return_from_wait_tx_fifo_next : state_type := reset;

  -- store the current command, mostly for printing

  signal cur_command      : std_logic_vector (7 downto 0);
  signal cur_command_next : std_logic_vector (7 downto 0);

  -- ram read data and address for retrieving bytes from RAM

  signal ram_rd_addr      : natural range 0 to 2**9 - 1 := 0;  -- 512 bytes of RAM (4k bits)
  signal ram_rd_addr_next : natural range 0 to 2**9 - 1 := 0;

  signal ram_wr_addr      : natural range 0 to 2**9 - 1 := 0;
  signal ram_wr_addr_next : natural range 0 to 2**9 - 1 := 0;

  signal ram_reset_addr : std_logic := '0';  -- so the ram addresses can be reset

  signal ram_rd_data : std_logic_vector (7 downto 0);  -- byte width

  -- a more readable reset signal than KEY(0)

  signal nRESET : std_logic := '1';

  function char_2_std_logic_vector(ch : character)
    return std_logic_vector is
    variable out_vector : std_logic_vector(7 downto 0);
  begin
    out_vector := std_logic_vector (to_unsigned(character'pos(ch), 8));
    return out_vector;
  end char_2_std_logic_vector;

  function nibble_2_ascii_hex(nibble : std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable out_vector : std_logic_vector(7 downto 0);
  begin
    case nibble is
      when "0000" =>
        out_vector := char_2_std_logic_vector('0');
      when "0001" =>
        out_vector := char_2_std_logic_vector('1');
      when "0010" =>
        out_vector := char_2_std_logic_vector('2');
      when "0011" =>
        out_vector := char_2_std_logic_vector('3');
      when "0100" =>
        out_vector := char_2_std_logic_vector('4');
      when "0101" =>
        out_vector := char_2_std_logic_vector('5');
      when "0110" =>
        out_vector := char_2_std_logic_vector('6');
      when "0111" =>
        out_vector := char_2_std_logic_vector('7');
      when "1000" =>
        out_vector := char_2_std_logic_vector('8');
      when "1001" =>
        out_vector := char_2_std_logic_vector('9');
      when "1010" =>
        out_vector := char_2_std_logic_vector('a');
      when "1011" =>
        out_vector := char_2_std_logic_vector('b');
      when "1100" =>
        out_vector := char_2_std_logic_vector('c');
      when "1101" =>
        out_vector := char_2_std_logic_vector('d');
      when "1110" =>
        out_vector := char_2_std_logic_vector('e');
      when "1111" =>
        out_vector := char_2_std_logic_vector('f');
      when others =>
        out_vector := char_2_std_logic_vector('?');
    end case;
    return out_vector;
  end nibble_2_ascii_hex;

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

  sd0 : SDCardSPI
    port map (
      SD_DAT     => SD_DAT,
      SD_CMD     => SD_CMD,
      SD_CLK     => SD_CLK,
      SD_DAT3    => SD_DAT3,
      CLK        => CLOCK_50,
      nRST       => n_sdRst,
      wr_data    => sd_wr_data,
      n_WR       => sd_wr_reg,
      rd_data    => sd_rd_data,
      n_RD       => sd_rd_reg,
      addr       => sd_addr,
      dm_wr_data => sd_dm_wr_data,
      dm_n_WR    => sd_dm_n_WR
      );

  sd_dm_WR <= not sd_dm_n_WR;

  ram0 : simple_dual_port_ram_single_clock
    generic map
    (
      DATA_WIDTH => 8,
      ADDR_WIDTH => 9
      )
    port map
    (
      clk   => CLOCK_50,
      raddr => ram_rd_addr,
      waddr => ram_wr_addr,
      data  => sd_dm_wr_data,
      we    => sd_dm_WR,
      q     => ram_rd_data
      );

  nRESET <= KEY(0);

  process (CLOCK_50, nRESET)
  begin
    if (nRESET = '0') then
      uart_wr_reg                   <= '1';
      uart_rd_reg                   <= '1';
      uart_wr_data                  <= (others => '0');
      state                         <= reset;
      sd_wr_data                    <= (others => '0');
      sd_addr                       <= (others => '0');
      return_from_response_handling <= reset;
      return_from_wait_tx_fifo      <= reset;
      cur_command                   <= (others => '0');
      ram_rd_addr                   <= 0;
      ram_wr_addr                   <= 0;
    elsif (CLOCK_50'event and CLOCK_50 = '1') then
      state                         <= next_state;
      count                         <= next_count;
      uart_addr                     <= uart_addr_next;
      uart_wr_data                  <= uart_wr_data_next;
      uart_wr_reg                   <= uart_wr_reg_next;
      uart_rd_reg                   <= uart_rd_reg_next;
      sd_wr_data                    <= sd_wr_data_next;
      sd_wr_reg                     <= sd_wr_reg_next;
      sd_rd_reg                     <= sd_rd_reg_next;
      sd_addr                       <= sd_addr_next;
      return_from_response_handling <= return_from_response_handling_next;
      return_from_wait_tx_fifo      <= return_from_wait_tx_fifo_next;
      cur_command                   <= cur_command_next;
      ram_rd_addr                   <= ram_rd_addr_next;
      ram_wr_addr                   <= ram_wr_addr_next;
    end if;

  end process;

  -- ram address handling

  process (sd_dm_n_WR, ram_wr_addr, ram_reset_addr)
  begin
    ram_wr_addr_next <= ram_wr_addr;

    if (ram_reset_addr = '1') then
      ram_wr_addr_next <= 0;
    elsif sd_dm_n_WR = '0' then
      if (ram_wr_addr = 511) then       -- to hack around altera template using
        -- natural type...
        ram_wr_addr_next <= 0;
      else
        ram_wr_addr_next <= ram_wr_addr + 1;
      end if;
    end if;

  end process;

  process (state, count, uart_rd_data, uart_wr_data, sd_wr_data,
           sd_rd_data, cur_command, return_from_response_handling, return_from_wait_tx_fifo,
           ram_rd_addr)
  begin
    next_state        <= state;
    next_count        <= count;
    uart_addr_next    <= (others => '0');
    uart_wr_data_next <= uart_wr_data;
    uart_wr_reg_next  <= '1';
    uart_rd_reg_next  <= '1';
    n_uartRst         <= '1';

    n_sdRst         <= '1';
    sd_wr_data_next <= sd_wr_data;
    sd_wr_reg_next  <= '1';
    sd_rd_reg_next  <= '1';
    sd_addr_next    <= (others => '0');

    ram_rd_addr_next <= ram_rd_addr;
    ram_reset_addr   <= '0';

    cur_command_next                   <= cur_command;
    return_from_response_handling_next <= return_from_response_handling;
    return_from_wait_tx_fifo_next      <= return_from_wait_tx_fifo;

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
            uart_wr_data_next (7 downto 0) <= "10010100";  -- control reg : 115200 baud, even parity, 1 stop bits
          when 3 =>
            uart_addr_next                 <= "10";
            uart_wr_reg_next               <= '0';
            uart_wr_data_next (7 downto 0) <= "10010100";  -- control reg : 115200 baud, even parity, 1 stop bits
            next_count                     <= count + 1;
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
            next_state        <= waitForCard;
        end case;
      when waitForCard =>
        case to_integer(count) is
          when 0 =>
            sd_addr_next   <= "011";    -- status register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 1 =>
            sd_addr_next <= "011";
            next_count   <= "00000";
            if (sd_rd_data(1) = '1') then
              next_state <= sendCMD0;
            end if;
          when others =>
            next_count <= "00000";
        end case;
      when sendCMD0 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD0) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (others => '0');
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(0, 8));   -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (others => '0');
            next_count      <= count + 1;
          when 2 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD0Response;
        end case;
      when processCMD0Response =>
        next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
        return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
        return_from_response_handling_next <= sendCMD8;    -- return from
                                                           -- response handling
                                                           -- to next command
      when sendCMD8 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD8) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (3 => '1', others => '0');
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(8, 8));   -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= "00000000000000000000000110101010";
            next_count      <= count + 1;
          when 2 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD8Response;
        end case;
      when processCMD8Response =>
        next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
        return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
        return_from_response_handling_next <= sendCMD58;   -- return from
                                                           -- response handling
                                                           -- to next command
      when sendCMD58 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD8) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= std_logic_vector(to_unsigned(58, 32));
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(58, 8));  -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (others => '0');
            next_count      <= count + 1;
          when 2 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD58Response;
        end case;
      when processCMD58Response =>
        next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
        return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
        return_from_response_handling_next <= sendCMD55;   -- return from
                                                           -- response handling
                                                           -- to next command


      when sendCMD55 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD8) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= std_logic_vector(to_unsigned(55, 32));
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(55, 8));  -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (others => '0');
            next_count      <= count + 1;
          when 2 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD55Response;
        end case;
      when processCMD55Response =>
        next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
        return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
        return_from_response_handling_next <= sendCMD41;        -- return from
                                        -- response handling
                                        -- to next command


      when sendCMD41 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD8) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= std_logic_vector(to_unsigned(41, 32));
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(41, 8));  -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (30 => '1', others => '0');  -- HCS = 1
            next_count      <= count + 1;
          when 2 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD41Response;
        end case;
      when processCMD41Response =>

        case to_integer(count) is
          -- wait for "response received" bit
          when 0 =>
            sd_addr_next   <= "011";    -- resp register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 1 =>
            sd_addr_next <= "011";
            next_count   <= "00000";
            if (sd_rd_data(3) = '1') then  -- transaction complete
              next_count <= count + 1;
            end if;
            -- read response, and see if bit 0 is 1. If so, poll the card again.
          when 2 =>
            next_count <= count + 1;
            sd_addr_next <= "100";
            sd_rd_reg_next <= '0';
          when 3 =>
				sd_addr_next <= "100";
				sd_rd_reg_next <= '1';
            if (sd_rd_data(0) = '1') then
               next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
					return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
					return_from_response_handling_next <= sendCMD55;  -- return from
                                        -- response handling
                                        -- to next command
					next_count                         <= "00000";
            else
              next_count <= count + 1;
            end if;
          when others =>
            next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
            return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
            return_from_response_handling_next <= sendCMD17;  -- return from
                                        -- response handling
                                        -- to next command
            next_count                         <= "00000";
        end case;
      when sendCMD17 =>
        case to_integer(count) is
          when 0 =>                     -- write command (CMD8) to reg 1
            sd_addr_next    <= "001";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= std_logic_vector(to_unsigned(17, 32));
            next_count      <= count + 1;
            cur_command_next <=
              std_logic_vector(to_unsigned(17, 8));  -- save command so we can
                                                     -- print it 
          when 1 =>                     -- write command argument to reg 2
            sd_addr_next    <= "010";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (others => '0');      -- read block at block /
                                                     -- byte offset 0
            next_count      <= count + 1;
          when 2 =>
            next_count     <= count + 1;
            ram_reset_addr <= '1';
          when 3 =>  -- write send command (write send bit of control register = 0)
            sd_addr_next    <= "000";
            sd_wr_reg_next  <= '0';
            sd_wr_data_next <= (0 => '1', others => '0');
            next_count      <= count + 1;
          when others =>
            next_count <= "00000";
            next_state <= processCMD17Response;
        end case;
      when processCMD17Response =>

        case to_integer(count) is
          -- wait for "transaction complete" bit
          when 0 =>
            sd_addr_next   <= "011";    -- status register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 1 =>
            sd_addr_next <= "011";
            next_count   <= "00000";
            if (sd_rd_data(4) = '1') then  -- transaction complete
              next_count <= count + 1;
            elsif (sd_rd_data(0) = '1') then
					next_state <= printTimedOut;
				end if;
          -- reset ram read address
          when 2 =>
            ram_rd_addr_next <= 0;
            next_count       <= count + 1;
          when others =>
            next_state                         <= waitTxFifoEmpty;  -- first drain fifo,
            return_from_wait_tx_fifo_next      <= waitForResponse;  -- then enter
                                        -- response handling
                                        -- sequence
            return_from_response_handling_next <= printRamByte;  -- return from
                                        -- response handling
                                        -- to next command
            next_count                         <= "00000";
        end case;
      when printRamByte =>
        case to_integer(count) is
          -- if ram_read_addr % 16 == 0, print new lines
          when 0 =>
            next_count <= count + 1;
            if (ram_rd_addr mod 16 /= 0) then
              next_count <= "00011";
            end if;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(cr);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(lf);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          -- print out current byte
          when 3 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(ram_rd_data(7 downto 4));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(ram_rd_data(3 downto 0));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 5 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(' ');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          -- increment ram read addr, or go to next state
          when 6 =>
            if (ram_rd_addr = 511) then
              next_count <= "00000";
              next_state <= waitForEver;
            else
              ram_rd_addr_next <= ram_rd_addr + 1;
              next_count       <= count + 1;
            end if;
          -- wait for tx fifo to drain
          when others =>
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= printRamByte;
        end case;

      when waitForResponse =>
        -- wait for previous command response
        case to_integer(count) is
          when 0 =>
            sd_addr_next   <= "011";    -- status register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 1 =>
            sd_addr_next <= "011";
            next_count   <= "00000";
            if (sd_rd_data(3) = '1') then                  -- response received
              next_state <= printCommand;
            elsif (sd_rd_data(0) = '1') then               -- timed out
              next_state <= printTimedOut;
            elsif (sd_rd_data(2) = '1') then               -- card removed; go
                                                           -- back to waiting
                                                           -- for card
              next_state <= waitForCard;
            end if;
          when others =>
            next_count <= "00000";
        end case;
      when printCommand =>
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('C');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(':');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(cur_command(7 downto 4));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 3 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(cur_command(3 downto 0));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(' ');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= printStatus;
        end case;
      when printStatus =>
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('S');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(':');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            sd_addr_next   <= "011";    -- status register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 3 =>
            sd_addr_next      <= "011";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(3 downto 0));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(' ');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= printResponseByte;
        end case;
      when printResponseByte =>
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('R');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(':');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            sd_addr_next   <= "100";    -- response register
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 3 =>
            sd_addr_next      <= "100";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(7 downto 4));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            sd_addr_next      <= "100";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(3 downto 0));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 5 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(' ');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= printResponseWord;
        end case;
      when printResponseWord =>
        case to_integer(count) is
          when 0 =>
            sd_addr_next   <= "101";    -- response register2
            sd_rd_reg_next <= '0';
            next_count     <= count + 1;
          when 1 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(31 downto 28));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(27 downto 24));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 3 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(23 downto 20));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 4 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(19 downto 16));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 5 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(15 downto 12));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 6 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(11 downto 8));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 7 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(7 downto 4));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 8 =>
            sd_addr_next      <= "101";
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & nibble_2_ascii_hex(sd_rd_data(3 downto 0));
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= printNewLine;
        end case;
      when printNewLine =>
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(cr);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(lf);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= return_from_response_handling;
        end case;
      when waitTxFifoEmpty =>
        -- wait for UART tx fifo to drain
        case to_integer(count) is
          when 0 =>
            uart_addr_next   <= "11";   -- status register
            uart_rd_reg_next <= '0';
            next_count       <= count + 1;
          when 1 =>
            uart_addr_next <= "11";
            next_count     <= "00000";
            -- return to intended next state ?
            if (uart_rd_data(1) = '1') then                -- tx fifo empty
              next_state <= return_from_wait_tx_fifo;
            end if;
          when others =>
            next_count <= "00000";
        end case;
      when printTimedOut =>
        case to_integer(count) is
          when 0 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('T');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 1 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector('O');
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 2 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(cr);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when 3 =>
            uart_addr_next    <= "00";
            uart_wr_data_next <= std_logic_vector(to_unsigned(0, 24)) & char_2_std_logic_vector(lf);
            uart_wr_reg_next  <= '0';
            next_count        <= count + 1;
          when others =>
            next_count                    <= "00000";
            next_state                    <= waitTxFifoEmpty;
            return_from_wait_tx_fifo_next <= waitForCard;  -- if we timed out,
                                                           -- go back to wait
                                        -- for card and start
                                        -- again.
        end case;
      when others =>
        null;
    end case;
  end process;

end RTL;

