--
--      PicoBrainTester, tester for Picoblaze compatible microcontroller core
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity PicoBrainTester is
  generic (
    ROM_SEL    : natural := 1;          -- select which test rom to instantiate
    CLOCK_FREQ : integer := 50000000
    );
  port (
    UART_TXD : out std_logic;
    UART_RXD : in  std_logic;

    -- CLK50
    -- TODO: generate clock from 24MHz clock using PLL

    CLOCK_50 : in std_logic;

    -- use 1 key for asynchronous reset

    KEY : in std_logic_vector (3 downto 0) := "1111";

    -- hex display

    HEX0 : out std_logic_vector(7 downto 0);
    HEX1 : out std_logic_vector(7 downto 0);
    HEX2 : out std_logic_vector(7 downto 0);
    HEX3 : out std_logic_vector(7 downto 0);

    -- LEDs

    LEDR : out std_logic_vector(9 downto 0);
    LEDG : out std_logic_vector(7 downto 0);

    -- Switches

    SW : in std_logic_vector(9 downto 0)

    );
end PicoBrainTester;

architecture RTL of PicoBrainTester is

  -- The PicoBrain

  component PicoBrain is
    port (
      address       : out std_logic_vector (9 downto 0);
      instruction   : in  std_logic_vector (17 downto 0);
      port_id       : out std_logic_vector (7 downto 0);
      write_strobe  : out std_logic;
      out_port      : out std_logic_vector (7 downto 0);
      read_strobe   : out std_logic;
      in_port       : in  std_logic_vector (7 downto 0);
      interrupt     : in  std_logic;
      interrupt_ack : out std_logic;
      reset         : in  std_logic;
      clk           : in  std_logic
      );
  end component;

  -- Test ROMs

  component test_rom_1 is

    port
      (
        clk  : in  std_logic;
        addr : in  natural range 0 to 1023;
        q    : out std_logic_vector(17 downto 0)
        );

  end component;

  component test_rom_2 is

    port
      (
        clk  : in  std_logic;
        addr : in  natural range 0 to 1023;
        q    : out std_logic_vector(17 downto 0)
        );

  end component;


  -- UARTLite

  component UARTLite is
    generic (
      TX_FIFO_DEPTH : integer := 2;
      RX_FIFO_DEPTH : integer := 2;
      BAUD_RATE     : integer := 115200;
      CLOCK_FREQ    : integer := CLOCK_FREQ
      );
    port (
      TX      : out std_logic;
      RX      : in  std_logic;
      CLK     : in  std_logic;
      nRST    : in  std_logic;
      WR_DATA : in  std_logic_vector (31 downto 0);
      RD_DATA : out std_logic_vector (31 downto 0);
      ADDR    : in  std_logic_vector (1 downto 0);
      n_WR    : in  std_logic;
      n_RD    : in  std_logic
      );
  end component;

  -- signals

  signal rom_addr     : std_logic_vector(9 downto 0);
  signal rom_addr_nat : natural range 0 to 1023;
  signal rom_data     : std_logic_vector(17 downto 0);

  signal reset, n_reset : std_logic := '0';

  signal uart_wr_data, uart_rd_data : std_logic_vector(31 downto 0);
  signal uart_addr                  : std_logic_vector (1 downto 0);
  signal uart_n_WR, uart_n_RD       : std_logic;

  signal port_id, port_data_out, port_data_in : std_logic_vector(7 downto 0);
  signal port_wr_strobe, port_rd_strobe       : std_logic;

  signal HEX0_val, HEX0_next : std_logic_vector(7 downto 0);
  signal HEX1_val, HEX1_next : std_logic_vector(7 downto 0);
  signal HEX2_val, HEX2_next : std_logic_vector(7 downto 0);
  signal HEX3_val, HEX3_next : std_logic_vector(7 downto 0);

  signal LEDR_next_1 : std_logic_vector(7 downto 0);
  signal LEDR_next_2 : std_logic_vector(1 downto 0);
  signal LEDG_next   : std_logic_vector(7 downto 0);

  signal LEDR_val : std_logic_vector(9 downto 0);
  signal LEDG_val : std_logic_vector(7 downto 0);

  --
  --    interrupt signal *must* be synchronous with master clock. We filter the key press
  --  through two registers to prevent metastability.
  --
  signal interrupt, interrupt_next, interrupt_next_next : std_logic;

  signal interrupt_latch, interrupt_latch_next, interrupt_ack : std_logic;

begin

  interrupt_next_next <= not KEY(1) or not KEY(2);

  reset        <= not KEY(0);
  n_reset      <= KEY(0);
  rom_addr_nat <= to_integer(unsigned(rom_addr));

  rom0 : if ROM_SEL = 0 generate
    testrom1 :
      test_rom_1
        port map (
          clk  => CLOCK_50,
          addr => rom_addr_nat,
          q    => rom_data
          );
  end generate rom0;

  rom1 : if ROM_SEL = 1 generate
    testrom2 :
      test_rom_2
        port map (
          clk  => CLOCK_50,
          addr => rom_addr_nat,
          q    => rom_data
          );
  end generate rom1;


  uart0 : UARTLite
    port map (
      TX      => UART_TXD,
      RX      => UART_RXD,
      CLK     => CLOCK_50,
      nRST    => n_reset,
      WR_DATA => uart_wr_data,
      RD_DATA => uart_rd_data,
      ADDR    => uart_addr,
      n_WR    => uart_n_WR,
      n_RD    => uart_n_RD
      );

  pb0 : PicoBrain
    port map (
      address       => rom_addr,
      instruction   => rom_data,
      port_id       => port_id,
      write_strobe  => port_wr_strobe,
      out_port      => port_data_out,
      read_strobe   => port_rd_strobe,
      in_port       => port_data_in,
      interrupt     => interrupt_latch,
      interrupt_ack => interrupt_ack,
      reset         => reset,
      clk           => CLOCK_50
      );

  --
  --  Picoblaze ports:
  --  0 = UART TXD       - wo
  --  1 = UART RXD       - ro
  --  2 = UART Status    - ro
  --  3 = HEX0           - wo
  --  4 = HEX1           - wo
  --  5 = HEX2           - wo
  --  6 = HEX3           - wo
  --  7 = SW0            - ro
  --  8 = SW1            - ro
  --  9 = GREENLED       - wo
  -- 10 = REDLED0        - wo
  -- 11 = REDLED1        - wo

  uart_wr_data(7 downto 0) <= port_data_out;
  uart_n_WR                <= not port_wr_strobe when to_integer(unsigned(port_id)) = 0 else '1';

  uart_addr <= "00" when to_integer(unsigned(port_id)) = 0 else
               "01" when to_integer(unsigned(port_id)) = 1 else
               "11";

  uart_n_RD <= not port_rd_strobe when
               to_integer(unsigned(port_id)) = 1 or
               to_integer(unsigned(port_id)) = 2 else '1';

  port_data_in <= uart_rd_data(7 downto 0) when to_integer(unsigned(port_id)) = 2 else
                  "ZZZZZZZZ";

  HEX0 <= HEX0_val;
  HEX1 <= HEX1_val;
  HEX2 <= HEX2_val;
  HEX3 <= HEX3_val;
  LEDG <= LEDG_val;
  LEDR <= LEDR_val;

  HEX0_next <= port_data_out when to_integer(unsigned(port_id)) = 3 and port_wr_strobe = '1' else
               HEX0_val;

  HEX1_next <= port_data_out when to_integer(unsigned(port_id)) = 4 and port_wr_strobe = '1' else
               HEX1_val;

  HEX2_next <= port_data_out when to_integer(unsigned(port_id)) = 5 and port_wr_strobe = '1' else
               HEX2_val;

  HEX3_next <= port_data_out when to_integer(unsigned(port_id)) = 6 and port_wr_strobe = '1' else
               HEX3_val;

  LEDG_next <= port_data_out when to_integer(unsigned(port_id)) = 9 and port_wr_strobe = '1' else
               LEDG_val;

  LEDR_next_1 <= port_data_out when to_integer(unsigned(port_id)) = 10 and port_wr_strobe = '1' else
                 LEDR_val(7 downto 0);

  LEDR_next_2 <= port_data_out(1 downto 0) when to_integer(unsigned(port_id)) = 11 and port_wr_strobe = '1' else
                 LEDR_val(9 downto 8);

  -- latch the interrupt signal, and clear when interrupt is acked                              
  interrupt_latch_next <= '0' when interrupt_ack = '1' else
                          '1' when interrupt = '1' else
                          interrupt_latch;

  process (CLOCK_50, reset)
  begin
    if (reset = '1') then
      HEX0_val        <= (others => '0');
      HEX1_val        <= (others => '0');
      HEX2_val        <= (others => '0');
      HEX3_val        <= (others => '0');
      LEDG_val        <= (others => '0');
      LEDR_val        <= (others => '0');
      interrupt       <= '0';
      interrupt_next  <= '0';
      interrupt_latch <= '0';
    elsif rising_edge(CLOCK_50) then
      HEX0_val             <= HEX0_next;
      HEX1_val             <= HEX1_next;
      HEX2_val             <= HEX2_next;
      HEX3_val             <= HEX3_next;
      LEDR_val(7 downto 0) <= LEDR_next_1;
      LEDR_val(9 downto 8) <= LEDR_next_2;
      LEDG_val             <= LEDG_next;
      interrupt            <= interrupt_next;
      interrupt_next       <= interrupt_next_next;
      interrupt_latch      <= interrupt_latch_next;
    end if;
  end process;

end RTL;

