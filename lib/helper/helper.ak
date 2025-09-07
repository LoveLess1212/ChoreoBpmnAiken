use aiken/builtin.{length_of_bytearray}
use aiken/collection/list
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{Value, merge, zero}
use cardano/transaction.{Datum, Input, Output, OutputReference}
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

pub fn input(oref: OutputReference, output: Output) -> Input {
  let input = Input { output_reference: oref, output }

  input
}

pub fn oref(id: ByteArray, index: Int) -> OutputReference {
  let oref = OutputReference { transaction_id: id, output_index: index }
  oref
}

pub fn output(addr: Address, value: Value, datum: Datum) -> Output {
  let output = Output { address: addr, value, datum, reference_script: None }

  output
}

pub fn scriptAddress(hash: ByteArray) -> Address {
  let address =
    Address { payment_credential: Script(hash), stake_credential: None }

  address
}

pub fn walletAddress(hash: ByteArray) -> Address {
  let address =
    Address {
      payment_credential: VerificationKey(hash),
      stake_credential: None,
    }

  address
}

pub fn makeAsset(
  policyId: ByteArray,
  assetName: ByteArray,
  quantity: Int,
) -> Value {
  let asset = assets.from_asset(policyId, assetName, quantity)

  asset
}
