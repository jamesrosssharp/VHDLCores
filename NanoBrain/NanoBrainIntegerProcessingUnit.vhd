--
--       NanoBrain Integer Processing Unit
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.NanoBrainInternal.all;

entity NanoBrainIntegerProcessingUnit is
  generic (
    USE_MUL : integer;
    USE_DIV : integer
    );
port (
  -- 16 bit operand x
  operand_x : in  std_logic_vector(15 downto 0);
  -- 16 bit operand y
  operand_y : in  std_logic_vector(15 downto 0);
  -- 16 bit operand z (for e.g. div -> z:x / y) 
  operand_z : in  std_logic_vector(15 downto 0);
  -- 16 bit result low word 
  result_lo : out std_logic_vector(15 downto 0);
  -- 16 bit result high word
  result_hi : out std_logic_vector(15 downto 0);
  -- carry in
  C_in      : in  std_logic;
  -- carry out
  C_out     : out std_logic;
  -- Z in (for pass through)
  Z_in      : in  std_logic;
  -- zero out
  Z_out     : out std_logic;
  -- we will stall the pipeline eg. on a division instruction while it completes.
  busy      : out std_logic;
  -- operation
  op        : in  IPU_Op
  );
end NanoBrainIntegerProcessingUnit;

architecture RTL of NanoBrainIntegerProcessingUnit is
begin

  process (operand_x, operand_y, operand_z, Z_in, C_in, op)
    variable a : unsigned (16 downto 0);
    variable b : unsigned (16 downto 0);
    variable c : unsigned (16 downto 0);
    variable o : unsigned (16 downto 0);
    variable l : unsigned (15 downto 0);

    variable carry : std_logic;
    variable zero  : std_logic;
    
  begin
  
	 result_hi <= (others => '0');
	 result_lo <= (others => '0');
	 C_out <= C_in;
	 Z_out <= Z_in;
  
    case op is
      when IPUOP_ADD =>
        a := unsigned('0' & operand_x);
        b := unsigned('0' & operand_y);
        o := a + b;

        C_out     <= o(16);
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(o(15 downto 0));
        if o(15 downto 0) = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_ADC =>

        a := unsigned('0' & operand_x);
        b := unsigned('0' & operand_y);
        c := "0000000000000000" & C_in;
        o := a + b + c;

        C_out     <= o(16);
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(o(15 downto 0));
        if o(15 downto 0) = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_SUB =>

        a := unsigned('0' & operand_x);
        b := not ( unsigned('0' & operand_y)) + 1;
        o := a + b;

        C_out     <= o(16);
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(o(15 downto 0));
        if o(15 downto 0) = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_SBB =>

        a := unsigned('0' & operand_x);
        b := not (unsigned('0' & operand_y)) + 1;

        if (C_in = '1') then
          c := "11111111111111111";
        else
          c := "00000000000000000";
        end if;

        o := a + b + c;

        C_out     <= o(16);
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(o(15 downto 0));
        if o(15 downto 0) = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_AND =>

        result_hi <= (others => '0');
        l         := unsigned(operand_x and operand_y);
        result_lo <= std_logic_vector(l);
        C_out     <= '0';

        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_OR =>
        result_hi <= (others => '0');
        l         := unsigned(operand_x or operand_y);
        result_lo <= std_logic_vector(l);
        C_out     <= '0';

        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_XOR =>

        result_hi <= (others => '0');
        l         := unsigned(operand_x and operand_y);
        result_lo <= std_logic_vector(l);
        C_out     <= '0';

        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_SLA =>

        l :=  unsigned(operand_x(14 downto 0) & C_in);
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(15);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
        
      when IPUOP_SLX =>

        l := unsigned(operand_x(14 downto 0) & operand_x(0));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(15);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
      
      when IPUOP_SL0 =>

        l := unsigned(operand_x(14 downto 0) & '0');
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(15);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
      
      when IPUOP_SL1 =>

        l :=  unsigned(operand_x(14 downto 0) & '1');
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(15);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
  
      when IPUOP_RL =>

        l := unsigned(operand_x(14 downto 0) & operand_x(15));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(15);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
          
      when IPUOP_SRA =>

        l := unsigned(C_in & operand_x(15 downto 1));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(0);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
          
      when IPUOP_SRX =>

        l := unsigned(operand_x(15) & operand_x(15 downto 1));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(0);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
         
      when IPUOP_SR0 =>

        l := unsigned('0' & operand_x(15 downto 1));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(0);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
      
      when IPUOP_SR1 =>

        l := unsigned('1' & operand_x(15 downto 1));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(0);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
      
      when IPUOP_RR =>

        l := unsigned(operand_x(0) & operand_x(15 downto 1));
        result_hi <= (others => '0');
        result_lo <= std_logic_vector(l);
        C_out     <= operand_x(0);
        
        if l = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;
     
      when IPUOP_CMP =>

        result_hi <= (others => '0');
        result_lo <= operand_x;

        a := unsigned('0' & operand_x);
        b := not (unsigned('0' & operand_y)) + 1;
        o := a + b;

        C_out     <= o(16);
        if o(15 downto 0) = "0000000000000000" then
          Z_out <= '1';
        else
          Z_out <= '0';
        end if;

      when IPUOP_TEST =>

        result_lo  <= operand_x;
        l := unsigned(operand_x and operand_y);

        carry := '0';
        for i in l'range loop
          carry := carry xor (not l(i));
        end loop;

        zero := '1';
        for i in l'range loop
          zero := zero and (not l(i));
        end loop;

        C_out <= carry;
        Z_out <= zero;
        
      when IPUOP_LOAD =>

        result_hi <= (others => '0');
        result_lo <= operand_y;
        C_out     <= C_in;
        -- to do:
        Z_out     <= Z_in;

      --when IPUOP_MUL =>
        -- todo
      --when IPUOP_MULS =>
        -- todo
      --when IPUOP_DIV =>
        -- todo
      --when IPUOP_DIVS =>
        -- todo
      when others => -- e.g. IPUOP_NOP
        result_hi <= (others => '0');
        result_lo <= (others => '0');
        C_out <= C_in;
        Z_out <= Z_in;
    end case;
  end process;

end RTL;
