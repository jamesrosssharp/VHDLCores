--
--      "Picobrain", a Picoblaze compatible microcontroller core
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity PicoBrain is
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
end PicoBrain;

architecture RTL of PicoBrain is

  component picobrain_dual_port_ram is
    generic
      (
        DATA_WIDTH : natural := 10;  -- instantiate 128 10 bit words. 64 words
        -- for scratch pad ram, 64 words for call
        -- stack.
        ADDR_WIDTH : natural := 7
        );

    port
      (
        clk    : in  std_logic;
        addr_a : in  natural range 0 to 2**ADDR_WIDTH - 1;
        addr_b : in  natural range 0 to 2**ADDR_WIDTH - 1;
        data_a : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        data_b : in  std_logic_vector((DATA_WIDTH-1) downto 0);
        we_a   : in  std_logic := '1';
        we_b   : in  std_logic := '1';
        q_a    : out std_logic_vector((DATA_WIDTH -1) downto 0);
        q_b    : out std_logic_vector((DATA_WIDTH -1) downto 0)
        );
  end component;

  subtype register_t is std_logic_vector(7 downto 0);
  type register_bank_t is array(15 downto 0) of register_t;

  -- Declare the RAM signal.    
  signal register_bank : register_bank_t;

  signal pc, pc_next : natural range 0 to 1023 := 0;

  -- state
  type state_t is (fetch, decode);
  signal cycle, cycle_next : state_t := fetch;

  -- current op
  type op_t is (OP_ALU, OP_SHIFT, OP_LOGIC, OP_LOAD, OP_FETCH, OP_STORE, OP_OUTPUT, OP_INPUT, NOP);
  signal current_op : op_t;

  -- interrupt op
  type interrupt_op_t is (INTERRUPT_DISABLE, INTERRUPT_ENABLE, INTERRUPT_NOP);
  signal interrupt_op : interrupt_op_t;

  -- instruction literals 

  signal xxx, yyy : std_logic_vector(3 downto 0);
  signal kkk      : std_logic_vector(7 downto 0);
  signal aaa      : std_logic_vector(9 downto 0);
  
  -- operands
  signal op_a, op_out, op_b : std_logic_vector(7 downto 0);

  signal op_b_sel            : std_logic;
  constant OP_B_SEL_REGISTER : std_logic := '1';
  constant OP_B_SEL_LITERAL  : std_logic := '0';

  -- alu signals
  signal alu_out                : std_logic_vector(7 downto 0);
  signal alu_op                 : std_logic_vector(2 downto 0);
  signal alu_C_next, alu_Z_next : std_logic;

  -- shifter
  signal shift_out    : std_logic_vector(7 downto 0);
  signal shift_op     : std_logic_vector (3 downto 0);
  signal shift_C_next, shift_Z_next : std_logic;
  
  -- logical
  signal logical_out    : std_logic_vector(7 downto 0);
  signal logic_op     : std_logic_vector (1 downto 0);
  signal logical_C_next, logical_Z_next : std_logic;
  

  -- flags
  signal C, C_next, Z, Z_next, I, I_next : std_logic;

  -- scratchpad ram / call stack ram

  signal scratchpad_ram_addr                         : unsigned (5 downto 0);
  signal callstack_ram_addr, callstack_ram_addr_next : unsigned (5 downto 0);
  
  signal ram_addr_a : natural range 0 to 127;
  signal ram_addr_b : natural range 0 to 127;

  signal scratchpad_ram_data_in, scratchpad_ram_data_out : std_logic_vector(9 downto 0);
  signal callstack_ram_data_in, callstack_ram_data_out   : std_logic_vector(9 downto 0);
  signal wr_scratchpad, wr_callstack                     : std_logic;

  signal callstack_top : std_logic_vector(9 downto 0);

  -- flow control

  type fc_call_return_t is (FC_CALL, FC_JUMP, FC_RETURN, FC_INC, FC_NOP);

  signal fc_call_return : fc_call_return_t;
  signal fc_op          : std_logic_vector(2 downto 0);

  -- call stack control

  type callstack_op_t is (CALLSTACK_PUSH, CALLSTACK_POP, CALLSTACK_NOP);
  signal callstack_op : callstack_op_t;

begin

  -- combined ram for callstack and scratchpad.
  -- port a: scratchpad
  -- port b: callstack
  
  ram_addr_a <= to_integer('0' & scratchpad_ram_addr);
  ram_addr_b <= to_integer('1' & callstack_ram_addr);
  
  ram0 : picobrain_dual_port_ram port map
    (
      clk    => clk,
      addr_a => ram_addr_a,
      addr_b => ram_addr_b,
      data_a => scratchpad_ram_data_in,
      data_b => callstack_ram_data_in,
      we_a   => wr_scratchpad,
      we_b   => wr_callstack,
      q_a    => scratchpad_ram_data_out,
      q_b    => callstack_ram_data_out
      );

  --============================================================================
  --
  --                        Concurrent statements
  --
  --============================================================================

  -- assign next address
  address <= std_logic_vector(to_unsigned(pc, 10));

  -- get operands
  xxx <= instruction(11 downto 8);
  yyy <= instruction(7 downto 4);
  kkk <= instruction(7 downto 0);
  aaa <= instruction(9 downto 0);

  -- multiplex operands
  op_a <= register_bank(to_integer(unsigned(xxx)));
  op_b <= register_bank(to_integer(unsigned(yyy))) when op_b_sel = OP_B_SEL_REGISTER else
          kkk;

  op_out <= alu_out when current_op = OP_ALU else
            shift_out                           when current_op = OP_SHIFT else
            logical_out                         when current_op = OP_LOGIC else
            scratchpad_ram_data_out(7 downto 0) when current_op = OP_FETCH else
            op_b                                when current_op = OP_LOAD else
            in_port                             when current_op = OP_INPUT else
            op_a;

  -- output port & strobes

  out_port <= op_a when current_op = OP_OUTPUT else
              "ZZZZZZZZ";

  port_id <= op_b when current_op = OP_OUTPUT or current_op = OP_INPUT else
             "ZZZZZZZZ";

  read_strobe <= '1' when current_op = OP_INPUT else '0';
  write_strobe <= '1' when current_op = OP_OUTPUT else '0';

  -- multiplex next carry
  C_next <= alu_C_next when current_op = OP_ALU else
            shift_C_next   when current_op = OP_SHIFT else
            logical_C_next when current_op = OP_LOGIC else
            C;

  -- multiplex next zero flag
  Z_next <= alu_Z_next when current_op = OP_ALU else
            shift_Z_next   when current_op = OP_SHIFT else
            logical_Z_next when current_op = OP_LOGIC else
            Z;

  -- mutiplex next interrupt flag
  I_next <= '0' when interrupt_op = INTERRUPT_DISABLE else
            '1' when interrupt_op = INTERRUPT_ENABLE else
            I;

  -- assign scratchpad ram

  scratchpad_ram_addr <= unsigned(op_b(5 downto 0));  -- scratchpad ram address is always
                                            -- op b (either kkk or (sY)

  scratchpad_ram_data_in <= "00" & op_a;  -- always write into scratchpad ram from sX

  wr_scratchpad <= '1' when current_op = OP_STORE else '0';

  -- assign callstack ram

  callstack_ram_data_in <= std_logic_vector(to_unsigned(pc, 10));  -- we always write current PC into callstack ram

  callstack_ram_addr_next <= callstack_ram_addr + 1 when callstack_op = CALLSTACK_PUSH else
                             callstack_ram_addr - 1 when callstack_op = CALLSTACK_POP else
                             callstack_ram_addr;

  wr_callstack <= '1' when callstack_op = CALLSTACK_PUSH else
                  '0';

  callstack_top <= callstack_ram_data_out;

  --============================================================================
  --
  --                            State transition logic
  --
  --============================================================================

  process (clk, reset)
  begin

    if (reset = '1') then  -- is picoblaze reset active high or active low?

      cycle              <= fetch;
      callstack_ram_addr <= "000000";
      C                  <= '0';
      Z                  <= '0';
      I                  <= '0';
      pc                 <= 0;

    elsif rising_edge(clk) then

      pc                                       <= pc_next;
      register_bank(to_integer(unsigned(xxx))) <= op_out;  -- store result
      C                                        <= C_next;
      Z                                        <= Z_next;
      I                                        <= I_next;
      callstack_ram_addr                       <= callstack_ram_addr_next;
      cycle                                    <= cycle_next;

    end if;

  end process;

  --============================================================================
  --
  --                            Combination logic
  --
  --============================================================================

  -- ALU
  --
  --    Inputs: op_a, op_b, alu_op, C
  --
  --    AluOp:  
  --            "000"  - add (inA + inB)
  --            "001"  - adc (inA + inB + C)
  --            "010"  - sub (inA - inB)
  --            "011"  - sbb (inA - inB - C)
  --            "100"  - compare
  --            others - copy from inB to aluOut
  --

  process (op_a, op_b, alu_op, C)
    variable inA   : unsigned(8 downto 0);
    variable inB   : unsigned(8 downto 0);
    variable carry : unsigned(8 downto 0);
    variable sum   : unsigned(8 downto 0);
  begin

    case alu_op is
      when "000" =>                     -- inA + inB
        inA   := unsigned('0' & op_a);
        inB   := unsigned('0' & op_b);
        carry := (others => '0');
      when "001" =>                     -- inA + inB + carry
        inA   := unsigned('0' & op_a);
        inB   := unsigned('0' & op_b);
        carry := (0 => C, others => '0');
      when "010" | "100" =>             -- inA - inB, or compare
        inA   := unsigned('0' & op_a);
        inB   := not unsigned('0' & op_b) + 1;
        carry := (others => '0');
      when "011" =>                     -- inA - inB - carry
        inA := unsigned('0' & op_a);
        inB := not unsigned('0' & op_b) + 1;
        if C = '0' then
          carry := (others => '0');
        else
          carry := (others => '1');
        end if;
      when others =>                    -- nop
        inA   := unsigned('0' & op_a);
        inB   := (others => '0');
        carry := (others => '0');
    end case;

    sum := inA + inB + carry;

    -- determine output
    case alu_op is
      when "100" =>                     -- compare: result is discarded
        alu_out <= std_logic_vector(inA(7 downto 0));
      when others =>
        alu_out <= std_logic_vector(sum(7 downto 0));
    end case;

    alu_C_next <= sum(8);
    if sum(7 downto 0) = "00000000" then
      alu_Z_next <= '1';
    else
      alu_Z_next <= '0';
    end if;

  end process;


  -- Shifter
  --
  --    Inputs: op_a, shift_op, C
  --          
  --

  process (op_a, shift_op, C)
    variable result : std_logic_vector(7 downto 0);
  begin
    case shift_op is
      when "0000" =>                    -- SLA sX
        result       := op_a(6 downto 0) & C;
        shift_C_next <= op_a(7);
      when "0010" =>                    -- RL  sX
        result       := op_a(6 downto 0) & op_a(7);
        shift_C_next <= op_a(7);
      when "0100" =>                    -- SLX sX
        result       := op_a(6 downto 0) & op_a(0);
        shift_C_next <= op_a(7);
      when "0110" =>                    -- SL0 sX
        result       := op_a(6 downto 0) & '0';
        shift_C_next <= op_a(7);
      when "0111" =>                    -- SL1 sX
        result       := op_a(6 downto 0) & '1';
        shift_C_next <= op_a(7);
      when "1000" =>                    -- SRA sX
        result       := C & op_a(7 downto 1);
        shift_C_next <= op_a(0);
      when "1010" =>                    -- RR  sX
        result       := op_a(0) & op_a(7 downto 1);
        shift_C_next <= op_a(0);
      when "1100" =>                    -- SRX sX
        result       := op_a(7) & op_a(7 downto 1);
        shift_C_next <= op_a(0);
      when "1110" =>                    -- SR0 sX
        result       := '0' & op_a(7 downto 1);
        shift_C_next <= op_a(0);
      when "1111" =>                    -- SR1 sX
        result       := '1' & op_a(7 downto 1);
        shift_C_next <= op_a(0);
      when others =>
        result       := op_a;
        shift_C_next <= C;
    end case;

    if (result = "00000000") then
      shift_Z_next <= '1';
    else
      shift_Z_next <= '0';
    end if;

    shift_out <= result;

  end process;

  --
  --    Logic operations
  --
  --

  process (op_a, op_b, logic_op)
    variable result, result2 : std_logic_vector(7 downto 0);
    variable carry           : std_logic;
    variable zero            : std_logic;
  begin

    case logic_op is
      when "00" =>                      -- AND
        result := op_a and op_b;
        carry  := '0';

        zero := '1';
        for i in result'range loop
          zero := zero and (not result(i));
        end loop;

      when "01" =>                      -- OR
        result := op_a or op_b;
        carry  := '0';

        zero := '1';
        for i in result'range loop
          zero := zero and (not result(i));
        end loop;

      when "10" =>                      -- XOR
        result := op_a xor op_b;
        carry  := '0';

        zero := '1';
        for i in result'range loop
          zero := zero and (not result(i));
        end loop;

      when others =>                      -- TEST
        result  := op_a;
        result2 := op_a and op_b;

        carry := '0';
        for i in result2'range loop
          carry := carry xor (not result2(i));
        end loop;

        zero := '1';
        for i in result2'range loop
          zero := zero and (not result2(i));
        end loop;

    end case;

    logical_out    <= result;
    logical_C_next <= carry;
    logical_Z_next <= zero;

  end process;

  -- Next instruction logic

  process (pc, fc_call_return, fc_op, callstack_top, aaa, Z, C)
    variable fc_cond      : std_logic;
    variable next_address : natural range 0 to 1023;
	 variable inc_address  : natural range 0 to 1023;
  begin
  
    if pc = 1023 then
       inc_address := 0;
    else
       inc_address := pc + 1;
    end if;


    case fc_call_return is
      when FC_CALL =>
        next_address := to_integer(unsigned(aaa));
        callstack_op <= CALLSTACK_PUSH;
      when FC_JUMP =>
        next_address := to_integer(unsigned(aaa));
        callstack_op <= CALLSTACK_NOP;
      when FC_INC =>

                                        -- need to wrap PC, it is natural type.
		  next_address := inc_address;
        callstack_op <= CALLSTACK_NOP;
      when FC_RETURN =>
        next_address := to_integer(unsigned(callstack_top));
        callstack_op <= CALLSTACK_POP;
      when others =>                    -- NOP
        next_address := pc;
        callstack_op <= CALLSTACK_NOP;
    end case;

    case fc_op is
      when "100" =>                     -- CALL Z
        fc_cond := Z;
      when "101" =>                     -- CALL NZ
        fc_cond := not Z;
      when "110" =>                     -- CALL C
        fc_cond := C;
      when "111" =>                     -- CALL NC
        fc_cond := not C;
      when others =>                    -- unconditional jump / call / return
        fc_cond := '1';
    end case;

    if fc_cond = '1' then
      pc_next <= next_address;
    else
      pc_next <= inc_address;
    end if;

  end process;

  -- instruction decode

  process (cycle, pc, register_bank, instruction)
  begin

    -- assign defaults
    fc_op          <= "000";
    current_op     <= NOP;
    interrupt_op   <= INTERRUPT_NOP;
    alu_op         <= "111";
    shift_op       <= "0101";           -- nop
    logic_op       <= "00";             -- and
    op_b_sel       <= OP_B_SEL_REGISTER;

    case cycle is
      when fetch =>
        cycle_next <= decode;
		  fc_call_return <= FC_NOP;
    
      when decode =>
        cycle_next <= fetch;
		  fc_call_return <= FC_INC;
    
        case instruction(17 downto 14) is
          when "0000" =>                -- load
            current_op <= OP_LOAD;
            op_b_sel   <= instruction(12);
          when "0001" =>                -- input, fetch
            case instruction (13 downto 12) is
              when "00" =>              -- INPUT,"sX,pp"
                op_b_sel  <= OP_B_SEL_LITERAL;
                current_op <= OP_INPUT;
              when "01" =>              -- INPUT,"sX,(sY)"
                op_b_sel <= OP_B_SEL_REGISTER;
                current_op <= OP_INPUT;
              when "10" =>              -- FETCH,"sX,kk"
                op_b_sel   <= OP_B_SEL_LITERAL;
                current_op <= OP_FETCH;
              when "11" =>              -- FETCH,"sX,(sY)"
                op_b_sel   <= OP_B_SEL_REGISTER;
                current_op <= OP_FETCH;
              when others =>
            end case;
          when "0010" =>                -- and
            op_b_sel   <= instruction(12);
            current_op <= OP_LOGIC;
            logic_op   <= "00";
          when "0011" =>                -- or, xor
            current_op <= OP_LOGIC;
            op_b_sel   <= instruction(12);
            if (instruction(13) = '0') then
              logic_op <= "01";         -- or
            else
              logic_op <= "10";         -- xor
            end if;
          when "0100" =>                -- test
            op_b_sel   <= instruction(12);
            current_op <= OP_LOGIC;
            logic_op   <= "11";
          when "0101" =>                -- compare
            op_b_sel   <= instruction(12);
            current_op <= OP_ALU;
            alu_op     <= "100";
          when "0110" =>                -- add
            op_b_sel   <= instruction(12);
            current_op <= OP_ALU;
            if (instruction(13) = '0') then
              alu_op <= "000";
            else
              alu_op <= "001"; -- add with carry
            end if;
          when "0111" =>                -- sub
            op_b_sel   <= instruction(12);
            current_op <= OP_ALU;
            if (instruction(13) = '0') then
              alu_op <= "010";
            else
              alu_op <= "011"; -- sub with borrow
            end if;
          when "1000" =>                -- shift / rotate
            current_op <= OP_SHIFT;
            shift_op <= instruction(3 downto 0);
          when "1001" => 
			   null;
			when "1010" => -- return
            fc_call_return <= FC_RETURN;
            fc_op <= instruction(12 downto 10);
		    when "1011" =>                -- output / store
            case instruction(13 downto 12) is
              when "00" =>              -- OUTPUT sX, pp
                op_b_sel <= OP_B_SEL_LITERAL;
                current_op <= OP_OUTPUT;
              when "01" =>              -- OUTPUT sX, (sY)
                op_b_sel <= OP_B_SEL_REGISTER;
                current_op <= OP_OUTPUT;
              when "10" =>              -- STORE  sX, ss
                op_b_sel <= OP_B_SEL_LITERAL;
                current_op <= OP_STORE;
              when "11" =>              -- STORE  sX, (sY)
                op_b_sel <= OP_B_SEL_REGISTER;
                current_op <= OP_STORE;
              when others =>
            end case;
          when "1100" =>                -- call
            fc_call_return <= FC_CALL;
            fc_op <= instruction(12 downto 10);
          when "1101" =>                -- jump
            fc_call_return <= FC_JUMP;
            fc_op <= instruction(12 downto 10);
          when "1110" =>                -- return from interrupt
            -- TODO
          when "1111" =>                -- interrupt enable / disable
            case instruction(0) is
              when '0' =>               -- DISABLE INTERRUPT
                interrupt_op <= INTERRUPT_DISABLE;
              when '1' =>               -- ENABLE INTERRUPT
                interrupt_op <= INTERRUPT_ENABLE;
              when others =>
            end case;
          when others =>
        end case;
    end case;
  end process;

end RTL;
