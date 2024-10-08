# Nimbus
# Copyright (c) 2022-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

import
  std/[tables, json],
  eth/common/blocks,
  eth/common/receipts,
  eth/rlp,
  results,
  stint,
  ../../nimbus/common/chain_config,
  ../common/types

export
  types

type
  T8NExitCode* = distinct int

  T8NError* = object of CatchableError
    exitCode*: T8NExitCode

  Ommer* = object
    delta*: uint64
    address*: Address

  EnvStruct* = object
    currentCoinbase*: Address
    currentDifficulty*: Opt[UInt256]
    currentRandom*: Opt[Bytes32]
    parentDifficulty*: Opt[UInt256]
    currentGasLimit*: GasInt
    currentNumber*: BlockNumber
    currentTimestamp*: EthTime
    parentTimestamp*: EthTime
    blockHashes*: Table[uint64, Hash32]
    ommers*: seq[Ommer]
    currentBaseFee*: Opt[UInt256]
    parentUncleHash*: Hash32
    parentBaseFee*: Opt[UInt256]
    parentGasUsed*: Opt[GasInt]
    parentGasLimit*: Opt[GasInt]
    withdrawals*: Opt[seq[Withdrawal]]
    currentBlobGasUsed*: Opt[uint64]
    currentExcessBlobGas*: Opt[uint64]
    parentBlobGasUsed*: Opt[uint64]
    parentExcessBlobGas*: Opt[uint64]
    parentBeaconBlockRoot*: Opt[Hash32]

  TxsType* = enum
    TxsNone
    TxsRlp
    TxsJson

  TxsList* = object
    case txsType*: TxsType
    of TxsRlp: r*: Rlp
    of TxsJson: n*: JsonNode
    else: discard

  TransContext* = object
    alloc*: GenesisAlloc
    txs*: TxsList
    env*: EnvStruct

  RejectedTx* = object
    index*: int
    error*: string

  TxReceipt* = object
    txType*: TxType
    root*: Hash32
    status*: bool
    cumulativeGasUsed*: GasInt
    logsBloom*: Bloom
    logs*: seq[Log]
    transactionHash*: Hash32
    contractAddress*: Address
    gasUsed*: GasInt
    blockHash*: Hash32
    transactionIndex*: int

  # ExecutionResult contains the execution status after running a state test, any
  # error that might have occurred and a dump of the final state if requested.
  ExecutionResult* = object
    stateRoot*: Hash32
    txRoot*: Hash32
    receiptsRoot*: Hash32
    logsHash*: Hash32
    logsBloom*: Bloom
    receipts*: seq[TxReceipt]
    rejected*: seq[RejectedTx]
    currentDifficulty*: Opt[UInt256]
    gasUsed*: GasInt
    currentBaseFee*: Opt[UInt256]
    withdrawalsRoot*: Opt[Hash32]
    blobGasUsed*: Opt[uint64]
    currentExcessBlobGas*: Opt[uint64]
    requestsRoot*: Opt[Hash32]
    depositRequests*: Opt[seq[DepositRequest]]
    withdrawalRequests*: Opt[seq[WithdrawalRequest]]
    consolidationRequests*: Opt[seq[ConsolidationRequest]]

const
  ErrorEVM*              = 2.T8NExitCode
  ErrorConfig*           = 3.T8NExitCode
  ErrorMissingBlockhash* = 4.T8NExitCode

  ErrorJson* = 10.T8NExitCode
  ErrorIO*   = 11.T8NExitCode
  ErrorRlp*  = 12.T8NExitCode

proc newError*(code: T8NExitCode, msg: string): ref T8NError =
  (ref T8NError)(exitCode: code, msg: msg)
