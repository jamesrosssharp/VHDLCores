--
--      UART transmitter core
--
--              See Chu, "FPGA Prototyping by VHDL Examples"
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTTransmitterLite is
  port (
    CLK  : IN STD_LOGIC;
    nRST : IN STD_LOGIC;

    nTxStart : IN  STD_LOGIC;
    nTxDone  : OUT STD_LOGIC;

    txData : IN STD_LOGIC_VECTOR (7 downto 0);

    baudTick : IN STD_LOGIC;

    TXD : OUT STD_LOGIC
    );
end UARTTransmitterLite;

architecture RTL of UARTTransmitterLite
is

  type state_type is (idle, latchByte, startBit, txBits, txStopBit, waitForIdle);
  signal state      : state_type := idle;
  signal state_next : state_type;

  signal tx_byte      : STD_LOGIC_VECTOR (7 downto 0);
  signal tx_byte_next : STD_LOGIC_VECTOR (7 downto 0);

  signal count      : UNSIGNED (3 downto 0);  -- 2**4 = 16 counts per bit
  signal count_next : UNSIGNED (3 downto 0);

  signal data_bit      : UNSIGNED (2 downto 0);
  signal data_bit_next : UNSIGNED (2 downto 0);

  signal n_tx_done_bit : STD_LOGIC;

  signal tx_bit      : STD_LOGIC := '1';
  signal tx_bit_next : STD_LOGIC;
  
begin

  process (CLK, nRST)
  begin
    
    if (nRST = '0') then
      
      tx_byte  <= (others => '0');
      tx_bit   <= '1';
      count    <= (others => '0');
      data_bit <= (others => '0');
      
    elsif CLK'event and CLK = '1' then
      
      tx_byte  <= tx_byte_next;
      tx_bit   <= tx_bit_next;
      state    <= state_next;
      count    <= count_next;
      data_bit <= data_bit_next;
    end if;
    
  end process;
  
  process (tx_byte,
           tx_bit, state, txData, nTxStart, count, data_bit, baudTick)
  begin
    
    tx_byte_next  <= tx_byte;
    tx_bit_next   <= tx_bit;
    state_next    <= state;
    count_next    <= count;
    data_bit_next <= data_bit;
    n_tx_done_bit <= '1';

    case state is
      when idle =>
        
        tx_bit_next <= '1';

        if nTxStart = '0' then  -- we wait a cycle after the tick (read from fifo) to account for delay
          state_next <= latchByte;
        end if;
        
      when latchByte =>
        
        tx_byte_next <= txData;

        state_next <= startBit;
        
      when startBit =>
        
        tx_bit_next <= '0';

        if (baudTick = '1') then
          count_next <= count + 1;

          if (count = "1111") then
            state_next    <= txBits;
            data_bit_next <= (others => '0');
          end if;
        end if;
        
      when txBits =>
        
        tx_bit_next <= tx_byte(0);

        if (baudTick = '1') then
          
          count_next <= count + 1;

          if (count = "1111") then
            data_bit_next <= data_bit + 1;
            tx_byte_next  <= '0' & tx_byte(7 downto 1);

            if (data_bit = "111") then
              state_next <= txStopBit;
            end if;
          end if;
        end if;
        
      when txStopBit =>

        tx_bit_next <= '1';

        if (baudTick = '1') then
          count_next <= count + 1;

          if (count = "1111") then
            state_next    <= waitForIdle;
            n_tx_done_bit <= '0';
          end if;
          
        end if;
        
      when others =>
        
        state_next <= idle;
        
    end case;
    
  end process;

  nTxDone <= n_tx_done_bit;
  TXD     <= tx_bit;

end RTL;
