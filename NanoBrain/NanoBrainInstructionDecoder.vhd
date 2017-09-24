--
--
--      NanoBrainInstructionDecoder
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.NanoBrainInternal.all;

entity NanoBrainInstructionDecoder is
  port (

    -- 00 = select zeros, 01 = reg x, 10 = reg x * 2, 11 = reg0/reg1
    x_sel : out std_logic_vector(1 downto 0);
    -- 00 = select zeros, 01 = reg y, 10 = imm
    y_sel : out std_logic_vector(1 downto 0);
    -- 00 = select zeros, 01 = reg x * 2 + 1
    z_sel : out std_logic;
    u_sel : out std_logic;
    v_sel : out std_logic;
    c_sel : out std_logic;

    stage_2_instruction  : in  instruction_t;
    stage_2_pc           : in  unsigned(22 downto 0);
    decoded_imm_reg_next : out reg16_t;
    decoded_op           : out Op;
    decoded_ipu_op       : out IPU_Op;
    decoded_bs_op        : out BS_Op;
    decoded_fpu_op       : out FPU_Op;
    decoded_fc_op        : out FC_Op;
    decoded_io_op        : out IO_Op

    );
end NanoBrainInstructionDecoder;

architecture RTL of NanoBrainInstructionDecoder is
begin

  process (stage_2_instruction, stage_2_pc)
    variable i : instruction_t;
  begin

    i := stage_2_instruction;

    decoded_imm_reg_next <= (others => '0');

    decoded_op <= OP_NOP;

    decoded_ipu_op <= IPUOP_NOP;
    decoded_bs_op  <= BSOP_NOP;
    decoded_fpu_op <= FPUOP_NOP;
    decoded_io_op  <= IO_NOP;
    decoded_fc_op  <= FC_NOP;

    x_sel <= "00";
    y_sel <= "00";
    z_sel <= '0';

    u_sel <= '0';
    v_sel <= '0';
    c_sel <= '0';

    case i(15 downto 14) is
      when "00" =>                      -- imm instruction
        decoded_imm_reg_next <= "00" & i(13 downto 0);
      when "01" =>                      -- alu
        case i(13 downto 8) is
          -- ALU  IP add rx, ry        | 01 000000  xxxx  yyyy 
          when "000000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_ADD;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP add rx, kkk       | 01 100000  xxxx  bbbb 
          when "100000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_ADD;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP adc rx, ry        | 01 010000  xxxx  yyyy
          when "010000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_ADC;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP adc rx, kkk       | 01 110000  xxxx  bbbb 
          when "110000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_ADC;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP sub rx, ry        | 01 001000  xxxx  yyyy
          when "001000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_SUB;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP sub rx, kkk       | 01 101000  xxxx  bbbb
          when "101000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_SUB;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP sbb rx, ry        | 01  011000 xxxx  yyyy 
          when "011000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_SBB;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP sbb rx, kkk       | 01  111000 xxxx  bbbb
          when "111000" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_SBB;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP and rx, ry        | 01  000100 xxxx  yyyy
          when "000100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_AND;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP and rx, kkk       | 01  100100 xxxx  bbbb
          when "100100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_AND;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP or  rx, ry        | 01  010100 xxxx  yyyy
          when "010100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_OR;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP or  rx, kkk       | 01  110100 xxxx  bbbb
          when "110100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_OR;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP xor rx, ry        | 01  001100 xxxx  yyyy
          when "001100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_XOR;
            x_sel          <= "01";
            y_sel          <= "01";
          -- ALU  IP xor rx, kkk       | 01  101100 xxxx  kkkk
          when "101100" =>
            decoded_op     <= OP_IPU;
            decoded_ipu_op <= IPUOP_XOR;
            x_sel          <= "01";
            y_sel          <= "10";
          -- ALU  IP sla rx            | 01  011100 xxxx  0000
          -- ALU  IP slx rx            | 01  011100 xxxx  0001
          -- ALU  IP sl0 rx            | 01  011100 xxxx  0010  
          -- ALU  IP sl1 rx            | 01  011100 xxxx  0011  
          -- ALU  IP rl  rx            | 01  011100 xxxx  0100
          when "011100" =>
            decoded_op <= OP_IPU;
            x_sel      <= "01";
            y_sel      <= "00";
            case i(3 downto 0) is
              when "0000" =>
                decoded_ipu_op <= IPUOP_SLA;
              when "0001" =>
                decoded_ipu_op <= IPUOP_SLX;
              when "0010" =>
                decoded_ipu_op <= IPUOP_SL0;
              when "0011" =>
                decoded_ipu_op <= IPUOP_SL1;
              when "0100" =>
                decoded_ipu_op <= IPUOP_RL;
				  when others =>
					 decoded_ipu_op <= IPUOP_NOP;
            end case;
          -- ALU  IP sra rx            | 01  111100 xxxx  0000
          -- ALU  IP srx rx            | 01  111100 xxxx  0001
          -- ALU IP sr0 rx             | 01  111100 xxxx  0010
          -- ALU IP sr1 rx             | 01  111100 xxxx  0011
          -- ALU IP rr rx              | 01  111100 xxxx  0100
          when "111100" =>
            decoded_op <= OP_IPU;
            x_sel      <= "01";
            y_sel      <= "00";
            case i(3 downto 0) is
              when "0000" =>
                decoded_ipu_op <= IPUOP_SRA;
              when "0001" =>
                decoded_ipu_op <= IPUOP_SRX;
              when "0010" =>
                decoded_ipu_op <= IPUOP_SR0;
              when "0011" =>
                decoded_ipu_op <= IPUOP_SR1;
              when "0100" =>
                decoded_ipu_op <= IPUOP_RR;
				  when others =>
					 decoded_ipu_op <= IPUOP_NOP;
            end case;
          -- ALU IP cmp rx, ry         | 01  000010 xxxx  yyyy
          when "000010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_CMP;
          -- ALU IP cmp rx, bbb        | 01  100010 xxxx  bbbb
          when "100010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "10";
            decoded_ipu_op <= IPUOP_CMP;
          -- ALU IP test rx, ry        | 01  010010 xxxx  yyyy
          when "010010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_TEST;
          -- ALU IP test rx, bbb       | 01  110010 xxxx  bbbb
          when "110010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "10";
            decoded_ipu_op <= IPUOP_TEST;
          -- ALU IP load rx, ry        | 01  001010 xxxx  yyyy
          when "001010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_LOAD;
          -- ALU IP load rx, bbb       | 01  101010 xxxx  bbbb
          when "101010" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "01";
            y_sel          <= "10";
            decoded_ipu_op <= IPUOP_LOAD;
          -- ALU IP mul rx, ry         | 01  000110 0xxx  yyyy
          when "000110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_MUL;
          -- ALU IP mul rx, bbb        | 01  100110 0xxx  bbbb
          when "100110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "10";
            decoded_ipu_op <= IPUOP_MUL;
          -- ALU IP muls rx, ry        | 01  010110 0xxx  yyyy
          when "010110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_MULS;
          -- ALU IP muls rx, bbb       | 01  110110 0xxx  bbbb
          when "110110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "01";
            decoded_ipu_op <= IPUOP_MULS;
          -- ALU IP div rx, ry         | 01  001110 0xxx  yyyy
          when "001110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "01";
            z_sel          <= '1';
            decoded_ipu_op <= IPUOP_DIV;
          -- ALU IP div rx, bbb        | 01  101110 0xxx  bbbb
          when "101110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "10";
            z_sel          <= '1';
            decoded_ipu_op <= IPUOP_DIV;
          -- ALU IP divs rx, ry        | 01  011110 0xxx  yyyy
          when "011110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "10";
            z_sel          <= '1';
            decoded_ipu_op <= IPUOP_DIVS;
          -- ALU IP divs rx, bbb       | 01  111110 0xxx  bbbb
          when "111110" =>
            decoded_op     <= OP_IPU;
            x_sel          <= "10";
            y_sel          <= "10";
            z_sel          <= '1';
            decoded_ipu_op <= IPUOP_DIVS;
          -- ALU BS bsl                | 01  000001 xxxx  bbbb
          when "000001" =>
            decoded_op    <= OP_BS;
            x_sel         <= "01";
            decoded_bs_op <= BSOP_SL;
          -- ALU BS bsr                | 01  100001 xxxx  bbbb
          when "100001" =>
            decoded_op    <= OP_BS;
            x_sel         <= "01";
            decoded_bs_op <= BSOP_SR;
          -- ALU FP fmul               | 01  000011 0000  uuvv
          when "000011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_MUL;
            u_sel          <= '1';
            v_sel          <= '1';
          -- ALU FP fdiv               | 01  100011 0000  uuvv
          when "100011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_DIV;
            u_sel          <= '1';
            v_sel          <= '1';
          -- ALU FP fadd               | 01  010011 0000  uuvv
          when "010011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_ADD;
            u_sel          <= '1';
            v_sel          <= '1';
          -- ALU FP fsub               | 01  110011 0000  uuvv
          when "110011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_SUB;
            u_sel          <= '1';
            v_sel          <= '1';
          -- ALU FP fcmp               | 01  001011 0000  uuvv
          when "001011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_CMP;
            u_sel          <= '1';
            v_sel          <= '1';
          -- ALU FP fint               | 01  101011 0000  uu00
          when "101011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_INT;
            u_sel          <= '1';
          -- ALU FP fflt               | 01  011011 0000  uu00
          when "011011" =>
            decoded_op     <= OP_FPU;
            decoded_fpu_op <= FPUOP_FLT;
            u_sel          <= '1';
          -- ALU C nop                 | 01  000111 0000  0000
          when "000111" =>
            decoded_op <= OP_NOP;
          -- ALU C sleep               | 01  001111 0000  0000 
          when "001111" =>
            decoded_op <= OP_SLEEP;
			 when others =>
				decoded_op <= OP_NOP;
        end case;
      when "10" =>                      -- fc
        decoded_op <= OP_FC;
        case i(13 downto 9) is
          -- FC   NA jump              | 10 00010 ccccccccc  
          when "00010" =>
            decoded_fc_op <= FC_JUMP;
            c_sel         <= '0';
          -- FC   NA jump nz           | 10 00000 ccccccccc
          when "00000" =>
            decoded_fc_op <= FC_JUMPNZ;
            c_sel         <= '0';
          -- FC   NA jump z            | 10 01000 ccccccccc
          when "01000" =>
            decoded_fc_op <= FC_JUMPZ;
            c_sel         <= '0';
          -- FC   NA jump nc           | 10 00100 ccccccccc
          when "00100" =>
            decoded_fc_op <= FC_JUMPNC;
            c_sel         <= '0';
          -- FC   NA jump c            | 10 01100 ccccccccc
          when "01100" =>
            decoded_fc_op <= FC_JUMPC;
            c_sel         <= '0';
          -- FC   NA jump rel          | 10 00011 ccccccccc
          when "00011" =>
            decoded_fc_op <= FC_JUMP_REL;
            c_sel         <= '1';
          -- FC   NA jump rel nz       | 10 00001 ccccccccc
          when "00001" =>
            decoded_fc_op <= FC_JUMPNZ_REL;
            c_sel         <= '1';
          -- FC   NA jump rel z        | 10 01001 ccccccccc
          when "01001" =>
            decoded_fc_op <= FC_JUMPZ_REL;
            c_sel         <= '1';
          -- FC   NA jump rel nc       | 10 00101 ccccccccc
          when "00101" =>
            decoded_fc_op <= FC_JUMPNC_REL;
            c_sel         <= '1';
          -- FC   NA jump rel c        | 10 01101 ccccccccc
          when "01101" =>
            decoded_fc_op <= FC_JUMPC_REL;
            c_sel         <= '1';
          -- FC   NA call              | 10 10010 ccccccccc
          when "10010" =>
            decoded_fc_op <= FC_CALL;
            c_sel         <= '0';
          -- FC   NA call nz           | 10 10000 ccccccccc
          when "10000" =>
            decoded_fc_op <= FC_CALLNZ;
            c_sel         <= '0';
          -- FC   NA call z            | 10 11000 ccccccccc
          when "11000" =>
            decoded_fc_op <= FC_CALLZ;
            c_sel         <= '0';
          -- FC   NA call nc           | 10 10100 ccccccccc
          when "10100" =>
            decoded_fc_op <= FC_CALLNC;
            c_sel         <= '0';
          -- FC   NA call c            | 10 11100 ccccccccc
          when "11100" =>
            decoded_fc_op <= FC_CALLC;
            c_sel         <= '0';
          -- FC   NA call rel          | 10 10011 ccccccccc
          when "10011" =>
            decoded_fc_op <= FC_CALL_REL;
            c_sel         <= '1';
          -- FC   NA call rel nz       | 10 10001 ccccccccc
          when "10001" =>
            decoded_fc_op <= FC_CALLNZ_REL;
            c_sel         <= '1';
          -- FC   NA call rel z        | 10 11001 ccccccccc
          when "11001" =>
            decoded_fc_op <= FC_CALLZ_REL;
            c_sel         <= '1';
          -- FC   NA call rel nc       | 10 10101 ccccccccc
          when "10101" =>
            decoded_fc_op <= FC_CALLNC_REL;
            c_sel         <= '1';
          -- FC   NA call rel c        | 10 11101 ccccccccc
          when "11101" =>
            decoded_fc_op <= FC_CALLC_REL;
            c_sel         <= '1';
          -- FC   NA svc               | 10 01111 000000000
          when "01111" =>
            decoded_fc_op <= FC_SVC;
            c_sel         <= '0';
          -- FC   NA ret               | 10 11111 000000000  
          -- FC   NA reti              | 10 11111 000000001 
          -- FC   NA rete              | 10 11111 000000010
          when "11111" =>
            case i(1 downto 0) is
              when "00" =>
                decoded_fc_op <= FC_RET;
              when "01" =>
                decoded_fc_op <= FC_RETI;
              when "11" =>
                decoded_fc_op <= FC_RETE;
              when others =>
            end case;
            c_sel <= '0';
          when others =>

        end case;
      when "11" =>                      -- io
        decoded_op <= OP_IO;
      --if i(13) = '0' then
      --  case i(12 downto 10) is
      --    -- IO   NA ldw r0/r1, ccc    | 11  0 000  x  c  c  c  c  c  c  c  c  c  |
      --    when "0000" =>
      --      c_sel         <= '1';
      --      iox_sel       <= "01";
      --      decoded_io_op <= IO_LDW;
      --    -- IO   NA ldw rx, [IDy + 2b]| 11  0 001  x  x  x  x  y  y  b  b  b  b  | 
      --    when "0001" =>
      --      iox_sel       <= "00";
      --      ioy_sel       <= "01";
      --      iob_sel       <= '1';
      --      decoded_io_op <= IO_LDW_IND;
      --    -- IO   NA ldspr rx:rx+1,SPRy| 11  0 010  xxx 000 yyyy  | 
      --    -- IO   NA incpr  IDy        | 11  0 010  000 010 00yy  | 
      --    -- IO   NA decpr  IDy        | 11  0 010  000 011 00yy  | 
      --    when "0010" =>
      --      case i(6 downto 4) is
      --        when "000" =>
      --          iox_sel       <= "11";
      --          ioy_sel       <= "10";
      --          decoded_io_op <= IO_LDSPR;
      --        when "010" =>
      --          iox_sel       <= "00";
      --          ioy_sel       <= "11";
      --          decoded_io_op <= IO_LDSPR;
      --        when "011" =>
      --          iox_sel       <= "00";
      --          ioy_sel       <= "11";
      --          decoded_io_op <= IO_LDSPR;
      --        when others =>
      --      end case;
      --    -- IO   NA ldpid             | 11  0 011  00  xxxx  0000  | 
      --    -- IO   NA ldtlb             | 11  0 011  10  xxx  ddddd  | 
      --    -- IO   NA mbar              | 11  0 011  11  0000  bbbb  |
      --    when "0011" =>
      --      case i(9 downto 8) is
      --        when "00" =>
      --          decoded_io_op <= IO_LDPID;
      --        when "10" =>
      --          decoded_io_op <= IO_LDTLB;
      --        when "11" =>
      --          decoded_io_op <= IO_LDSPR;
      --      end case;
      --    -- IO   NA stw r0/r1, ccc    | 11  0 100  x  c  c  c  c  c  c  c  c  c  |  
      --    when "0100" =>
      --      decoded_io_op <= IO_STW;
      --    -- IO   NA stw rx, [IDy + 2b]| 11  0 101  x  x  x  x  y  y  b  b  b  b  | 
      --    when "0101" =>
      --      decoded_io_op <= IO_STW_IND;
      --    -- IO   NA stspr rx:rx+1,SPRy| 11  0 110  x  x  x  0  0  0  y  y  y  y  | 
      --    when "0110" =>
      --      decoded_io_op <= IO_STSPR;
      --    -- IO   NA cmpxchg           | 11  0 111  x  x  x  x  y  y  y  y  z  z  | 
      --    when "0111" =>
      --      decoded_io_op <= IO_CMPXCHG;
      --    when others =>
      --  end case;
      --else
      ---- could decode lots of instructions here
      --end if;
      when others =>
    end case;
  end process;

end RTL;

