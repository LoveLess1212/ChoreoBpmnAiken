use aiken/crypto.{DataHash}

pub type BpmnEnactDatum {
  InitState {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    hashBpmn: DataHash,
    proceed: Int,
  }
  ActiveState {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    artifactCid: ByteArray,
    hashBpmn: DataHash,
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

// could be up to 32 * 3 ?
pub type EnactActions {
  Task
  Cancel
  Finalize
}
