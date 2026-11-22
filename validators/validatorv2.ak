use aiken/collection/dict
use aiken/collection/list
// use aiken/crypto.{Blake2b_224, DataHash}
use cardano/assets.{PolicyId, policies}
use cardano/transaction.{InlineDatum, OutputReference, Transaction, find_input}
use constant/typev2.{
  BpmnEnactDatum, Compensated, EnactActions, InitRefund, NodeState, Start, Task,
  Uncompensated,
}
use constant/value.{proceed_fee}
use helper/helper.{
  any_input_from, any_payment_to, is_next_task_valid, is_valid_ipfs_cid,
  is_valid_proceed_transition,
}
use vodka_extra_signatories.{all_key_signed}
use vodka_inputs.{inputs_at}
use vodka_outputs.{outputs_at}

validator enact_bpmn {
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
        // TODO: check the policyId
        expect ([input], [output]) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))

        // extract datum input
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        let BpmnEnactDatum {
          buyer,
          seller,
          thirdParty,
          workflow: old_workflow,
          hashBpmn,
          artifactCid: old_artifactCid,
          proceed,
        } = old_datum
        // extract datum output
        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEnactDatum = raw_output_datum
        let BpmnEnactDatum {
          workflow: new_workflow,
          artifactCid: new_artifactCid,
          proceed: new_proceed,
          ..
        } = new_datum

        // construct expected output datum
        let expected_output_datum =
          BpmnEnactDatum {
            buyer,
            seller,
            thirdParty,
            workflow: new_workflow,
            hashBpmn,
            artifactCid: new_artifactCid,
            proceed,
          }

        // validate 
        let is_new_task_valid = is_next_task_valid(old_workflow, new_workflow)
        let is_proceed_valid =
          is_valid_proceed_transition(
            proceed,
            new_proceed,
            input.output.value,
            output.value,
          )
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        // Only validate old_artifactCid if it's not empty (InitState case)
        let is_old_artifact_valid =
          if old_artifactCid == None {
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
          is_proceed_valid,
          is_both_parties_signed,
          is_valid_ipfs_cid(new_artifactCid),
          is_old_artifact_valid,
        }
      }
      Compensated -> {
        // could compensated at any time, no output generated, but both parties must sign, and seller must be refunded
        // could be update the logic in the future to specify which parties should sign
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        let BpmnEnactDatum { buyer, seller, proceed, .. } = old_datum
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        expect Some(payment_to_seller) = any_payment_to(self.outputs, seller)

        let is_seller_refunded = and {
            proceed == proceed_fee,
            assets.lovelace_of(input.output.value) == proceed_fee,
            assets.lovelace_of(payment_to_seller.value) == proceed_fee,
          }

        is_both_parties_signed && is_seller_refunded
      }
      Uncompensated -> {
        // there should be no output at the contract address
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        let BpmnEnactDatum { buyer, seller, workflow, proceed, .. } = old_datum
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        expect Some(payment) = any_payment_to(self.outputs, seller)

        let is_proceed_paid = and {
            proceed == proceed_fee,
            assets.lovelace_of(input.output.value) == proceed_fee,
            assets.lovelace_of(payment.value) == proceed_fee,
          }
        and {
          is_both_parties_signed,
          is_proceed_paid,
          workflow.outgoing == None,
        }
      }
      InitRefund -> {
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEnactDatum = raw_input_datum
        let BpmnEnactDatum { buyer, seller, workflow, proceed, .. } = old_datum
        // Find the original funding input in this transaction
        // this is only the claimer,
        expect Some(funding_input) =
          list.find(inputs, fn(input) { input.output.address != own_address })
        // Get the funder's address from the input
        let funder_credential = funding_input.output.address.payment_credential
        // Ensure refund goes back to the original funder's address
        expect Some(payment) =
          list.find(
            outputs,
            fn(output) {
              output.address.payment_credential == funder_credential
            },
          )
        let is_proceed_refunded =
          assets.lovelace_of(payment.value) == assets.lovelace_of(
            input.output.value,
          )
        // No need to check signatures since the funder must sign to spend their UTxO
        is_proceed_refunded
      }

      _ -> False
    }
  }

  mint(redeemer: EnactActions, policy_id: PolicyId, self: Transaction) {
    // the utxo that is being spent
    when redeemer is {
      Start -> {
        let Transaction { inputs, outputs, mint, extra_signatories, .. } = self
        expect [Pair(_asset_name, quantity)] =
          mint |> assets.tokens(policy_id) |> dict.to_pairs()
        expect Some(state_output) =
          list.find(
            outputs,
            fn(output) { list.has(policies(output.value), policy_id) },
          )

        expect InlineDatum(raw_datum) = state_output.datum
        expect datum: BpmnEnactDatum = raw_datum
        let BpmnEnactDatum { buyer, seller, proceed, .. } = datum

        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        let is_proceed_valid = and {
            proceed == proceed_fee,
            assets.lovelace_of(state_output.value) == proceed_fee,
          }
        let is_inital_state = and {
            datum.workflow.incoming == None,
            datum.workflow.outgoing != None,
          }
        and {
          is_both_parties_signed,
          is_proceed_valid,
          is_inital_state,
          // only mint 1 token for the state output
          quantity == 1,
          // the seller should be the one who fund
          any_input_from(inputs, seller),
        }
      }

      _ -> False
    }
  }

  else(_) {
    fail
  }
}
