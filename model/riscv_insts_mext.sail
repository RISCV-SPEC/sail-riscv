/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* ****************************************************************** */
/* This file specifies the instructions in the 'M' extension.         */
/* ****************************************************************** */

function clause currentlyEnabled(Ext_M) = hartSupports(Ext_M) & misa[M] == 0b1
function clause currentlyEnabled(Ext_Zmmul) = hartSupports(Ext_Zmmul) | currentlyEnabled(Ext_M)

union clause instruction = MUL : (regidx, regidx, regidx, mul_op)

mapping encdec_mul_op : mul_op <-> bits(3) = {
  struct { high = false, signed_rs1 = true,  signed_rs2 = true  } <-> 0b000,
  struct { high = true,  signed_rs1 = true,  signed_rs2 = true  } <-> 0b001,
  struct { high = true,  signed_rs1 = true,  signed_rs2 = false } <-> 0b010,
  struct { high = true,  signed_rs1 = false, signed_rs2 = false } <-> 0b011,
}

mapping clause encdec = MUL(rs2, rs1, rd, mul_op)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_mul_op(mul_op) @ encdec_reg(rd) @ 0b0110011
  when currentlyEnabled(Ext_M) | currentlyEnabled(Ext_Zmmul)

function clause execute (MUL(rs2, rs1, rd, mul_op)) = {
  let rs1_bits = X(rs1);
  let rs2_bits = X(rs2);
  let rs1_int = if mul_op.signed_rs1 then signed(rs1_bits) else unsigned(rs1_bits);
  let rs2_int = if mul_op.signed_rs2 then signed(rs2_bits) else unsigned(rs2_bits);

  let result_wide = to_bits_truncate(2 * xlen, rs1_int * rs2_int);
  X(rd) = if   mul_op.high
          then result_wide[(2 * xlen - 1) .. xlen]
          else result_wide[(xlen - 1) .. 0];
  RETIRE_SUCCESS
}

mapping mul_mnemonic : mul_op <-> string = {
  struct { high = false, signed_rs1 = true,  signed_rs2 = true  } <-> "mul",
  struct { high = true,  signed_rs1 = true,  signed_rs2 = true  } <-> "mulh",
  struct { high = true,  signed_rs1 = true,  signed_rs2 = false } <-> "mulhsu",
  struct { high = true,  signed_rs1 = false, signed_rs2 = false } <-> "mulhu",
}

mapping clause assembly = MUL(rs2, rs1, rd, mul_op)
  <-> mul_mnemonic(mul_op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)

/* ****************************************************************** */
union clause instruction = DIV : (regidx, regidx, regidx, bool)

mapping clause encdec = DIV(rs2, rs1, rd, is_unsigned)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b10 @ bool_bits(is_unsigned) @ encdec_reg(rd) @ 0b0110011
  when currentlyEnabled(Ext_M)

function clause execute (DIV(rs2, rs1, rd, is_unsigned)) = {
  let rs1_bits = X(rs1);
  let rs2_bits = X(rs2);
  let rs1_int = if is_unsigned then unsigned(rs1_bits) else signed(rs1_bits);
  let rs2_int = if is_unsigned then unsigned(rs2_bits) else signed(rs2_bits);

  let quotient = if rs2_int == 0 then -1 else quot_round_zero(rs1_int, rs2_int);
  // Check for signed overflow.
  let quotient = if not(is_unsigned) & quotient >= 2 ^ (xlen - 1) then negate(2 ^ (xlen - 1)) else quotient;
  X(rd) = to_bits_truncate(quotient);
  RETIRE_SUCCESS
}

mapping clause assembly = DIV(rs2, rs1, rd, is_unsigned)
  <-> "div" ^ maybe_u(is_unsigned) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)

/* ****************************************************************** */
union clause instruction = REM : (regidx, regidx, regidx, bool)

mapping clause encdec = REM(rs2, rs1, rd, is_unsigned)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b11 @ bool_bits(is_unsigned) @ encdec_reg(rd) @ 0b0110011
  when currentlyEnabled(Ext_M)

function clause execute (REM(rs2, rs1, rd, is_unsigned)) = {
  let rs1_bits = X(rs1);
  let rs2_bits = X(rs2);
  let rs1_int = if is_unsigned then unsigned(rs1_bits) else signed(rs1_bits);
  let rs2_int = if is_unsigned then unsigned(rs2_bits) else signed(rs2_bits);

  let remainder = if rs2_int == 0 then rs1_int else rem_round_zero(rs1_int, rs2_int);
  // Signed overflow case returns zero naturally as required due to -1 divisor.
  X(rd) = to_bits_truncate(remainder);
  RETIRE_SUCCESS
}

mapping clause assembly = REM(rs2, rs1, rd, is_unsigned)
  <-> "rem" ^ maybe_u(is_unsigned) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)

/* ****************************************************************** */
union clause instruction = MULW : (regidx, regidx, regidx)

mapping clause encdec = MULW(rs2, rs1, rd)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0111011
  when xlen == 64 & (currentlyEnabled(Ext_M) | currentlyEnabled(Ext_Zmmul))

function clause execute (MULW(rs2, rs1, rd)) = {
  let rs1_bits = X(rs1)[31..0];
  let rs2_bits = X(rs2)[31..0];
  let rs1_int = signed(rs1_bits);
  let rs2_int = signed(rs2_bits);

  let result32 : bits(32) = to_bits_truncate(rs1_int * rs2_int);
  X(rd) = sign_extend(result32);
  RETIRE_SUCCESS
}

mapping clause assembly = MULW(rs2, rs1, rd)
  <-> "mulw" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)
  when xlen == 64

/* ****************************************************************** */
union clause instruction = DIVW : (regidx, regidx, regidx, bool)

mapping clause encdec = DIVW(rs2, rs1, rd, is_unsigned)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b10 @ bool_bits(is_unsigned) @ encdec_reg(rd) @ 0b0111011
  when xlen == 64 & currentlyEnabled(Ext_M)

function clause execute (DIVW(rs2, rs1, rd, is_unsigned)) = {
  let rs1_bits = X(rs1)[31..0];
  let rs2_bits = X(rs2)[31..0];
  let rs1_int = if is_unsigned then unsigned(rs1_bits) else signed(rs1_bits);
  let rs2_int = if is_unsigned then unsigned(rs2_bits) else signed(rs2_bits);

  let quotient = if rs2_int == 0 then -1 else quot_round_zero(rs1_int, rs2_int);
  // Check for signed overflow.
  let quotient = if not(is_unsigned) & quotient >= 2 ^ 31 then negate(2 ^ 31) else quotient;
  X(rd) = sign_extend(to_bits_truncate(32, quotient));
  RETIRE_SUCCESS
}

mapping clause assembly = DIVW(rs2, rs1, rd, is_unsigned)
  <-> "div" ^ maybe_u(is_unsigned) ^ "w" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)
  when xlen == 64

/* ****************************************************************** */
union clause instruction = REMW : (regidx, regidx, regidx, bool)

mapping clause encdec = REMW(rs2, rs1, rd, is_unsigned)
  <-> 0b0000001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b11 @ bool_bits(is_unsigned) @ encdec_reg(rd) @ 0b0111011
  when xlen == 64 & currentlyEnabled(Ext_M)

function clause execute (REMW(rs2, rs1, rd, is_unsigned)) = {
  let rs1_bits = X(rs1)[31..0];
  let rs2_bits = X(rs2)[31..0];
  let rs1_int = if is_unsigned then unsigned(rs1_bits) else signed(rs1_bits);
  let rs2_int = if is_unsigned then unsigned(rs2_bits) else signed(rs2_bits);

  let remainder = if rs2_int == 0 then rs1_int else rem_round_zero(rs1_int, rs2_int);
  // Signed overflow case returns zero naturally as required due to -1 divisor.
  X(rd) = sign_extend(to_bits_truncate(32, remainder));
  RETIRE_SUCCESS
}

mapping clause assembly = REMW(rs2, rs1, rd, is_unsigned)
  <-> "rem" ^ maybe_u(is_unsigned) ^ "w" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)
  when xlen == 64
