--
--      SPI Master lite
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SPIMasterLite is
  generic (
    CLOCK_FREQ    : real    := 50000000.0;
    SPI_FREQ      : real    := 10000000.0;
    BITS          : integer := 8;
    TX_FIFO_DEPTH : integer := 2;       -- 2**2 = 4 word FIFO
    RX_FIFO_DEPTH : integer := 2;       -- 2**2 = 4 word FIFO
    SPI_MODE      : integer := 0

    --
    --                  SPI Mode
    --
    --          SPI Mode  |  CPOL   | CPHA  
    --          0                                       0                       0               Clock normally low. Data captured on rising edge.
    --          1                                       0                       1               Clock normally low. Data captured on falling edge.
    --          2                                       1                       0               Clock normally high. Data captured on falling edge.
    --          3                                       1                       1               Clock normally high. Data captured on rising edge.

    );
  --
  --            Controller has a raw signal interface to make it easier to
  --            interface to other logic. TODO: wrapper with bus interface.
  --
  port (

    -- to tx fifo
    wr_data : IN STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
    n_WR    : IN STD_LOGIC;

    -- from rx fifo
    rd_data : OUT STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
    n_RD    : IN  STD_LOGIC;

    --                  Control Input
    --          BIT                     |               Function
    --          ----------------------------------------------------
    --          0                       |               transmit inhibit (1 = inhibit, 0 = transmit)

    control : IN STD_LOGIC;

    --                  Status Output
    --          BIT                     |               Function
    --          -----------------------------------------------------
    --          0                       |               TX Fifo Full
    --          1                       |               TX Fifo Empty
    --          2                       |               RX Fifo Full
    --          3                       |               RX Fifo Empty
    --

    status : OUT STD_LOGIC_VECTOR (3 downto 0);

    -- SPI signals

    MISO : IN  STD_LOGIC;
    MOSI : OUT STD_LOGIC;
    nSS  : OUT STD_LOGIC;
    SCK  : OUT STD_LOGIC;

    -- signals

    CLK  : IN STD_LOGIC;
    nRST : IN STD_LOGIC

    );
end SPIMasterLite;

architecture RTL of SPIMasterLite is

  component Fifo is
    generic (
      DEPTH : INTEGER;
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
  end component;

  signal txfifo_rd_data  : STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
  signal txfifo_nRD      : STD_LOGIC := '1';
  signal txfifo_nRD_next : STD_LOGIC := '1';

  signal baud_tick  : STD_LOGIC                                         := '0';
  signal baud_count : INTEGER RANGE 0 to integer(CLOCK_FREQ / SPI_FREQ) := 0;

  type state_type is (idle, latchtx, txbits, pollTxFifo);
  signal state      : state_type := idle;
  signal state_next : state_type;

  signal tx_word      : STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
  signal tx_word_next : STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);

  signal baud_tick_count      : INTEGER RANGE 0 to 2**(BITS + 2);
  signal baud_tick_count_next : INTEGER RANGE 0 to 2**(BITS + 2);

  signal serial_clk      : STD_LOGIC;
  signal serial_clk_next : STD_LOGIC;

  signal serial_data      : STD_LOGIC := '1';
  signal serial_data_next : STD_LOGIC;

  signal serial_slave_select      : STD_LOGIC := '1';
  signal serial_slave_select_next : STD_LOGIC;

  signal serial_status : STD_LOGIC_VECTOR (3 DOWNTO 0);

  signal rx_word      : STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);
  signal rx_word_next : STD_LOGIC_VECTOR (BITS - 1 DOWNTO 0);

  signal rxfifo_nWR      : STD_LOGIC := '1';
  signal rxfifo_nWR_next : STD_LOGIC := '1';


  procedure reset_serial_clock
    (signal serial_clk : OUT STD_LOGIC) is
  begin
    if (SPI_MODE = 0) or (SPI_MODE = 1) then
      serial_clk <= '0';
    else
      serial_clk <= '1';
    end if;
  end reset_serial_clock;
  
begin

  txfifo0 : Fifo generic map (
    DEPTH => TX_FIFO_DEPTH,
    BITS  => BITS
    )
    port map (CLK   => CLK, nRST => nRST, WR_DATA => wr_data,
              n_WR  => n_WR, RD_DATA => txfifo_rd_data,
              n_RD  => txfifo_nRD, full => serial_status(0),
              empty => serial_status(1));

  rxfifo0 : Fifo generic map (
    DEPTH => RX_FIFO_DEPTH,
    BITS  => BITS
    )
    port map (CLK   => CLK, nRST => nRST, WR_DATA => rx_word,
              n_WR  => rxfifo_nWR, RD_DATA => rd_data,
              n_RD  => n_RD, full => serial_status(2),
              empty => serial_status(3));
  -- Synchronous updates
  process (CLK, nRST)
  begin
    if (nRST = '0') then
      txfifo_nRD          <= '1';
      reset_serial_clock(serial_clk);
      serial_data         <= '0';
      tx_word             <= (others => '0');
      state               <= idle;
      serial_slave_select <= '1';
      rx_word             <= (others => '0');
      rxfifo_nWR          <= '1';
      baud_tick_count     <= 0;
    elsif rising_edge(CLK) then
      txfifo_nRD          <= txfifo_nRD_next;
      serial_clk          <= serial_clk_next;
      serial_data         <= serial_data_next;
      tx_word             <= tx_word_next;
      state               <= state_next;
      serial_slave_select <= serial_slave_select_next;
      rxfifo_nWR          <= rxfifo_nWR_next;
      rx_word             <= rx_word_next;
      baud_tick_count     <= baud_tick_count_next;
    end if;

  end process;


  -- SPI baud tick generator

  process (CLK)
  begin

    if rising_edge(CLK) then
      
      baud_count <= baud_count + 1;
      baud_tick  <= '0';

      if (baud_count >= (integer(CLOCK_FREQ / SPI_FREQ / 2.0) - 1)) then
        baud_count <= 0;
        baud_tick  <= '1';
      end if;
      
    end if;

  end process;

  process (CLK, serial_status, state,
           txfifo_nRD, tx_word, serial_clk,
           baud_tick, txfifo_rd_data, serial_data,
           MISO, rx_word, baud_tick_count
           )
    variable conv_vector : UNSIGNED (1 downto 0);
  begin
    
    state_next               <= state;
    serial_clk_next          <= serial_clk;
    txfifo_nRD_next          <= '1';
    tx_word_next             <= tx_word;
    serial_data_next         <= serial_data;
    serial_slave_select_next <= '1';
    rxfifo_nWR_next          <= '1';
    rx_word_next             <= rx_word;
    baud_tick_count_next     <= baud_tick_count;

    case state is
      when idle =>
        reset_serial_clock(serial_clk_next);

        serial_data_next <= '0';
        if (serial_status(1) = '0') then
          state_next <= latchtx;
        end if;
      when latchtx =>
        tx_word_next             <= txfifo_rd_data;
        serial_slave_select_next <= '0';
        baud_tick_count_next     <= 0;

        if (serial_status(1) = '0') then
          state_next <= txbits;
        else
          state_next <= idle;
        end if;
      when txbits =>
        
        serial_slave_select_next <= '0';

        if (baud_tick = '1') then
          
          baud_tick_count_next <= baud_tick_count + 1;
          serial_data_next     <= tx_word(BITS - 1);

                                        -- SPI Mode 0
                                        -- generate clock

          if SPI_MODE = 0 then
            
            conv_vector     := to_unsigned(baud_tick_count mod 2, 2);
            serial_clk_next <= conv_vector(0);

            if (baud_tick_count > 0) and (conv_vector(0) = '1') then
              tx_word_next <= tx_word(BITS - 2 downto 0) & '0';  -- TODO: quiescent TX (hi or lo)
            end if;

            if conv_vector(0) = '1' then
              rx_word_next <= rx_word(BITS - 2 downto 0) & MISO;
            end if;

            if (baud_tick_count = BITS * 2) then
              state_next      <= pollTxFifo;
              txfifo_nRD_next <= '0';
              rxfifo_nWR_next <= '0';
            end if;
            
          elsif SPI_MODE = 1 then
            
            conv_vector     := to_unsigned(baud_tick_count mod 2, 2);
            serial_clk_next <= conv_vector(0);

            if (baud_tick_count > 1) and (conv_vector(0) = '0') then
              tx_word_next <= tx_word(BITS - 2 downto 0) & '0';  -- TODO: quiescent TX (hi or lo)
            end if;

            if (baud_tick_count > 1) and (conv_vector(0) = '0') then
              rx_word_next <= rx_word(BITS - 2 downto 0) & MISO;
            end if;

            if (baud_tick_count = BITS * 2) then
              state_next      <= pollTxFifo;
              txfifo_nRD_next <= '0';
              rxfifo_nWR_next <= '0';
            end if;
            
            
          elsif SPI_MODE = 2 then
            
            conv_vector     := to_unsigned(baud_tick_count mod 2, 2);
            serial_clk_next <= not conv_vector(0);

            if (baud_tick_count > 0) and (conv_vector(0) = '1') then
              tx_word_next <= tx_word(BITS - 2 downto 0) & '0';  -- TODO: quiescent TX (hi or lo)
            end if;

            if conv_vector(0) = '1' then
              rx_word_next <= rx_word(BITS - 2 downto 0) & MISO;
            end if;

            if (baud_tick_count = BITS * 2) then
              state_next      <= pollTxFifo;
              txfifo_nRD_next <= '0';
              rxfifo_nWR_next <= '0';
            end if;
            
            
          elsif SPI_MODE = 3 then
            
            conv_vector     := to_unsigned(baud_tick_count mod 2, 2);
            serial_clk_next <= not conv_vector(0);

            if (baud_tick_count > 1) and (conv_vector(0) = '0') then
              tx_word_next <= tx_word(BITS - 2 downto 0) & '0';  -- TODO: quiescent TX (hi or lo)
            end if;

            if (baud_tick_count > 1) and (conv_vector(0) = '0') then
              rx_word_next <= rx_word(BITS - 2 downto 0) & MISO;
            end if;

            if (baud_tick_count = BITS * 2) then
              state_next      <= pollTxFifo;
              txfifo_nRD_next <= '0';
              rxfifo_nWR_next <= '0';
            end if;
            
            
            
          end if;
          
        end if;
        
        
      when others =>  -- pollTxFifo is necessary to keep the slave select low when transferring multiple bytes
        
        reset_serial_clock(serial_clk_next);

        serial_slave_select_next <= '0';

        if (serial_status(1) = '0') then
          state_next <= latchtx;
        else
          state_next <= idle;
        end if;

    end case;
    
  end process;

  SCK    <= serial_clk;
  MOSI   <= serial_data;
  nSS    <= serial_slave_select;
  status <= serial_status;
  
end RTL;

