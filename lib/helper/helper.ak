use aiken/builtin.{length_of_bytearray}
use aiken/collection/list
use cardano/address.{Address, VerificationKey}
use cardano/assets.{Value, merge, zero}
use cardano/transaction.{Output}
use constant/typev2.{NodeState}

pub fn get_all_value_to(outputs: List<Output>, address: ByteArray) -> Value {
  list.foldr(
    outputs,
    zero,
    fn(output, acc_value) {
      if output.address.payment_credential == VerificationKey(address) {
        merge(acc_value, output.value)
      } else {
        acc_value
      }
    },
  )
}

pub fn is_valid_ipfs_cid(cid: ByteArray) -> Bool {
  // Basic checks you might want:
  let length = length_of_bytearray(cid)
  and {
    length >= 32,
    // Minimum reasonable length
    length <= 64,
    // Maximum reasonable length
    cid != #"",
  }
  // Not empty
}

pub fn is_next_task_valid(old_task: NodeState, new_task: NodeState) -> Bool {
  let old_current = old_task.current
  expect Some(old_outgoing) = old_task.outgoing

  let new_current = new_task.current
  expect Some(new_incoming) = new_task.incoming

  // trace @"old_current": old_current
  // trace @"old_outgoing": old_outgoing
  // trace @"new_current": new_current
  // trace @"new_incoming": new_incoming
  // Extract from Option
  let is_valid = and {
      list.has(old_outgoing, new_current),
      list.has(new_incoming, old_current),
    }

  is_valid
}
