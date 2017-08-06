--
--      Controller for SD cards in SPI mode
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SDCardSPI is
  generic (
    CLOCK_FREQ : real := 50000000.0
    );
  port (
    SD_DAT  : in    std_logic;          -- MISO
    SD_CMD  : out   std_logic;          -- MOSI
    SD_CLK  : out   std_logic;          -- CLK
    SD_DAT3 : inout std_logic;          -- \CS / card present

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
end SDCardSPI;

architecture RTL of SDCardSPI is

  -- CRC7 generator
  component CRC7 is
    port (
      din  : in  std_logic;
      n_WR : in  std_logic;
      clk  : in  std_logic;
      nRST : in  std_logic;
      crc7 : out std_logic_vector (6 downto 0)
      );
  end component;

  type state_type is (idle, cardInserted, waitCommand,
                      performCommand, receive1ByteResponse,
                      receive5ByteResponse,

                      receiveDataBlocks, waitForRXDataToken,
                      receiveByte, writeByteToMemory,

                      checkCard);
  -- state "checkCard" allows us to sample the DAT3 input when cs is no longer
  -- driving to determine if the card is still inserted or not.

  signal state      : state_type := idle;
  signal next_state : state_type := idle;

  signal handle_response_state      : state_type := idle;  -- state which will
                                                           -- handle the
                                                           -- response is
                                                           -- selected when
                                                           -- "send command" is
                                                           -- asserted
  signal handle_response_state_next : state_type := idle;

  signal return_from_response_state : state_type := idle;  -- we also select
                                                           -- the state to
                                                           -- return to when
                                                           -- we've processed
                                                           -- the response

  signal return_from_response_state_next : state_type := idle;

  -- registers

  --    
  --            Address         |       Register
  --    ----------------------------------------------
  --            0               |       Control register        
  --            1               |       Command register
  --            2               |       Command argument register
  --            3               |       Status register
  --            4               |       Command response register 1
  --            5               |       Command response register 2
  --

  --
  --            Address 0 :        Control register
  --    
  --           Bit              |       Function
  --    ---------------------------------------------------------------------
  --            0               |       Send command ('0' = no action, '1' =
  --                            |       process current command in command /
  --                            |       argument registers)
  --    --------------------------------------------------------------------
  --            1 - 2           |       SPI Freq select
  --                            |       00 = 400 kHz
  --                            |       01 = 6.25 MHz
  --                            |       10 = 12.5 MHz
  --                            |       11 = 25 MHz
  --    --------------------------------------------------------------------
  --            3 - 31          |       Number of blocks in multiblock command
  --                            |       (0 to 2**29 - 1)
  --

  signal control_register : std_logic_vector (31 downto 0) := (others => '0');

  signal control_register_internal_next : std_logic_vector (31 downto 0) := (others => '0');

  --
  --    Address 1:      Command register
  --
  --            Bit             |       Function
  --    ---------------------------------------------------------------------
  --            0 - 5           |       Command
  --
  --

  signal command_register : std_logic_vector (5 downto 0) := (others => '0');

  --
  --    Address 2:      Command argument register   
  --
  --            Bit             |        Function
  --    ---------------------------------------------------------------------
  --            0 - 31          |       Command argument
  --

  signal command_argument_register : std_logic_vector (31 downto 0) := (others => '0');

  --
  --    Address 3:      status register
  --
  --            Bit             |       Function
  --    ---------------------------------------------------------------------
  --            0               |       1 = response timed out
  --            1               |       1 = card inserted
  --            2               |       1 = card removed
  --            3               |       1 = response received
  --            4               |       1 = transaction complete (for block /
  --                            |           multiblock commands)
  --            5               |       1 = invalid command
  --            6               |       1 = transaction error

  constant STATUS_REG_RESPONSE_TIMED_OUT_BIT   : integer := 0;
  constant STATUS_REG_CARD_INSERTED_BIT        : integer := 1;
  constant STATUS_REG_CARD_REMOVED_BIT         : integer := 2;
  constant STATUS_REG_RESPONSE_RECEIVED_BIT    : integer := 3;
  constant STATUS_REG_TRANSACTION_COMPLETE_BIT : integer := 4;
  constant STATUS_REG_INVALID_COMMAND_BIT      : integer := 5;
  constant STATUS_REG_TRANSACTION_ERROR_BIT    : integer := 6;

  constant STATUS_REG_BITS : integer := 7;

  signal status_register      : std_logic_vector (STATUS_REG_BITS - 1 downto 0) := (others => '0');
  signal status_register_next : std_logic_vector (STATUS_REG_BITS - 1 downto 0) := (others => '0');


  --
  --    Address 4:      Command response register
  --
  --            Bit             |       Function
  --    ---------------------------------------------------------------------
  --            0 - 7           |       Command response byte
  --
  --

  signal command_response_register      : std_logic_vector (7 downto 0) := (others => '0');
  signal command_response_register_next : std_logic_vector (7 downto 0) := (others => '0');

  --
  --    Address 5:      Command response register 2
  --
  --            Bit             |       Function
  --    ---------------------------------------------------------------------
  --            0 - 31          |       Command response 
  --
  --

  signal command_response_register2      : std_logic_vector (31 downto 0) := (others => '0');
  signal command_response_register2_next : std_logic_vector (31 downto 0) := (others => '0');


  --
  --    Baud tick generator
  --

  signal baud_count : integer range 0 to integer(CLOCK_FREQ / 400000.0 / 2.0) := 0;
  signal baud_tick  : std_logic                                               := '0';

  --
  --    Count for command transmission
  --

  constant COMMAND_COUNT_MAXVAL : integer := 2**10 - 1;

  signal command_count      : integer range 0 to COMMAND_COUNT_MAXVAL := 0;
  signal command_count_next : integer range 0 to COMMAND_COUNT_MAXVAL := 0;

  --
  --    Holding register for command transmission
  --

  signal command_holding_reg      : std_logic_vector (39 downto 0) := (others => '0');
  signal command_holding_reg_next : std_logic_vector (39 downto 0) := (others => '0');

  --
  --    Holding register for CRC
  --

  signal crc_holding_reg      : std_logic_vector (6 downto 0) := (others => '0');
  signal crc_holding_reg_next : std_logic_vector (6 downto 0) := (others => '0');

  --
  --    Holding register for token
  --

  signal token_holding_reg      : std_logic_vector (7 downto 0) := (others => '0');
  signal token_holding_reg_next : std_logic_vector (7 downto 0) := (others => '0');

  --
  --    SPI signals
  --

  signal sd_spi_mosi      : std_logic;
  signal sd_spi_mosi_next : std_logic;

  signal sd_spi_clk      : std_logic;
  signal sd_spi_clk_next : std_logic;

  signal sd_spi_cs      : std_logic := '1';
  signal sd_spi_cs_next : std_logic := '1';

  --
  --    Byte count for multibyte transfers
  --

  signal byte_count      : natural range 0 to 2048 := 0;
  signal byte_count_next : natural range 0 to 2048 := 0;

  --
  --    CRC7 signals
  --

  signal crc7_n_WR      : std_logic                     := '1';
  signal crc7_n_WR_next : std_logic                     := '1';
  signal crc7_nRST      : std_logic                     := '1';
  signal crc7_din       : std_logic                     := '0';
  signal crc7_din_next  : std_logic                     := '0';
  signal crc7_crc       : std_logic_vector (6 downto 0) := (others => '0');

begin

  crc0 : CRC7 port map (
    din  => crc7_din,
    n_WR => crc7_n_WR,
    clk  => CLK,
    nRST => crc7_nRST,
    crc7 => crc7_crc
    );

  -- drive SD_DAT3 when not in idle

  SD_DAT3 <= 'Z' when (state = idle or
                       state = checkCard or
                       state = cardInserted or
                       state = waitCommand)
             else sd_spi_cs;

  SD_CMD <= sd_spi_mosi;
  SD_CLK <= sd_spi_clk;

  -- state transition

  process (CLK, nRST, addr)
  begin
    if (nRST = '0') then

      state <= idle;

      command_count       <= 0;
      status_register     <= (others => '0');
      command_holding_reg <= (others => '0');

      control_register           <= (others => '0');
      command_register           <= (others => '0');
      command_argument_register  <= (others => '0');
      command_response_register  <= (others => '0');
      command_response_register2 <= (others => '0');

      sd_spi_cs   <= '1';
      sd_spi_mosi <= '1';
      sd_spi_clk  <= '0';

      command_holding_reg <= (others => '0');
      crc_holding_reg     <= (others => '0');

      crc7_din  <= '0';
      crc7_n_WR <= '1';

      return_from_response_state <= idle;
      handle_response_state      <= idle;

      token_holding_reg <= (others => '0');

      byte_count <= 0;

    elsif (CLK'event and CLK = '1') then

      state           <= next_state;
      command_count   <= command_count_next;
      status_register <= status_register_next;

      command_holding_reg <= command_holding_reg_next;
      crc_holding_reg     <= crc_holding_reg_next;
      crc7_n_WR           <= crc7_n_WR_next;
      crc7_din            <= crc7_din_next;

      sd_spi_cs   <= sd_spi_cs_next;
      sd_spi_mosi <= sd_spi_mosi_next;
      sd_spi_clk  <= sd_spi_clk_next;

      command_response_register  <= command_response_register_next;
      command_response_register2 <= command_response_register2_next;

      handle_response_state      <= handle_response_state_next;
      return_from_response_state <= return_from_response_state_next;

      token_holding_reg <= token_holding_reg_next;

      byte_count <= byte_count_next;

      -- register writes

      case to_integer(unsigned(addr)) is

        when 0 =>                       -- Control register
          if n_WR = '0' then
            control_register <= wr_data;
          else
            control_register <= control_register_internal_next;
          end if;
        when 1 =>                       -- Command register
          command_register <= wr_data (5 downto 0);
        when 2 =>                       -- Command argument register
          command_argument_register <= wr_data;
        when others =>
          null;
      end case;
    end if;

  end process;

  -- generate baud tick

  process (CLK)
  begin

    if rising_edge(CLK) then

      baud_count <= baud_count + 1;
      baud_tick  <= '0';

      case control_register(2 downto 1) is
        when "00" =>

          if (baud_count >= (integer(CLOCK_FREQ / 400000.0 / 2.0) - 1)) then
            baud_count <= 0;
            baud_tick  <= '1';
          end if;

        when "01" =>

          if (baud_count >= (integer(CLOCK_FREQ / 6250000.0 / 2.0) - 1)) then
            baud_count <= 0;
            baud_tick  <= '1';
          end if;

        when "10" =>

          if (baud_count >= (integer(CLOCK_FREQ / 12500000.0 / 2.0) - 1)) then
            baud_count <= 0;
            baud_tick  <= '1';
          end if;

        when "11" =>

          if (baud_count >= (integer(CLOCK_FREQ / 25000000.0 / 2.0) - 1)) then
            baud_count <= 0;
            baud_tick  <= '1';
          end if;

        when others =>
          null;
      end case;

    end if;

  end process;

  -- next state logic

  process (state, SD_DAT3, control_register, status_register,
           command_register, command_argument_register, command_holding_reg,
           crc_holding_reg, command_count, baud_tick, SD_DAT, sd_spi_clk, sd_spi_mosi,
           crc7_n_WR, crc7_din, crc7_crc, command_response_register, command_response_register2,
           handle_response_state, return_from_response_state, token_holding_reg, byte_count)
    variable conv_vector : unsigned (1 downto 0);
  begin

    next_state       <= state;
    sd_spi_cs_next   <= '1';
    sd_spi_clk_next  <= sd_spi_clk;
    sd_spi_mosi_next <= sd_spi_mosi;

    control_register_internal_next <= control_register;
    status_register_next           <= status_register;
    command_count_next             <= command_count;

    command_holding_reg_next <= command_holding_reg;
    crc_holding_reg_next     <= crc_holding_reg;

    handle_response_state_next      <= handle_response_state;
    return_from_response_state_next <= return_from_response_state;

    crc7_n_WR_next <= '1';
    crc7_din_next  <= crc7_din;
    crc7_nRST      <= '1';

    command_response_register_next  <= command_response_register;
    command_response_register2_next <= command_response_register2;

    token_holding_reg_next <= token_holding_reg;

    byte_count_next <= byte_count;
	 
	 dm_wr_data <= (others => '0');
	 dm_n_WR <= '1';
	 
    case state is
      when idle =>
        command_count_next                <= 0;
        sd_spi_clk_next                   <= '0';
        sd_spi_mosi_next                  <= '1';
        control_register_internal_next(0) <= '0';  -- clear "perform command"
                                                   -- bit, in case it has been
                                        -- set before card is even inserted
        if (SD_DAT3 = '1' or SD_DAT3 = 'H') then
          next_state <= cardInserted;
        end if;
      when cardInserted =>              -- do we need this state?
        status_register_next(STATUS_REG_CARD_INSERTED_BIT) <= '1';  -- card inserted set to high
        status_register_next(STATUS_REG_CARD_REMOVED_BIT)  <= '0';  -- card removed set to low
        next_state                                         <= waitCommand;
      when waitCommand =>

        --if (SD_DAT3 = 'L' or SD_DAT3 = '0') then  -- if card removed
        --  next_state                                        <= idle;
        --  status_register_next(STATUS_REG_CARD_REMOVED_BIT) <= '1';
        if (control_register(0) = '1') then
          control_register_internal_next(0) <= '0';
          command_holding_reg_next          <= "01" & command_register & command_argument_register;

          next_state                                                <= performCommand;
          command_count_next                                        <= 0;
          status_register_next(STATUS_REG_RESPONSE_TIMED_OUT_BIT)   <= '0';  -- clear timed out
          status_register_next(STATUS_REG_RESPONSE_RECEIVED_BIT)    <= '0';  -- clear response received
          status_register_next(STATUS_REG_TRANSACTION_COMPLETE_BIT) <= '0';  -- clear transaction complete
          status_register_next(STATUS_REG_INVALID_COMMAND_BIT)      <= '0';  -- clear invalid command
          status_register_next(STATUS_REG_TRANSACTION_ERROR_BIT)    <= '0';  -- clear
                                        -- transaction error
          crc7_nRST                                                 <= '0';

          command_response_register_next  <= (others => '0');
          command_response_register2_next <= (others => '0');

          -- decide which response is expected

          case to_integer(unsigned(command_register)) is
            when 0 | 55 | 41 =>
              handle_response_state_next      <= receive1ByteResponse;
              return_from_response_state_next <= checkCard;
            when 8 | 58 =>
              handle_response_state_next      <= receive5ByteResponse;
              return_from_response_state_next <= checkCard;
            when 17 =>
              handle_response_state_next      <= receive1ByteResponse;
              return_from_response_state_next <= receiveDataBlocks;
            when others =>
              status_register_next(5) <= '1';  -- invalid command
              next_state              <= waitCommand;
          end case;

        end if;

      when performCommand =>

        sd_spi_cs_next <= '0';

        if baud_tick = '1' then

          command_count_next <= command_count + 1;

          conv_vector     := to_unsigned(command_count mod 2, 2);
          sd_spi_clk_next <= conv_vector(0);

          if (command_count <= 40 * 2 - 1) then

            sd_spi_mosi_next <= command_holding_reg(39);

            -- compute crc on rising edge of clock 
            crc7_din_next  <= command_holding_reg(39);
            crc7_n_WR_next <= conv_vector(0);

            if (conv_vector(0) = '1') then
              command_holding_reg_next <= command_holding_reg(38 downto 0) & '0';
            end if;

            crc_holding_reg_next <= crc7_crc;

          elsif (command_count <= 47 * 2 - 1) then  -- CRC

            sd_spi_mosi_next <= crc_holding_reg(6);

            if (conv_vector(0) = '1') then
              crc_holding_reg_next <= crc_holding_reg(5 downto 0) & '0';
            end if;

          elsif (command_count <= 48 * 2 - 1) then  -- stop bit

            sd_spi_mosi_next <= '1';

          elsif (command_count = 1022) then
            command_count_next      <= 0;
            next_state              <= checkCard;
            status_register_next(0) <= '1';  -- timed out

          else                          -- wait for response
            if SD_DAT = '0' then
              command_count_next <= 0;
              next_state         <= handle_response_state;
            end if;
          end if;

        end if;

      when receive1ByteResponse =>
        sd_spi_cs_next <= '0';

        if baud_tick = '1' then

          command_count_next <= command_count + 1;

          conv_vector     := to_unsigned(command_count mod 2, 2);
          sd_spi_clk_next <= conv_vector(0);

          if (command_count < 8*2 - 1) then
            if (conv_vector(0) = '0') then
              command_response_register_next <= command_response_register(6 downto 0) & SD_DAT;
            end if;
          elsif (command_count < 1022) then
            if SD_DAT = '1' then               -- the response has completed
              command_count_next      <= 0;
              next_state              <= return_from_response_state;
              status_register_next(3) <= '1';  -- response received
            end if;
          else
            command_count_next      <= 0;
            next_state              <= checkCard;
            status_register_next(0) <= '1';    -- timed out
          end if;

        end if;

      when receive5ByteResponse =>

        sd_spi_cs_next <= '0';

        if baud_tick = '1' then

          command_count_next <= command_count + 1;

          conv_vector     := to_unsigned(command_count mod 2, 2);
          sd_spi_clk_next <= conv_vector(0);

          if (command_count < 8*2 - 1) then
            if (conv_vector(0) = '0') then
              command_response_register_next <= command_response_register(6 downto 0) & SD_DAT;
            end if;
          elsif (command_count < 40*2 - 1) then
            if (conv_vector(0) = '0') then
              command_response_register2_next <= command_response_register2(30 downto 0) & SD_DAT;
            end if;
          elsif (command_count < 1022) then
            if SD_DAT = '1' then               -- response has been received
              command_count_next      <= 0;
              next_state              <= return_from_response_state;
              status_register_next(3) <= '1';  -- response received
            end if;
          else
            command_count_next      <= 0;
            next_state              <= checkCard;
            status_register_next(0) <= '1';    -- timed out
          end if;

        end if;
      when receiveDataBlocks =>
        sd_spi_cs_next <= '0';

        case to_integer(unsigned(command_register)) is
          when 17 =>
            command_count_next <= 0;
            next_state         <= waitForRXDataToken;
            token_holding_reg_next <= "10101010"; -- this pattern is necessary
                                             -- because it doesn't correspond
                                             -- to any token, so we can differentiate
                                             -- when we have received a valid token
            
          -- we don't handle multiple block reads yet.
          -- if we do decide to handle them, we need to be able to send
          -- CMD12 to stop the transaction when we
          -- need to terminate the read. This is a little tricky so we
          -- don't handle the case yet.
          --when 18 =>
          --  if control_register(31 downto 3) = (others => '0') then
          --    status_register_next(STATUS_REG_TRANSACTION_COMPLETE_BIT) <= '1';
          --    next_state                                                <= checkCard;
          --    command_count_next                                        <= 0;
          --  else
          --    control_register_internal_next(31 downto 3) <=
          --      std_logic_vector(unsigned(control_register(31 downto 3)) - 1);
          --    next_state         <= receiveByte;
          --    command_count_next <= 0;
          --    next_state <= waitForRXDataToken;
          --  end if;
          when others =>
            status_register_next(STATUS_REG_INVALID_COMMAND_BIT) <= '1';
            next_state                                           <= checkCard;
        end case;
      when waitForRXDataToken =>
        -- wait to receive "11111110" (start of data) or "000xxxxx" (error)
        sd_spi_cs_next <= '0';

        if baud_tick = '1' then

          command_count_next <= command_count + 1;

          conv_vector     := to_unsigned(command_count mod 2, 2);
          sd_spi_clk_next <= conv_vector(0);

          -- check if we received a token
          if (token_holding_reg = "11111110") then
            command_count_next <= 0;
            next_state         <= receiveByte;
				byte_count_next    <= 0;
			elsif (token_holding_reg(7 downto 5) = "000") then
            status_register_next(STATUS_REG_TRANSACTION_ERROR_BIT) <= '1';
            command_count_next                                <= 0;
            next_state                                        <= checkCard;
          end if;

          if (command_count < 1022) then
            if (conv_vector(0) = '0') then
              token_holding_reg_next <= token_holding_reg(6 downto 0) & SD_DAT;
            end if;
          else
            command_count_next                                      <= 0;
            next_state                                              <= checkCard;
            status_register_next(STATUS_REG_RESPONSE_TIMED_OUT_BIT) <= '1';  -- timed out
          end if;

        end if;
      when receiveByte =>

        sd_spi_cs_next <= '0';

        -- if we have received all bytes, advance to check if card is still connected

        if (byte_count = 512) then
          status_register_next(STATUS_REG_TRANSACTION_COMPLETE_BIT) <= '1';
          next_state                                                <= idle;
        elsif baud_tick = '1' then

          command_count_next <= command_count + 1;

          conv_vector     := to_unsigned(command_count mod 2, 2);
          sd_spi_clk_next <= conv_vector(0);

          if (command_count < 8*2 - 1) then
            if (conv_vector(0) = '0') then
              token_holding_reg_next <= token_holding_reg(6 downto 0) & SD_DAT;
            end if;
          else
            next_state <= writeByteToMemory;
            byte_count_next <= byte_count + 1;
            command_count_next <= 0;
          end if;
        end if;
      when writeByteToMemory =>

		  sd_spi_cs_next <= '0';

        case command_count is
          when 0 =>
            command_count_next <= command_count + 1;
            dm_wr_data <= token_holding_reg;
            dm_n_WR <= '1';
          when 1 =>
			   command_count_next <= command_count + 1;
            dm_wr_data <= token_holding_reg;
            dm_n_WR <= '0';
			 when others =>
            dm_wr_data <= token_holding_reg;
            dm_n_WR <= '1';
            command_count_next <= 0;
            next_state <= receiveByte;
        end case;
      when checkCard =>
        case command_count is
          when 0 =>                     -- dummy tick to let DAT3 settle
            command_count_next <= command_count + 1;
          when 1 =>
            next_state <= idle;
            if (SD_DAT3 = '0' or SD_DAT3 = 'L') then
              status_register_next(STATUS_REG_CARD_REMOVED_BIT) <= '1';
            end if;
          when others =>
            command_count_next <= 0;
        end case;

      when others =>
        next_state <= idle;
    end case;

  end process;

-- register reads

  process (addr, control_register, command_register, command_argument_register,
           status_register, command_response_register, command_response_register2)
  begin

    rd_data <= (others => '0');

    case to_integer(unsigned(addr)) is

      when 0 =>                         -- Control register
        rd_data <= control_register;
      when 1 =>                         -- Command register
        rd_data(5 downto 0) <= command_register;
      when 2 =>                         -- Command argument register
        rd_data <= command_argument_register;
      when 3 =>                         -- Status register
        rd_data(STATUS_REG_BITS - 1 downto 0) <= status_register;
      when 4 =>                         -- Command response register 1
        rd_data(7 downto 0) <= command_response_register;
      when 5 =>                         -- Command response register 2
        rd_data <= command_response_register2;
      when others =>
        null;
    end case;
  end process;

end RTL;

