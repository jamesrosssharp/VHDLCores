--
--      NanoBrainSingleIssueInstructionPipeline : single issue instruction pipeline
--
--      1) need PC fetching instruction from cache and incrementing
--      2) implement flow control
--      3) implement integer instructions 
--      4) implement hazard detection
--      5) implement io instructions
--
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.NanoBrainInternal.all;

entity NanoBrainSingleIssueInstructionPipeline is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    -- icache

    icache_wr_data_a       : out std_logic_vector (15 downto 0);
    icache_rd_data_a       : in  std_logic_vector (15 downto 0);
    icache_data_sel_a      : out std_logic;
    icache_rd_req_a        : out std_logic;
    icache_wr_req_a        : out std_logic;
    icache_flush_req       : out std_logic;
    icache_invalidate_req  : out std_logic;
    icache_wr_data_b       : out std_logic_vector (15 downto 0);
    icache_rd_data_b       : in  std_logic_vector (15 downto 0);
    icache_data_sel_b      : out std_logic;
    icache_rd_req_b        : out std_logic;
    icache_wr_req_b        : out std_logic;
    icache_bypass          : out std_logic;
    icache_rd_ready_a      : in  std_logic;
    icache_wr_ready_a      : in  std_logic;
    icache_rd_ready_b      : in  std_logic;
    icache_wr_ready_b      : in  std_logic;
    icache_flush_done      : in  std_logic;
    icache_invalidate_done : in  std_logic;
    icache_address_a       : out unsigned (23 downto 0);
    icache_address_b       : out unsigned (23 downto 0);

    -- dcache

    dcache_wr_data_a       : out std_logic_vector (15 downto 0);
    dcache_rd_data_a       : in  std_logic_vector (15 downto 0);
    dcache_data_sel_a      : out std_logic;
    dcache_rd_req_a        : out std_logic;
    dcache_wr_req_a        : out std_logic;
    dcache_flush_req       : out std_logic;
    dcache_invalidate_req  : out std_logic;
    dcache_wr_data_b       : out std_logic_vector (15 downto 0);
    dcache_rd_data_b       : in  std_logic_vector (15 downto 0);
    dcache_data_sel_b      : out std_logic;
    dcache_rd_req_b        : out std_logic;
    dcache_wr_req_b        : out std_logic;
    dcache_bypass          : out std_logic;
    dcache_rd_ready_a      : in  std_logic;
    dcache_wr_ready_a      : in  std_logic;
    dcache_rd_ready_b      : in  std_logic;
    dcache_wr_ready_b      : in  std_logic;
    dcache_flush_done      : in  std_logic;
    dcache_invalidate_done : in  std_logic;
    dcache_address_a       : out unsigned (23 downto 0);
    dcache_address_b       : out unsigned (23 downto 0);

    -- connection to IPU
    ipu_operand_x : out std_logic_vector(15 downto 0);
    ipu_operand_y : out std_logic_vector(15 downto 0);
    ipu_operand_z : out std_logic_vector(15 downto 0);
    ipu_result_lo : in  std_logic_vector(15 downto 0);
    ipu_result_hi : in  std_logic_vector(15 downto 0);
    ipu_C_in      : out std_logic;
    ipu_C_out     : in  std_logic;
    ipu_Z_in      : out std_logic;
    ipu_Z_out     : in  std_logic;
    ipu_busy      : in  std_logic;
    ipu_op        : out IPU_Op;

    -- connection to FPU
    fpu_operand_x : out std_logic_vector(31 downto 0);
    fpu_operand_y : out std_logic_vector(31 downto 0);
    fpu_result    : in  std_logic_vector(31 downto 0);
    fpu_C_out     : in  std_logic;
    fpu_Z_out     : in  std_logic;
    -- when '1', FPU is busy with an operation. Pipeline must stall until it
    -- completes.
    fpu_busy      : in  std_logic;
    fpu_op        : out FPU_Op;

    -- connection to BS
    bs_operand_x : out std_logic_vector(15 downto 0);
    bs_shift     : out std_logic_vector(3 downto 0);
    bs_result    : in  std_logic_vector(15 downto 0);
    bs_C_in      : out std_logic;
    bs_C_out     : in  std_logic;
    bs_op        : out BS_Op
    );
end NanoBrainSingleIssueInstructionPipeline;

architecture RTL of NanoBrainSingleIssueInstructionPipeline is

  component NanoBrainInstructionDecoder is
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
      decoded_ipu_op       : out work.NanoBrainInternal.IPU_Op;
      decoded_bs_op        : out work.NanoBrainInternal.BS_Op;
      decoded_fpu_op       : out work.NanoBrainInternal.FPU_Op;
      decoded_fc_op        : out work.NanoBrainInternal.FC_Op;
      decoded_io_op        : out work.NanoBrainInternal.IO_Op

      );
  end component;

  signal pc, pc_next : unsigned (22 downto 0);

  --
  --    7-stage Pipeline :: stages
  --
  --    0:  fetch 0
  --    pc is output to stage_0_icache_portsel port.
  --    stage_0_icache_portsel_next <= not stage_0_icache_portsel
  --    stage_1_icache_portsel_next <= stage_0_icache_portsel
  --    pc_next muxed from pc + 1 and branch target on flush_pipeline signal.
  --
  --    1: fetch 1
  --    if rd_ready of port selected by stage_1_icache_portsel, then
  --    stage_2_instruction_next <= rd_data of selected port from icache
  --    else stage_1_stall <= '1' and fetch 0 stage will not increment pc etc,
  --    and stage_2_instruction_next will be set to nop instruction.
  --
  --    2: decode
  --    decoded outputs from instruction_decoder mulitplexed. stage_3_xyz_next
  --    selects either decoded outs. if stall in higher stage, stage_2_halt will
  --    be high and mux must select previous values.
  --
  --    3: execute
  --    decoded outputs from either IPU, BS or FPU muxed and registered for
  --    write back. C and Z updated. If IPU or FPU is busy, stage_3_stall will be high and
  --    previous stages must retain their previous values and nop will be
  --    transferred to stage 4. If stall in higher
  --    stage, stage_3_halt will be high and mux must select previous values.
  --    If flow control op, if conditions are met, flush_pipeline and
  --    branch_target will be propagated through pipeline and will take effect
  --    after write back stage.
  --
  --    4. memory 0
  --    Initial read / write cycle
  --
  --    5. memory 1
  --    Final read / write cycle - if cache misses, stage_5_stall will be high.
  --    Previous stages will retain their values. Once cache hits,
  --    stage_5_stall will go low.
  --
  --    6. write back
  --    Register writes.
  --

  signal flush_pipeline, flush_pipeline_next : std_logic;
  signal branch_target, branch_target_next   : address_t;

  -- pipeline stage 0 (fetch 0) signals

  signal stage_0_halt                                        : std_logic;
  signal stage_0_icache_portsel, stage_0_icache_portsel_next : std_logic;

  -- pipeline stage 1 (fetch 1) signals

  signal stage_1_pc, stage_1_pc_next                         : address_t;
  signal stage_1_halt                                        : std_logic;
  signal stage_1_stall                                       : std_logic;
  signal stage_1_icache_portsel, stage_1_icache_portsel_next : std_logic;

  -- pipeline stage 2 (decode) signals

  signal stage_2_halt                                  : std_logic;
  signal stage_2_stall                                 : std_logic;
  signal stage_2_instruction, stage_2_instruction_next : instruction_t;
  signal stage_2_pc, stage_2_pc_next                    : address_t;

  -- pipeline stage 3 (execute) signals

  signal stage_3_halt  : std_logic;
  signal stage_3_stall : std_logic;

  signal decoded_x_sel : std_logic_vector (1 downto 0);
  signal decoded_y_sel : std_logic_vector (1 downto 0);
  signal decoded_z_sel : std_logic;
  signal decoded_u_sel : std_logic;
  signal decoded_v_sel : std_logic;
  signal decoded_c_sel : std_logic;

  signal stage_3_ipu_op, stage_3_ipu_op_next, decoded_ipu_op : work.NanoBrainInternal.IPU_Op := IPUOP_NOP;
  signal stage_3_fpu_op, stage_3_fpu_op_next, decoded_fpu_op : work.NanoBrainInternal.FPU_Op := FPUOP_NOP;
  signal stage_3_bs_op, stage_3_bs_op_next, decoded_bs_op    : work.NanoBrainInternal.BS_Op  := BSOP_NOP;
  signal stage_3_op, stage_3_op_next, decoded_op             : work.NanoBrainInternal.Op     := OP_NOP;
  signal stage_3_fc_op, stage_3_fc_op_next, decoded_fc_op    : work.NanoBrainInternal.FC_Op  := FC_NOP;
  signal stage_3_io_op, stage_3_io_op_next, decoded_io_op    : work.NanoBrainInternal.IO_Op  := IO_NOP;

  signal stage_3_ipu_operand_x, stage_3_ipu_operand_x_next, decoded_operand_x : std_logic_vector(15 downto 0);
  signal stage_3_ipu_operand_y, stage_3_ipu_operand_y_next, decoded_operand_y : std_logic_vector(15 downto 0);
  signal stage_3_ipu_operand_z, stage_3_ipu_operand_z_next, decoded_operand_z : std_logic_vector(15 downto 0);

  signal stage_3_fpu_operand_x, stage_3_fpu_operand_x_next, decoded_operand_fx : std_logic_vector(31 downto 0);
  signal stage_3_fpu_operand_y, stage_3_fpu_operand_y_next, decoded_operand_fy : std_logic_vector(31 downto 0);

  signal stage_3_reg16_dest_lo, stage_3_reg16_dest_lo_next, decoded_reg16_dest_lo : std_logic_vector(15 downto 0);
  signal stage_3_reg16_dest_hi, stage_3_reg16_dest_hi_next, decoded_reg16_dest_hi : std_logic_vector(15 downto 0);

  signal stage_3_jump_target, stage_3_jump_target_next, decoded_jump_target : std_logic_vector(22 downto 0);

  -- 00 : no dest 01: dest lo 10: dest lo : dest hi
  signal stage_3_reg16_dest_sel, decoded_dest_sel : std_logic_vector(2 downto 0);

  -- pipeline stage 4 (memory access 0) signals

  signal stage_4_halt  : std_logic;
  signal stage_4_stall : std_logic;

  -- pipeline stage 5 (memory access 1) signals

  signal stage_5_halt  : std_logic;
  signal stage_5_stall : std_logic;

  -- pipeline stage 6 (write back) signals

  signal stage_6_halt  : std_logic;
  signal stage_6_stall : std_logic;

  -- registers

  -- immediate register
  signal imm_reg, imm_reg_next, decoded_imm_reg_next : reg16_t;

  type reg16_bank_t is array(15 downto 0) of reg16_t;
  type reg32_bank_t is array(15 downto 0) of reg32_t;

  signal reg16_bank         : reg16_bank_t;
  signal reg16_write_idx_a  : unsigned (3 downto 0);
  signal reg16_write_data_a : reg16_t;
  signal wr_reg16_a         : std_logic;
  signal reg16_write_idx_b  : unsigned (3 downto 0);
  signal reg16_write_data_b : reg16_t;
  signal wr_reg16_b         : std_logic;

  signal reg32_bank       : reg32_bank_t;
  signal reg32_write_idx  : unsigned (3 downto 0);
  signal reg32_write_data : reg32_t;
  signal wr_reg32         : std_logic;

begin

  -- component instantiations

  dec0 : NanoBrainInstructionDecoder
    port map (
      x_sel                => decoded_x_sel,
      y_sel                => decoded_y_sel,
      z_sel                => decoded_z_sel,
      u_sel                => decoded_u_sel,
      v_sel                => decoded_v_sel,
      c_sel                => decoded_c_sel,
      stage_2_instruction  => stage_2_instruction,
      stage_2_pc           => stage_2_pc,
      decoded_imm_reg_next => decoded_imm_reg_next,
      decoded_op           => decoded_op,
      decoded_ipu_op       => decoded_ipu_op,
      decoded_bs_op        => decoded_bs_op,
      decoded_fpu_op       => decoded_fpu_op,
      decoded_fc_op        => decoded_fc_op,
      decoded_io_op        => decoded_io_op
      );

  -- synchronous transitions

  process (clk, reset)
  begin
    if reset = '1' then

      pc <= (others => '0');

      stage_2_instruction <= NOP_INSTRUCTION;

      imm_reg <= (others => '0');

      stage_0_icache_portsel <= '0';
      stage_1_icache_portsel <= '0';
		
		stage_1_pc <= (others => '0');
		stage_2_pc <= (others => '0');

      -- on reset, flush pipeline and branch to 0x000000
      flush_pipeline <= '1';
      branch_target  <= (others => '0');

    elsif rising_edge(clk) then

      pc                  <= pc_next;
      stage_2_instruction <= stage_2_instruction_next;
      imm_reg             <= imm_reg_next;

      if (wr_reg16_a = '1') then
        reg16_bank(to_integer(reg16_write_idx_a)) <= reg16_write_data_a;
      end if;

      if (wr_reg16_b = '1') then
        reg16_bank(to_integer(reg16_write_idx_b)) <= reg16_write_data_b;
      end if;

      if (wr_reg32 = '1') then
        reg32_bank(to_integer(reg32_write_idx)) <= reg32_write_data;
      end if;

      stage_0_icache_portsel <= stage_0_icache_portsel_next;
      stage_1_icache_portsel <= stage_1_icache_portsel_next;
		
		stage_1_pc <= stage_1_pc_next;
		stage_2_pc <= stage_2_pc_next;

      stage_3_ipu_op <= stage_3_ipu_op_next;
      stage_3_fpu_op <= stage_3_fpu_op_next;
      stage_3_bs_op  <= stage_3_bs_op_next;
      stage_3_op     <= stage_3_op_next;
      stage_3_fc_op  <= stage_3_fc_op_next;
      stage_3_io_op  <= stage_3_io_op_next;

      stage_3_ipu_operand_x <= stage_3_ipu_operand_x_next;
      stage_3_ipu_operand_y <= stage_3_ipu_operand_y_next;
      stage_3_ipu_operand_z <= stage_3_ipu_operand_z_next;
      stage_3_fpu_operand_x <= stage_3_fpu_operand_x_next;
      stage_3_fpu_operand_y <= stage_3_fpu_operand_y_next;
      stage_3_reg16_dest_lo <= stage_3_reg16_dest_lo_next;
      stage_3_reg16_dest_hi <= stage_3_reg16_dest_hi_next;
      stage_3_jump_target   <= stage_3_jump_target_next;

      flush_pipeline <= flush_pipeline_next;
      branch_target  <= branch_target_next;

    end if;
  end process;

  -- instruction decoding

  -- this process isn't in the instruction decoded because register access is needed.
  process (decoded_x_sel, decoded_y_sel, decoded_z_sel,
           decoded_u_sel, decoded_v_sel, decoded_c_sel,
           stage_2_instruction, stage_2_pc)
    variable i             : instruction_t;
    variable idx           : std_logic_vector(3 downto 0);
    variable jump_target   : std_logic_vector(22 downto 0);
    variable jump_target_u : unsigned(22 downto 0);
  begin
    i := stage_2_instruction;

    case decoded_x_sel is
      when "01" =>
        decoded_operand_x <= reg16_bank(to_integer(unsigned(i(7 downto 4))));
      when "10" =>
        decoded_operand_x <= reg16_bank(to_integer(unsigned(i(6 downto 4) & '0')));
      when others =>
        decoded_operand_y <= (others => '0');
    end case;

    case decoded_y_sel is
      when "01" =>
        decoded_operand_y <= reg16_bank(to_integer(unsigned(i(3 downto 0) & '0')));
      when "10" =>
        decoded_operand_y <= imm_reg(11 downto 0) & i(3 downto 0);
      when others =>
        decoded_operand_y <= (others => '0');
    end case;

    case decoded_z_sel is
      when '1' =>
        decoded_operand_z <= reg16_bank(to_integer(unsigned(i(3 downto 0) & '1')));
      when others =>
    end case;

    case decoded_u_sel is
      when '1' =>
        idx                := "11" & i(3 downto 2);
        decoded_operand_fx <= reg32_bank(to_integer(unsigned(idx)));
      when others =>
    end case;

    case decoded_v_sel is
      when '1' =>
        idx                := "11" & i(1 downto 0);
        decoded_operand_fy <= reg32_bank(to_integer(unsigned(idx)));
      when others =>
    end case;

    case decoded_c_sel is
      when '1' =>
        if i(8) = '1' then
          jump_target         := "11111111111111" & i(8 downto 0);
          jump_target_u       := unsigned(jump_target);
          decoded_jump_target <= std_logic_vector(unsigned(jump_target_u) + stage_2_pc);
        else
          jump_target         := "00000000000000" & i(8 downto 0);
          jump_target_u       := unsigned(jump_target);
          decoded_jump_target <= std_logic_vector(jump_target_u + stage_2_pc);
        end if;
      when others =>
        decoded_jump_target <= imm_reg(13 downto 0) & i(8 downto 0);
    end case;

  end process;


  -- instruction execution



  -- memory access



  -- write back



  -- main state machine

  process (pc, flush_pipeline, stage_0_halt, stage_0_icache_portsel)
  begin

    -- pc next

    if flush_pipeline = '1' then
      pc_next <= branch_target;
    elsif stage_0_halt = '1' then
      pc_next <= pc;
    else
      pc_next <= pc + 1;
    end if;

    icache_address_a  <= (others => '0');
    icache_address_b  <= (others => '0');
    icache_rd_req_a   <= '0';
    icache_rd_req_b   <= '0';
    icache_data_sel_a <= '1';

    -- stage 0

    if stage_0_halt = '1' then
      stage_0_icache_portsel_next <= stage_0_icache_portsel;
      stage_1_pc_next             <= stage_1_pc;
    else
      stage_0_icache_portsel_next <= not stage_0_icache_portsel;
      stage_1_pc_next             <= pc;
    end if;

    if stage_0_icache_portsel = '0' then
      icache_address_a <= pc & '0';
      icache_rd_req_a  <= '1';
    else
      icache_address_b <= pc & '0';
      icache_rd_req_b  <= '1';
    end if;

    -- stage 1

    stage_1_stall <= '0';

    if stage_1_halt = '1' then
      stage_1_icache_portsel_next <= stage_1_icache_portsel;
    else
      stage_1_icache_portsel_next <= not stage_0_icache_portsel;
    end if;

    if flush_pipeline = '1' then
      stage_2_instruction_next <= NOP_INSTRUCTION;
      stage_2_pc_next          <= (others => '0');
    else

      if stage_1_icache_portsel = '0' then
        icache_address_a <= stage_1_pc & '0';
        icache_rd_req_a  <= '1';

        if icache_rd_ready_a = '1' then
          stage_2_instruction_next <= icache_rd_data_a;
          stage_2_pc_next          <= stage_1_pc;
        else
          stage_2_instruction_next <= NOP_INSTRUCTION;
          stage_2_pc_next          <= (others => '0');
          stage_1_stall             <= '1';
        end if;

      else
        icache_address_b <= stage_1_pc & '0';
        icache_rd_req_b  <= '1';

        if icache_rd_ready_b = '1' then
          stage_2_instruction_next <= icache_rd_data_b;
          stage_2_pc_next          <= stage_1_pc;
        else
          stage_2_instruction_next <= NOP_INSTRUCTION;
          stage_1_stall             <= '1';
          stage_2_pc_next          <= (others => '0');
        end if;

      end if;
    end if;

    -- stage 2

    if flush_pipeline = '1' or stage_2_stall = '1' then

      -- if stall or flush pipeline, insert a nop as decoded operation

      stage_3_ipu_op_next <= IPUOP_NOP;
      stage_3_fpu_op_next <= FPUOP_NOP;
      stage_3_bs_op_next  <= BSOP_NOP;
      stage_3_op_next     <= OP_NOP;
      stage_3_fc_op_next  <= FC_NOP;
      stage_3_io_op_next  <= IO_NOP;

      stage_3_ipu_operand_x_next <= (others => '0');
      stage_3_ipu_operand_y_next <= (others => '0');
      stage_3_ipu_operand_z_next <= (others => '0');
      stage_3_fpu_operand_x_next <= (others => '0');
      stage_3_fpu_operand_y_next <= (others => '0');
      stage_3_reg16_dest_lo_next <= (others => '0');
      stage_3_reg16_dest_hi_next <= (others => '0');
      stage_3_jump_target_next   <= (others => '0');

    elsif stage_2_halt = '1' then

      -- if halt pipeline (stages above stage 2 have stalled) keep same value

      stage_3_ipu_op_next <= stage_3_ipu_op;
      stage_3_fpu_op_next <= stage_3_fpu_op;
      stage_3_bs_op_next  <= stage_3_bs_op;
      stage_3_op_next     <= stage_3_op;
      stage_3_fc_op_next  <= stage_3_fc_op;
      stage_3_io_op_next  <= stage_3_io_op;

      stage_3_ipu_operand_x_next <= stage_3_ipu_operand_x;
      stage_3_ipu_operand_y_next <= stage_3_ipu_operand_y;
      stage_3_ipu_operand_z_next <= stage_3_ipu_operand_z;
      stage_3_fpu_operand_x_next <= stage_3_fpu_operand_x;
      stage_3_fpu_operand_y_next <= stage_3_fpu_operand_y;
      stage_3_reg16_dest_lo_next <= stage_3_reg16_dest_lo;
      stage_3_reg16_dest_hi_next <= stage_3_reg16_dest_hi;
      stage_3_jump_target_next   <= stage_3_jump_target;

    else

      -- no stall, halt, or flush. stage 3 takes on decoded values

      stage_3_ipu_op_next <= decoded_ipu_op;
      stage_3_fpu_op_next <= decoded_fpu_op;
      stage_3_bs_op_next  <= decoded_bs_op;
      stage_3_op_next     <= decoded_op;
      stage_3_fc_op_next  <= decoded_fc_op;
      stage_3_io_op_next  <= decoded_io_op;

      stage_3_ipu_operand_x_next <= decoded_operand_x;
      stage_3_ipu_operand_y_next <= decoded_operand_y;
      stage_3_ipu_operand_z_next <= decoded_operand_z;
      stage_3_fpu_operand_x_next <= decoded_operand_fx;
      stage_3_fpu_operand_y_next <= decoded_operand_fy;
      stage_3_reg16_dest_lo_next <= decoded_reg16_dest_lo;
      stage_3_reg16_dest_hi_next <= decoded_reg16_dest_hi;
      stage_3_jump_target_next   <= decoded_jump_target;

    end if;


  end process;

end RTL;
