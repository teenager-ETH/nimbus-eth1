# TODO : hex
const
  STOP*          = 0.byte
  ADD*           = 1.byte
  MUL*           = 2.byte
  SUB*           = 3.byte
  DIV*           = 4.byte
  SDIV*          = 5.byte
  MOD*           = 6.byte
  SMOD*          = 7.byte
  ADDMOD*        = 8.byte
  MULMOD*        = 9.byte
  EXP*           = 10.byte
  SIGNEXTEND*    = 11.byte

  LT*            = 16.byte
  GT*            = 17.byte
  SLT*           = 18.byte
  SGT*           = 19.byte
  EQ*            = 20.byte
  ISZERO*        = 21.byte
  AND*           = 22.byte
  OR*            = 23.byte
  XOR*           = 24.byte
  NOT*           = 25.byte
  BYTE*          = 26.byte

  SHA3*          = 32.byte
  
  ADDRESS*       = 48.byte
  BALANCE*       = 49.byte
  ORIGIN*        = 50.byte

  CALLER*        = 51.byte
  CALLVALUE*     = 52.byte
  CALLDATALOAD*  = 53.byte
  CALLDATASIZE*  = 54.byte
  CALLDATACOPY*  = 55.byte

  CODESIZE*      = 56.byte
  CODECOPY*      = 57.byte

  GASPRICE*      = 58.byte

  EXTCODESIZE*   = 59.byte
  EXTCODECOPY*   = 60.byte

  RETURNDATASIZE* = 61.byte
  RETURNDATACOPY* = 62.byte

  BLOCKHASH*     = 64.byte

  COINBASE*      = 65.byte

  TIMESTAMP*     = 66.byte

  NUMBER*        = 67.byte

  DIFFICULTY*    = 68.byte

  GASLIMIT*      = 69.byte
  
  POP*           = 80.byte

  MLOAD*         = 81.byte
  MSTORE*        = 82.byte
  MSTORE8        = 83.byte

  SLOAD*         = 84.byte
  SSTORE*        = 85.byte

  JUMP*          = 86.byte
  JUMPI*         = 87.byte

  PC*            = 88.byte

  MSIZE*         = 89.byte

  GAS*           = 90.byte

  JUMPDEST*      = 91.byte
  
  PUSH1*         = 96.byte
  PUSH2*         = 97.byte
  PUSH3*         = 98.byte
  PUSH4*         = 99.byte
  PUSH5*         = 100.byte
  PUSH6*         = 101.byte
  PUSH7*         = 102.byte
  PUSH8*         = 103.byte
  PUSH9*         = 104.byte
  PUSH10*        = 105.byte
  PUSH11*        = 106.byte
  PUSH12*        = 107.byte
  PUSH13*        = 108.byte
  PUSH14*        = 109.byte
  PUSH15*        = 110.byte
  PUSH16*        = 111.byte
  PUSH17*        = 112.byte
  PUSH18*        = 113.byte
  PUSH19*        = 114.byte
  PUSH20*        = 115.byte
  PUSH21*        = 116.byte
  PUSH22*        = 117.byte
  PUSH23*        = 118.byte
  PUSH24*        = 119.byte
  PUSH25*        = 120.byte
  PUSH26*        = 121.byte
  PUSH27*        = 122.byte
  PUSH28*        = 123.byte
  PUSH29*        = 124.byte
  PUSH30*        = 125.byte
  PUSH31*        = 126.byte
  PUSH32*        = 127.byte
  DUP1*          = 128.byte
  DUP2*          = 129.byte
  DUP3*          = 130.byte
  DUP4*          = 131.byte
  DUP5*          = 132.byte
  DUP6*          = 133.byte
  DUP7*          = 134.byte
  DUP8*          = 135.byte
  DUP9*          = 136.byte
  DUP10*         = 137.byte
  DUP11*         = 138.byte
  DUP12*         = 139.byte
  DUP13*         = 140.byte
  DUP14*         = 141.byte
  DUP15*         = 142.byte
  DUP16*         = 143.byte
  SWAP1*         = 144.byte
  SWAP2*         = 145.byte
  SWAP3*         = 146.byte
  SWAP4*         = 147.byte
  SWAP5*         = 148.byte
  SWAP6*         = 149.byte
  SWAP7*         = 150.byte
  SWAP8*         = 151.byte
  SWAP9*         = 152.byte
  SWAP10*        = 153.byte
  SWAP11*        = 154.byte
  SWAP12*        = 155.byte
  SWAP13*        = 156.byte
  SWAP14*        = 157.byte
  SWAP15*        = 158.byte
  SWAP16*        = 159.byte
  LOG0*          = 160.byte
  LOG1*          = 161.byte
  LOG2*          = 162.byte
  LOG3*          = 163.byte
  LOG4*          = 164.byte
  CREATE*        = 240.byte
  CALL*          = 241.byte
  CALLCODE*      = 242.byte
  RETURN*        = 243.byte
  DELEGATECALL*  = 244.byte
  STATICCALL*    = 250.byte
  REVERT*        = 253.byte
  SELFDESTRUCT*  = 255.byte
