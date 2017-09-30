--
--      Top level of UART core
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity UARTLite is

  generic (
    TX_FIFO_DEPTH : integer := 2;       -- 2**2 = 16 depth
    RX_FIFO_DEPTH : integer := 2;
    BAUD_RATE     : integer := 115200;
    CLOCK_FREQ    : integer := 50000000;
    BAUD_BITS     : integer := 5
    );

  port (

    TX : out std_logic;
    RX : in  std_logic;

    CLK : in std_logic;

    nRST : in std_logic;

    -- Register interface (bus slave)

    WR_DATA : in  std_logic_vector (31 downto 0);
    RD_DATA : out std_logic_vector (31 downto 0);

    ADDR : in std_logic_vector (1 downto 0);  -- 2 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = BAUDGEN, 3 = CTRL

    n_WR : in std_logic;                -- active low, write to register 
    n_RD : in std_logic                 -- active low, read from register

    );

end UARTLite;

architecture RTL of UARTLite
is

  component BaudRateGeneratorLite is
    generic (
      CLOCK_FREQ : integer;
      BITS       : integer;
      BAUD_RATE  : integer
      );
    port (
      TICK : out std_logic;
      nRST : in  std_logic;
      CLK  : in  std_logic
      );
  end component;

  component Fifo is
    generic (
      DEPTH : integer;
      BITS  : integer
      );
    port (
      CLK     : in  std_logic;
      nRST    : in  std_logic;
      WR_DATA : in  std_logic_vector (BITS - 1 downto 0);
      n_WR    : in  std_logic;
      RD_DATA : out std_logic_vector (BITS - 1 downto 0);
      n_RD    : in  std_logic;
      full    : out std_logic;
      empty   : out std_logic
      );
  end component;

  component UARTTransmitterLite is
    port (
      CLK  : in std_logic;
      nRST : in std_logic;

      nTxStart : in  std_logic;
      nTxDone  : out std_logic;

      txData : in std_logic_vector (7 downto 0);

      baudTick : in std_logic;

      TXD : out std_logic
      );
  end component;

  component UARTReceiverLite is
    port (
      CLK  : in std_logic;
      nRST : in std_logic;

      nRxDone : out std_logic;

      rxData : out std_logic_vector (7 downto 0);

      baudTick : in std_logic;

      RXD : in std_logic;

      frameError : out std_logic
      );
  end component;

  signal txfifo_wr_data : std_logic_vector (7 downto 0);
  signal txfifo_nWR     : std_logic := '1';
  signal txfifo_rd_data : std_logic_vector (7 downto 0);
  signal txfifo_nRD     : std_logic := '1';

  signal rxfifo_wr_data : std_logic_vector (7 downto 0);
  signal rxfifo_nWR     : std_logic := '1';
  signal rxfifo_rd_data : std_logic_vector (7 downto 0);
  signal rxfifo_nRD     : std_logic := '1';

  --    Status register
  --
  --                    0                                                       |                               TX_FIFO_FULL
  --                    1                                                       |                               TX_FIFO_EMPTY
  --                    2                                                       |                               RX_FIFO_FULL
  --                    3                                                       |                               RX_FIFO_EMPTY
  --                    4                                                       |                               RX_OVERRUN
  --                    5                                                       |                               reserved
  --                    6                                                       |                               FRAME_ERROR

  signal status_reg      : std_logic_vector (7 downto 0);
  signal status_reg_next : std_logic_vector (7 downto 0);

  signal baud_tick : std_logic;

begin

  status_reg_next(7) <= '0';

  baud0 : BaudRateGeneratorLite generic map (
    CLOCK_FREQ => CLOCK_FREQ,
    BITS       => BAUD_BITS,  -- ceil(log2(clk_freq / baud_rate / 16))
    BAUD_RATE  => BAUD_RATE
    )
    port map (CLK  => CLK,
              TICK => baud_tick,
              nRST => nRST);

  txFifo0 : Fifo generic map (
    DEPTH => TX_FIFO_DEPTH,  -- TX_FIFO_DEPTH deep (can set this generic to descrease area if need be)
    BITS  => 8                          -- 8 bit (1 char) width
    )
    port map (CLK     => CLK,
              nRST    => nRST,
              WR_DATA => txfifo_wr_data,
              n_WR    => txfifo_nWR,
              RD_DATA => txfifo_rd_data,
              n_RD    => txfifo_nRD,
              full    => status_reg_next(0),
              empty   => status_reg_next(1)
              );

  tx0 : UARTTransmitterLite port map (CLK      => CLK,
                                      nRST     => nRST,
                                      nTxStart => status_reg(1),
                                      nTxDone  => txfifo_nRD,
                                      txData   => txfifo_rd_data,
                                      baudTick => baud_tick,
                                      TXD      => TX
                                      );

  rxFifo0 : Fifo generic map (
    DEPTH => RX_FIFO_DEPTH,
    BITS  => 8
    )
    port map (CLK     => CLK,
              nRST    => nRST,
              WR_DATA => rxfifo_wr_data,
              n_WR    => rxfifo_nWR,
              RD_DATA => rxfifo_rd_data,
              n_RD    => rxfifo_nRD,
              full    => status_reg_next(2),
              empty   => status_reg_next(3)
              );

  rx0 : UARTReceiverLite port map (
    CLK        => CLK,
    nRST       => nRST,
    nRxDone    => rxfifo_nWR,
    rxData     => rxfifo_wr_data,
    baudTick   => baud_tick,
    RXD        => RX,
    frameError => status_reg_next(6)
    );

  process(CLK, nRST)
  begin

    if nRST = '0' then
      status_reg <= (1 => '1', 3 => '1', others => '0');
    elsif CLK'event and CLK = '1' then

      -- synchronous transitions here

      status_reg <= status_reg_next;

    end if;
  end process;

  process (ADDR, WR_DATA, n_WR, rxfifo_rd_data, n_RD, status_reg)
  begin

    txfifo_wr_data <= (others => '0');
    txfifo_nWR     <= '1';

    RD_DATA    <= (others => '0');
    rxfifo_nRD <= '1';

    case ADDR is
      when "00" =>                      -- TX fifo

        txfifo_wr_data <= WR_DATA(7 downto 0);
        txfifo_nWR     <= n_WR;

      when "10" =>                      -- no register

        null;

      when "01" =>                      --      RX fifo

        RD_DATA(7 downto 0) <= rxfifo_rd_data;
        rxfifo_nRD          <= n_RD;

      when "11" =>                      -- status register

        RD_DATA(7 downto 0) <= status_reg;

      when others =>

        null;

    end case;

  end process;

  -- handle RX overrun
  process (rxFifo_nWR, status_reg)
  begin
    status_reg_next(4) <= status_reg(4);

    if (rxFifo_nWR = '0') then          -- if RX received 
      if (status_reg(2) = '1') then     -- and fifo is full
        status_reg_next(4) <= '1';      -- RX overrun detected
      else
        status_reg_next(4) <= '0';      -- clear rx overrun
      end if;
    end if;

  end process;


end RTL;
