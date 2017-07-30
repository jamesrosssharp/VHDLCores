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
                CLOCK_FREQ      : REAL := 50000000.0    -- frequency of driving clock
        );
        port (
        
                -- SD Card pins
                SD_DAT          : IN     STD_LOGIC;             -- MISO
                SD_CMD          : OUT    STD_LOGIC;             -- MOSI
                SD_CLK          : OUT    STD_LOGIC;             -- CLK
                SD_DAT3         : INOUT  STD_LOGIC;             -- \CS / card present
                
                -- UART Pins
                UART_TXD        :       OUT STD_LOGIC;
                UART_RXD        :      IN       STD_LOGIC;
        
                -- main clock
                CLOCK_50        :       IN      STD_LOGIC;

                -- KEY[0] used as asynchronous reset 
                KEY             :       IN STD_LOGIC_VECTOR (3 DOWNTO 0)
        
        );
end SDCardSPITester;
        
architecture RTL of SDCardSPITester is

        -- SDCardSPI core
        
        component SDCardSPI is
                generic (
                        CLOCK_FREQ : REAL := CLOCK_FREQ;
                );
                port (
                        SD_DAT  : IN     STD_LOGIC;             -- MISO
                        SD_CMD  : OUT    STD_LOGIC;             -- MOSI
                        SD_CLK  : OUT    STD_LOGIC;             -- CLK
                        SD_DAT3 : INOUT STD_LOGIC;              -- \CS / card present
                
                        CLK     : IN   STD_LOGIC;
                        nRST    : IN   STD_LOGIC;
                        
                );
        end component;
        
        
        -- UART core
        
        component UART is
                generic (
                        TX_FIFO_DEPTH   : INTEGER;
                        RX_FIFO_DEPTH   : INTEGER
                );
                port (
                
                        TX      : OUT STD_LOGIC;
                        RX      : IN  STD_LOGIC;
                        CLK     : IN  STD_LOGIC;
                        nRST    : IN  STD_LOGIC;
                        
                        -- Register interface (bus slave)
                        
                        WR_DATA :       IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
                        RD_DATA :       OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
                        
                        ADDR    :       IN       STD_LOGIC_VECTOR (1 DOWNTO 0); -- 4 registers, 0 = TXFIFO, 1 = RXFIFO, 2 = CTRL, 3 = STATUS
                        
                        n_WR    :       IN STD_LOGIC;   -- active low, write to register 
                        n_RD    :       IN STD_LOGIC  -- active low, read from register
                
                );
        end component;

        signal uart_wr_reg              : STD_LOGIC := '1';
        signal uart_wr_reg_next         : STD_LOGIC := '1';
        
        signal uart_addr                : STD_LOGIC_VECTOR (1 DOWNTO 0);
        signal uart_addr_next           : STD_LOGIC_VECTOR (1 DOWNTO 0);
        
        signal uart_wr_data             : STD_LOGIC_VECTOR (31 DOWNTO 0);
        signal uart_wr_data_next        : STD_LOGIC_VECTOR (31 DOWNTO 0);
        
        signal uart_rd_reg              : STD_LOGIC := '1';
        signal uart_rd_reg_next         : STD_LOGIC := '1';
        signal uart_rd_data             : STD_LOGIC_VECTOR (31 DOWNTO 0);

        signal sd_wr_reg                : STD_LOGIC := '1';
        signal sd_wr_reg_next           : STD_LOGIC := '1';
        
        signal sd_addr                  : STD_LOGIC_VECTOR (1 DOWNTO 0);
        signal sd_addr_next             : STD_LOGIC_VECTOR (1 DOWNTO 0);
        
        signal sd_wr_data               : STD_LOGIC_VECTOR (31 DOWNTO 0);
        signal sd_wr_data_next          : STD_LOGIC_VECTOR (31 DOWNTO 0);
        
        signal sd_rd_reg                : STD_LOGIC := '1';
        signal sd_rd_reg_next           : STD_LOGIC := '1';
        signal sd_rd_data               : STD_LOGIC_VECTOR (31 DOWNTO 0);

        signal n_sdRst                  : STD_LOGIC;
        
        type state_type is (reset, writeBanner, sendCMD0, sendCMD8, processCMD8Response, 
                            sendCMD58, processCMD58Response, sendCMD55, processCMD55Response, 
                            sendCMD41, processACMD41Response, sendCMD17, getBlockData, printRXData);                        
        
        signal state                    : state_type := reset;
        signal count                    : unsigned (4 DOWNTO 0) := "00000";     -- counter used as sub-state
        
        signal next_state               : state_type := reset;
        signal next_count               : unsigned (4 DOWNTO 0) := "00000";
        
begin
 
 
 u0:    UART generic map (
                TX_FIFO_DEPTH => 4,     -- 2**4 = 16 character FIFO
                RX_FIFO_DEPTH => 4
        )
        port map (
                TX              => UART_TXD,
                RX              => UART_RXD,
                CLK             => CLOCK_50,
                nRST            => n_uartRst,
                WR_DATA         => wr_data,
                RD_DATA         => rd_data,
                ADDR            => addr,
                n_WR            => wr_reg,
                n_RD            => rd_reg
             );

        process (CLOCK_50, KEY)
        begin
        
        
        end process;
         
end RTL;
 
