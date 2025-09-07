use aiken/collection/list
// use aiken/crypto.{Blake2b_224, DataHash}
use cardano/address.{VerificationKey}
use cardano/assets
use cardano/transaction.{InlineDatum, OutputReference, Transaction, find_input}
use constant/typev2.{
  ActiveState, BpmnEnactDatum, Cancel, EnactActions, Finalize, InitState,
  NodeState, Task,
}
use helper/helper.{is_next_task_valid, is_valid_ipfs_cid}
use vodka_extra_signatories.{all_key_signed, one_of_keys_signed}
use vodka_inputs.{inputs_at}
use vodka_outputs.{outputs_at}

validator enact_bpmn {
  // is the input too big?
  spend(
    _datum: Option<BpmnEnactDatum>,
    redeemer: EnactActions,
    utxo: OutputReference,
    self: Transaction,
  ) {
    // the utxo that is being spent
    let Transaction { inputs, outputs, extra_signatories, .. } = self
    // get the transaction data and store it in inputs, outputs, extra_signatories
    expect Some(own_input) = find_input(inputs, utxo)
    // searches the transaction inputs to find the utxo that is being spent from the contract address
    let own_address = own_input.output.address
    // address of transaction wallet
    when redeemer is {
      Task -> {
        // extract input and output at smart contract address
        expect ([input], [output]) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))

        // extract datum input
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        // Handle both InitState and ActiveStatecases
        let (buyer, seller, old_workflow, hashBpmn, old_artifactCid, proceed) =
          when old_datum is {
            InitState { buyer, seller, workflow, hashBpmn, proceed } ->
              // For InitState, there's no artifactCid, so we use empty ByteArray or handle differently
              (buyer, seller, workflow, hashBpmn, "", proceed)
            ActiveState {
              buyer,
              seller,
              workflow,
              hashBpmn,
              artifactCid,
              proceed,
            } -> (buyer, seller, workflow, hashBpmn, artifactCid, proceed)
          }
        // extract datum output
        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEnactDatum = raw_output_datum
        expect ActiveState {
          workflow: new_workflow,
          artifactCid: new_artifactCid,
          ..
        } = new_datum

        // construct expected output datum
        let expected_output_datum =
          ActiveState {
            buyer,
            seller,
            workflow: new_workflow,
            hashBpmn,
            artifactCid: new_artifactCid,
            proceed,
          }

        // validate 
        let is_new_task_valid = is_next_task_valid(old_workflow, new_workflow)
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        // Only validate old_artifactCid if it's not empty (InitState case)
        let is_old_artifact_valid =
          if old_artifactCid == "" {
            True
          } else {
            is_valid_ipfs_cid(old_artifactCid)
          }
        // trace @"is_new_task_valid": is_new_task_valid
        // trace @"is_both_parties_signed": is_both_parties_signed
        // trace @"new_datum": new_datum
        // trace @"expected_output_datum": expected_output_datum
        and {
          new_datum == expected_output_datum,
          is_new_task_valid,
          is_both_parties_signed,
          is_valid_ipfs_cid(new_artifactCid),
          is_old_artifact_valid,
        }
      }

      Cancel -> {
        //trace @"Cancel"
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        //trace @"is_seller_signed": extra_signatories
        let (buyer, seller, proceed) =
          when old_datum is {
            InitState { buyer, seller, proceed, .. } -> (buyer, seller, proceed)
            ActiveState { buyer, seller, proceed, .. } ->
              (buyer, seller, proceed)
          }
        let is_any_parties_signed =
          one_of_keys_signed(extra_signatories, [buyer, seller])
        expect Some(payment_to_seller) =
          list.find(
            self.outputs,
            fn(output) {
              output.address.payment_credential == VerificationKey(seller)
            },
          )
        let is_seller_refunded =
          assets.lovelace_of(payment_to_seller.value) == proceed

        is_any_parties_signed && is_seller_refunded
      }
      Finalize -> {
        // there should be no output at the contract address
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        expect ActiveState { buyer, seller, workflow, proceed, .. } = old_datum
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        expect Some(payment) =
          // payment to seller
          list.find(
            self.outputs,
            fn(output) {
              output.address.payment_credential == VerificationKey(seller)
            },
          )
        let is_proceed_paid = assets.lovelace_of(payment.value) == proceed
        and {
          is_both_parties_signed,
          is_proceed_paid,
          workflow.outgoing == None,
        }
      }
    }
    // True
  }

  else(_) {
    fail
  }
}
