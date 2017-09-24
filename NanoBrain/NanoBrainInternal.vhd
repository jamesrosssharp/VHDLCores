--
--      Internal definitions to NanoBrain
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package NanoBrainInternal is

  type IPU_Op is (IPUOP_ADD, IPUOP_ADC, IPUOP_SUB, IPUOP_SBB, IPUOP_AND, IPUOP_OR, IPUOP_XOR, IPUOP_SLA,
                  IPUOP_SLX, IPUOP_SL0, IPUOP_SL1, IPUOP_RL, IPUOP_SRA, IPUOP_SRX, IPUOP_SR0, IPUOP_SR1,
                  IPUOP_RR,  IPUOP_CMP, IPUOP_TEST, IPUOP_LOAD, IPUOP_MUL, IPUOP_MULS, IPUOP_DIV,
                  IPUOP_DIVS, IPUOP_NOP);
  
  type FPU_Op is (FPUOP_MUL, FPUOP_DIV, FPUOP_ADD, FPUOP_SUB, FPUOP_CMP, FPUOP_INT, FPUOP_FLT, FPUOP_NOP);
  
  type BS_Op  is (BSOP_SL, BSOP_SR, BSOP_NOP);
  
  type Op is (OP_IPU, OP_FPU, OP_BS, OP_FC, OP_IO, OP_NOP, OP_SLEEP);
  
  type FC_Op is (FC_JUMP, FC_JUMPNZ, FC_JUMPNC, FC_JUMPZ, FC_JUMPC,
                 FC_JUMP_REL, FC_JUMPNZ_REL, FC_JUMPNC_REL, FC_JUMPZ_REL, FC_JUMPC_REL,
                 FC_CALL, FC_CALLNZ, FC_CALLNC, FC_CALLZ, FC_CALLC,
                 FC_CALL_REL, FC_CALLNZ_REL, FC_CALLNC_REL, FC_CALLZ_REL, FC_CALLC_REL,
                 FC_RET, FC_RETI, FC_RETE, FC_SVC, FC_NOP);
					  
  -- TODO: fix this
  type IO_Op is ( IO_NOP );
  
  subtype instruction_t is std_logic_vector(15 downto 0);
  subtype reg16_t is std_logic_vector(15 downto 0);
  subtype reg32_t is std_logic_vector(31 downto 0);
  subtype address_t is unsigned(22 downto 0);
  
  constant NOP_INSTRUCTION : instruction_t := "0100011100000000";
  
end NanoBrainInternal;
