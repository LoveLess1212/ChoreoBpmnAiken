use aiken/crypto.{DataHash}

pub type BpmnEscrowDatum {
  InitEscrow {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    hashBpmn: DataHash,
    proceed: Int,
    status: Status,
  }
  ActiveEscrow {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    artifactCid: ByteArray,
    hashBpmn: DataHash,
    status: Status,
    proceed: Int,
  }
}

pub type NodeState {
  current: DataHash,
  // 32 bytes
  incoming: Option<List<DataHash>>,
  // 32 bytes
  outgoing: Option<List<DataHash>>,
}

pub type Status {
  Start
  Ongoing
  Compensated
  UnCompensated
}

// could be up to 32 * 3 ?
pub type EscrowBpmnActions {
  Task
  Cancel
  Finalize
}
