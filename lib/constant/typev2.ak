use aiken/crypto.{DataHash}

/// Datum type for the BPMN enactment smart contract
pub type BpmnEnactDatum {
  /// Initial state of the contract start event
  InitState {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    hashBpmn: DataHash,
    proceed: Int,
  }
  /// Active state of the contract task events
  ActiveState {
    buyer: ByteArray,
    seller: ByteArray,
    workflow: NodeState,
    artifactCid: ByteArray,
    hashBpmn: DataHash,
    proceed: Int,
  }
}

/// Current state of a task in the BPMN workflow
pub type NodeState {
  /// hash of the current task
  current: DataHash,
  /// list of hashes of possible next tasks
  incoming: Option<List<DataHash>>,
  /// list of hashes of possible previous tasks
  outgoing: Option<List<DataHash>>,
}

/// Redeemer type for actions that can be performed on the BPMN enactment smart contract
pub type EnactActions {
  /// Move to the next task in the workflow
  Task
  /// Compensated the workflow -> uncompensated ending
  Compensated
  /// Uncompensated the workflow -> compensated ending
  Uncompensated
}
