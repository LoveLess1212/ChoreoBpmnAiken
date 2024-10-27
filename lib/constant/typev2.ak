use aiken/crypto.{DataHash}

pub type BpmnEscrowDatum {
  InitEscrow {
    seller: ByteArray,
    price: Int,
    workflow: NodeState,
    hashBpmn: DataHash,
  }
  ActiveEscrow {
    buyer: ByteArray,
    seller: ByteArray,
    price: Int,
    workflow: NodeState,
    hashBpmn: DataHash,
  }
}

pub type NodeState {
  current: DataHash,
  // 32 bytes
  incoming: Option<DataHash>,
  // 32 bytes
  outgoing: Option<List<DataHash>>,
}

// could be up to 32 * 3 ?
pub type EscrowBpmnActions {
  Start { buyer: ByteArray }
  Task { new_task: NodeState }
  Cancel
  Finalize
}
