# Nimbus - Portal Network- Message types
# Copyright (c) 2021 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# As per spec:
# https://github.com/ethereum/stateless-ethereum-specs/blob/master/state-network.md#wire-protocol

{.push raises: [Defect].}

import
  std/options,
  stint, stew/[results, objects],
  eth/ssz/ssz_serialization

export ssz_serialization, stint

const
  contentKeysLimit = 64

type
  ByteList* = List[byte, 2048]
  Bytes2* = array[2, byte]

  ContentKeysList* = List[ByteList, contentKeysLimit]
  ContentKeysBitList* = BitList[contentKeysLimit]

  MessageKind* = enum
    unused = 0x00

    ping = 0x01
    pong = 0x02
    findnode = 0x03
    nodes = 0x04
    findcontent = 0x05
    foundcontent = 0x06
    offer = 0x07
    accept = 0x08

  PingMessage* = object
    enrSeq*: uint64
    dataRadius*: UInt256

  PongMessage* = object
    enrSeq*: uint64
    dataRadius*: UInt256

  FindNodeMessage* = object
    distances*: List[uint16, 256]

  NodesMessage* = object
    total*: uint8
    enrs*: List[ByteList, 32] # ByteList here is the rlp encoded ENR. This could
    # also be limited to 300 bytes instead of 2048

  FindContentMessage* = object
    contentKey*: ByteList

  FoundContentMessage* = object
    enrs*: List[ByteList, 32]
    payload*: ByteList

  OfferMessage* = object
    contentKeys*: ContentKeysList

  AcceptMessage* = object
    connectionId*: Bytes2
    contentKeys*: ContentKeysBitList

  Message* = object
    case kind*: MessageKind
    of ping:
      ping*: PingMessage
    of pong:
      pong*: PongMessage
    of findnode:
      findNode*: FindNodeMessage
    of nodes:
      nodes*: NodesMessage
    of findcontent:
      findcontent*: FindContentMessage
    of foundcontent:
      foundcontent*: FoundContentMessage
    of offer:
      offer*: OfferMessage
    of accept:
      accept*: AcceptMessage
    else:
      discard

  SomeMessage* =
    PingMessage or PongMessage or
    FindNodeMessage or NodesMessage or
    FindContentMessage or FoundContentMessage or
    OfferMessage or AcceptMessage

template messageKind*(T: typedesc[SomeMessage]): MessageKind =
  when T is PingMessage: ping
  elif T is PongMessage: pong
  elif T is FindNodeMessage: findNode
  elif T is NodesMessage: nodes
  elif T is FindContentMessage: findcontent
  elif T is FoundContentMessage: foundcontent
  elif T is OfferMessage: offer
  elif T is AcceptMessage: accept

template toSszType*(x: UInt256): array[32, byte] =
  toBytesLE(x)

template toSszType*(x: auto): auto =
  x

func fromSszBytes*(T: type UInt256, data: openArray[byte]):
    T {.raises: [MalformedSszError, Defect].} =
  if data.len != sizeof(result):
    raiseIncorrectSize T

  T.fromBytesLE(data)

proc encodeMessage*[T: SomeMessage](m: T): seq[byte] =
  ord(messageKind(T)).byte & SSZ.encode(m)

proc decodeMessage*(body: openarray[byte]): Result[Message, cstring] =
  # Decodes to the specific `Message` type.
  if body.len < 1:
    return err("No message data, peer might not support this talk protocol")

  var kind: MessageKind
  if not checkedEnumAssign(kind, body[0]):
    return err("Invalid message type")

  var message = Message(kind: kind)

  try:
    case kind
    of unused: return err("Invalid message type")
    of ping:
      message.ping = SSZ.decode(body.toOpenArray(1, body.high), PingMessage)
    of pong:
      message.pong = SSZ.decode(body.toOpenArray(1, body.high), PongMessage)
    of findNode:
      message.findNode = SSZ.decode(body.toOpenArray(1, body.high), FindNodeMessage)
    of nodes:
      message.nodes = SSZ.decode(body.toOpenArray(1, body.high), NodesMessage)
    of findcontent:
      message.findcontent = SSZ.decode(body.toOpenArray(1, body.high), FindContentMessage)
    of foundcontent:
      message.foundcontent = SSZ.decode(body.toOpenArray(1, body.high), FoundContentMessage)
    of offer:
      message.offer = SSZ.decode(body.toOpenArray(1, body.high), OfferMessage)
    of accept:
      message.accept = SSZ.decode(body.toOpenArray(1, body.high), AcceptMessage)
  except SszError:
    return err("Invalid message encoding")

  ok(message)

template innerMessage[T: SomeMessage](message: Message, expected: MessageKind): Option[T] =
  if (message.kind == expected):
    some[T](message.expected)
  else:
    none[T]()

# All our Message variants correspond to enum MessageKind, therefore we are able to
# zoom in on inner structure of message by defining expected type T.
# If expected variant is not active, return None
proc getInnnerMessage*[T: SomeMessage](m: Message): Option[T] =
  innerMessage[T](m, messageKind(T))

# Simple conversion from Option to Result, looks like something which could live in
# Result library.
proc optToResult*[T, E](opt: Option[T], e: E): Result[T, E] =
  if (opt.isSome()):
    ok(opt.unsafeGet())
  else:
    err(e)

proc getInnerMessageResult*[T: SomeMessage](m: Message, errMessage: cstring): Result[T, cstring] =
  optToResult(getInnnerMessage[T](m), errMessage)
