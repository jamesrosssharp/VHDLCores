--
-- UART receiver
--
-- See Chu, "FPGA Prototyping by VHDL Examples"
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTReceiverLite is
  port (
    CLK  : IN STD_LOGIC;
    nRST : IN STD_LOGIC;

    nRxDone : OUT STD_LOGIC;

    rxData : OUT STD_LOGIC_VECTOR (7 downto 0);

    baudTick : IN STD_LOGIC;

    RXD : IN STD_LOGIC;

    frameError : OUT STD_LOGIC
    );
end UARTReceiverLite;

architecture RTL of UARTReceiverLite is

  type state_type is (idle, startBit, rxBits, rxStopBit, waitForIdle);
  signal state      : state_type := idle;
  signal state_next : state_type;

  signal rx_byte      : STD_LOGIC_VECTOR (7 downto 0);
  signal rx_byte_next : STD_LOGIC_VECTOR (7 downto 0);

  signal rx_filter      : STD_LOGIC_VECTOR (3 downto 0);  -- filter received input into rx_filter
  signal rx_filter_next : STD_LOGIC_VECTOR (3 downto 0);

  signal count      : UNSIGNED (3 downto 0);  -- 2**4 = 16 counts per bit
  signal count_next : UNSIGNED (3 downto 0);

  signal data_bit      : UNSIGNED (2 downto 0);
  signal data_bit_next : UNSIGNED (2 downto 0);

  signal frame_error_bit      : STD_LOGIC;
  signal frame_error_bit_next : STD_LOGIC;
  
begin

  process (CLK, nRST)
  begin
    
    if (nRST = '0') then
      
      rx_byte         <= (others => '0');
      count           <= (others => '0');
      data_bit        <= (others => '0');
      rx_filter       <= (others => '0');
      state           <= idle;
      frame_error_bit <= '0';
      
    elsif CLK'event and CLK = '1' then
      
      rx_byte         <= rx_byte_next;
      state           <= state_next;
      count           <= count_next;
      data_bit        <= data_bit_next;
      rx_filter       <= rx_filter_next;
      frame_error_bit <= frame_error_bit_next;

    end if;
    
  end process;
  
  
  process (RXD, rx_byte, state, count, data_bit,
           baudTick, rx_filter, frame_error_bit)
    variable filter     : integer;
    variable filter_bit : STD_LOGIC;
  begin
    
    state_next           <= state;
    rx_byte_next         <= rx_byte;
    count_next           <= count;
    data_bit_next        <= data_bit;
    rx_filter_next       <= rx_filter;
    frame_error_bit_next <= frame_error_bit;

    nRXDone <= '1';

    filter := 0;

    for i in rx_filter'range loop
      if (rx_filter(i) = '1') then
        filter := filter + 1;
      end if;
    end loop;

    if (filter > 2) then
      filter_bit := '1';
    else
      filter_bit := '0';
    end if;


    case state is
      when idle =>
        if (RXD = '0') then
          state_next <= startBit;
        end if;
      when startBit =>
        
        frame_error_bit_next <= '0';

        if (baudTick = '1') then
          count_next <= count + 1;

          if (count > 7 and count < 13) then
            rx_filter_next <= rx_filter(2 downto 0) & RXD;
          end if;

          if (count = "1111") then
            if filter_bit = '0' then
              state_next <= rxBits;
            else
              frame_error_bit_next <= '1';
              state_next           <= idle;
            end if;
          end if;
        end if;
        
      when rxBits =>
        
        if (baudTick = '1') then
          count_next <= count + 1;

          if (count > 7 and count < 13) then
            rx_filter_next <= rx_filter(2 downto 0) & RXD;
          end if;

          if (count = "1111") then
            data_bit_next <= data_bit + 1;
            rx_byte_next  <= filter_bit & rx_byte(7 downto 1);

            if (data_bit = "111") then
              state_next <= rxStopBit;
            end if;
          end if;
        end if;
        
        
      when rxStopBit =>
        if (baudTick = '1') then
          
          count_next <= count + 1;

          if (count = "1111") then
            state_next <= waitForIdle;
            nRxDone    <= '0';
          end if;
          
        end if;
        
      when others =>
        
        state_next <= idle;
        
    end case;
    
  end process;

  rxData     <= rx_byte;
  frameError <= frame_error_bit;
  
end RTL;
