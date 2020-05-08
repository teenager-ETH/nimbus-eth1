import
  stew/[byteutils, endians2],
  nimcrypto/[keccak, hash], eth/[common, rlp],
  eth/trie/[trie_defs, nibbles, db],
  faststreams/output_stream,
  ./witness_types, ../nimbus/constants,
  ../nimbus/db/storage_types, ./multi_keys

type
  DB = TrieDatabaseRef

  WitnessBuilder* = object
    db*: DB
    root: KeccakHash
    output: OutputStream
    flags: WitnessFlags

  StackElem = object
    node: seq[byte]
    parentGroup: Group
    keys: MultikeysRef
    depth: int
    storageMode: bool

proc initWitnessBuilder*(db: DB, rootHash: KeccakHash, flags: WitnessFlags = {}): WitnessBuilder =
  result.db = db
  result.root = rootHash
  result.output = memoryOutput().s
  result.flags = flags

template extensionNodeKey(r: Rlp): auto =
  hexPrefixDecode r.listElem(0).toBytes

proc expectHash(r: Rlp): seq[byte] =
  result = r.toBytes
  if result.len != 32:
    raise newException(RlpTypeMismatch,
      "RLP expected to be a Keccak hash value, but has an incorrect length")

template getNode(elem: untyped): untyped =
  if elem.isList: @(elem.rawData)
  else: @(get(wb.db, elem.expectHash))

proc rlpListToBitmask(r: var Rlp): uint =
  # only bit 1st to 16th are valid
  # the 1st bit is the rightmost bit
  var i = 0
  for branch in r:
    if not branch.isEmpty:
      result.setBranchMaskBit(i)
    inc i
  r.position = 0

template write(wb: var WitnessBuilder, x: untyped) =
  wb.output.append(x)

proc writeU32Impl(wb: var WitnessBuilder, x: uint32) =
  wb.write(toBytesBE(x))

template writeU32(wb: var WitnessBuilder, x: untyped) =
  wb.writeU32Impl(uint32(x))

template writeByte(wb: var WitnessBuilder, x: untyped) =
  wb.write(byte(x))

proc writeNibbles(wb: var WitnessBuilder; n: NibblesSeq, withLen: bool = true) =
  # convert the NibblesSeq into left aligned byte seq
  # perhaps we can optimize it if the NibblesSeq already left aligned
  let nibblesLen = n.len
  let numBytes = nibblesLen div 2 + nibblesLen mod 2
  var bytes: array[32, byte]
  doAssert(nibblesLen >= 1 and nibblesLen <= 64)
  for pos in 0..<n.len:
    if (pos and 1) != 0:
      bytes[pos div 2] = bytes[pos div 2] or n[pos]
    else:
      bytes[pos div 2] = bytes[pos div 2] or (n[pos] shl 4)

  if withLen:
    # write nibblesLen
    wb.writeByte(nibblesLen)
  # write nibbles
  wb.write(bytes.toOpenArray(0, numBytes-1))

proc writeExtensionNode(wb: var WitnessBuilder, n: NibblesSeq, depth: int, node: openArray[byte]) =
  # write type
  wb.writeByte(ExtensionNodeType)
  # write nibbles
  wb.writeNibbles(n)

  when defined(debugDepth):
    wb.writeByte(depth)

  when defined(debugHash):
    wb.write(keccak(node).data)

proc writeBranchNode(wb: var WitnessBuilder, mask: uint, depth: int, node: openArray[byte]) =
  # write type
  # branch node 17th elem should always empty
  doAssert mask.branchMaskBitIsSet(16) == false
  wb.writeByte(BranchNodeType)
  # write branch mask
  # countOnes(branch mask) >= 2 and <= 16
  wb.writeByte((mask shr 8) and 0xFF)
  wb.writeByte(mask and 0xFF)

  when defined(debugDepth):
    wb.writeByte(depth)

  when defined(debugHash):
    wb.write(keccak(node).data)

proc writeHashNode(wb: var WitnessBuilder, node: openArray[byte]) =
  # usually a hash node means the recursion will not go deeper
  # and the information can be represented by the hash
  # for chunked witness, a hash node can be a root to another
  # sub-trie in one of the chunks
  wb.writeByte(HashNodeType)
  wb.write(node)

proc getBranchRecurse(wb: var WitnessBuilder, z: var StackElem) {.raises: [ContractCodeError, IOError, Defect, CatchableError, Exception].}

proc writeAccountNode(wb: var WitnessBuilder, kd: KeyData, acc: Account, nibbles: NibblesSeq,
  node: openArray[byte], depth: int) {.raises: [ContractCodeError, IOError, Defect, CatchableError, Exception].} =

  # write type
  wb.writeByte(AccountNodeType)

  when defined(debugHash):
    wb.writeU32(node.len)
    wb.write(node)

  when defined(debugDepth):
    wb.writeByte(depth)

  doAssert(nibbles.len == 64 - depth)
  var accountType = if acc.codeHash == blankStringHash and acc.storageRoot == emptyRlpHash: SimpleAccountType
                    else: ExtendedAccountType

  if not kd.codeTouched:
    accountType = CodeUntouched

  wb.writeByte(accountType)
  wb.writeNibbles(nibbles, false)
  wb.write(kd.address)
  wb.write(acc.balance.toBytesBE)
  wb.write(acc.nonce.u256.toBytesBE)

  if accountType != SimpleAccountType:
    if not kd.codeTouched:
      # the account have code but not touched by the EVM
      # in current block execution
      wb.writeHashNode(acc.codeHash.data)
      let code = get(wb.db, contractHashKey(acc.codeHash).toOpenArray)
      if wfEIP170 in wb.flags and code.len > EIP170_CODE_SIZE_LIMIT:
        raise newException(ContractCodeError, "code len exceed EIP170 code size limit")
      wb.writeU32(code.len)
      # no code here
    elif acc.codeHash != blankStringHash:
      # the account have code and the EVM use it
      let code = get(wb.db, contractHashKey(acc.codeHash).toOpenArray)
      if wfEIP170 in wb.flags and code.len > EIP170_CODE_SIZE_LIMIT:
        raise newException(ContractCodeError, "code len exceed EIP170 code size limit")
      wb.writeU32(code.len)
      wb.write(code)
    else:
      # no code
      wb.writeU32(0'u32)

    if kd.storageKeys.isNil:
      # the account have storage but not touched by EVM
      wb.writeHashNode(acc.storageRoot.data)
    elif acc.storageRoot != emptyRlpHash:
      # the account have storage and the EVM use it
      var zz = StackElem(
        node: wb.db.get(acc.storageRoot.data),
        parentGroup: kd.storageKeys.initGroup(),
        keys: kd.storageKeys,
        depth: 0,          # set depth to zero
        storageMode: true  # switch to storage mode
      )
      getBranchRecurse(wb, zz)
    else:
      # no storage at all
      wb.writeHashNode(emptyRlpHash.data)

  # rule 0x01 and 0x02 can be optimized again to save some bytes
  # nibbles can be removed to save space, it can be constructed by the parser
  # using depth dan hash of address with `nibblesLen = 64-depth` (right side bytes)

  #0x00 pathnibbles:<Nibbles(64-d)> address:<Address> balance:<Bytes32> nonce:<Bytes32>
  #0x01 pathnibbles:<Nibbles(64-d)> address:<Address> balance:<Bytes32> nonce:<Bytes32> bytecode:<Bytecode> storage:<Tree_Node(0,1)>
  #0x02 pathnibbles:<Nibbles(64-d)> address:<Address> balance:<Bytes32> nonce:<Bytes32> codehash:<Bytes32> codesize:<U32> storage:<Account_Storage_Tree_Node(0)>

proc writeAccountStorageLeafNode(wb: var WitnessBuilder, key: openArray[byte], val: UInt256, nibbles: NibblesSeq, node: openArray[byte], depth: int) =
  wb.writeByte(StorageLeafNodeType)

  when defined(debugHash):
    wb.writeU32(node.len)
    wb.write(node)

  when defined(debugDepth):
    wb.writeByte(depth)

  doAssert(nibbles.len == 64 - depth)
  # nibbles can be removed to save space, it can be constructed by the parser
  # using depth dan hash of key with `nibblesLen = 64-depth` (right side bytes)
  wb.writeNibbles(nibbles, false)

  wb.write(key)
  wb.write(val.toBytesBE)

  #<Storage_Leaf_Node(d<65)> := pathnibbles:<Nibbles(64-d))> key:<Bytes32> val:<Bytes32>

proc getBranchRecurse(wb: var WitnessBuilder, z: var StackElem) =
  if z.node.len == 0: return
  var nodeRlp = rlpFromBytes z.node

  case nodeRlp.listLen
  of 2:
    let (isLeaf, k) = nodeRlp.extensionNodeKey
    let mg = groups(z.keys, z.depth, k, z.parentGroup)

    if not mg.match:
      # return immediately if there is no match
      writeHashNode(wb, keccak(z.node).data)
      return

    let value = nodeRlp.listElem(1)
    if not isLeaf:
      # recursion will go deeper depend on the common-prefix length nibbles
      writeExtensionNode(wb, k, z.depth, z.node)
      var zz = StackElem(
        node: value.getNode,
        parentGroup: mg.group,
        keys: z.keys,
        depth: z.depth + k.len, # increase the depth by k.len
        storageMode: z.storageMode
      )
      getBranchRecurse(wb, zz)
      return

    # there should be only one match
    let kd = z.keys.visitMatch(mg, z.depth, k)
    if z.storageMode:
      doAssert(kd.storageMode)
      writeAccountStorageLeafNode(wb, kd.storageSlot, value.toBytes.decode(UInt256), k, z.node, z.depth)
    else:
      doAssert(not kd.storageMode)
      writeAccountNode(wb, kd, value.toBytes.decode(Account), k, z.node, z.depth)

  of 17:
    let branchMask = rlpListToBitmask(nodeRlp)
    writeBranchNode(wb, branchMask, z.depth, z.node)

    # if there is a match in any branch elem
    # 1st to 16th, the recursion will go deeper
    # by one nibble
    doAssert(z.depth != 64) # notLeaf or path.len == 0

    let path = groups(z.keys, z.parentGroup, z.depth)
    for i in nonEmpty(branchMask):
      let branch = nodeRlp.listElem(i)
      if branchMaskBitIsSet(path.mask, i):
        # it is a match between multikeys and Branch Node elem
        var zz = StackElem(
          node: branch.getNode,
          parentGroup: path.groups[i],
          keys: z.keys,
          depth: z.depth + 1, # increase the depth by one
          storageMode: z.storageMode
        )
        getBranchRecurse(wb, zz)
        continue

      if branch.isList:
        # short node appear in yellow paper
        # but never in the actual ethereum state trie
        # an rlp encoded ethereum account will have length > 32 bytes
        # block witness spec silent about this
        doAssert(false, "Short node should not exist in block witness")
      else:
        # if branch elem not empty and not a match, emit hash
        writeHashNode(wb, branch.expectHash)

    # 17th elem should always empty
    # 17th elem appear in yellow paper but never in
    # the actual ethereum state trie
    # the 17th elem also not included in block witness spec
    doAssert branchMask.branchMaskBitIsSet(16) == false
  else:
    raise newException(CorruptedTrieDatabase,
                       "HexaryTrie node with an unexpected number of children")

proc buildWitness*(wb: var WitnessBuilder, keys: MultikeysRef): seq[byte]
  {.raises: [ContractCodeError, IOError, Defect, CatchableError, Exception].} =

  # witness version
  wb.writeByte(BlockWitnessVersion)

  # one or more trees

  # we only output one big tree here
  # the condition to split the big tree into chunks of sub-tries
  # is not clear in the spec
  wb.writeByte(MetadataNothing)

  var z = StackElem(
    node: @(wb.db.get(wb.root.data)),
    parentGroup: keys.initGroup(),
    keys: keys,
    depth: 0,          # always start with a zero depth
    storageMode: false # build account witness first
  )
  getBranchRecurse(wb, z)

  # result
  result = wb.output.getOutput(seq[byte])