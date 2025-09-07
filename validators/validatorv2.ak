use aiken/collection/list
// use aiken/crypto.{Blake2b_224, DataHash}
use cardano/address.{VerificationKey}
use cardano/assets
use cardano/transaction.{InlineDatum, OutputReference, Transaction, find_input}
use constant/typev2.{
  ActiveEscrow, BpmnEscrowDatum, Cancel, Compensated, EscrowBpmnActions,
  Finalize, InitEscrow, NodeState, Ongoing, Start, Task, UnCompensated,
}
use helper/helper.{is_next_task_valid, is_valid_ipfs_cid}
use vodka_extra_signatories.{all_key_signed, key_signed, one_of_keys_signed}
use vodka_inputs.{inputs_at}
use vodka_outputs.{outputs_at}

// use vodka_value.{get_all_value_to, value_geq}

// Steps of the BPMN process with A - Provider and B - Consumer (outdated-newest on obsidian)

validator escrow_bpmn {
  // is the input too big?
  spend(
    _datum: Option<BpmnEscrowDatum>,
    redeemer: EscrowBpmnActions,
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
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        // Handle both InitEscrow and ActiveEscrow cases
        let (
          buyer,
          seller,
          old_workflow,
          hashBpmn,
          old_artifactCid,
          old_status,
          proceed,
        ) =
          when old_datum is {
            InitEscrow { buyer, seller, workflow, hashBpmn, proceed, status } ->
              // For InitEscrow, there's no artifactCid, so we use empty ByteArray or handle differently
              (buyer, seller, workflow, hashBpmn, "", status, proceed)
            ActiveEscrow {
              buyer,
              seller,
              workflow,
              hashBpmn,
              artifactCid,
              status,
              proceed,
            } ->
              (buyer, seller, workflow, hashBpmn, artifactCid, status, proceed)
          }
        let in_status_valid = or {
            old_status == Start,
            old_status == Ongoing,
          }
        // extract datum output
        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEscrowDatum = raw_output_datum
        expect ActiveEscrow {
          workflow: new_workflow,
          artifactCid: new_artifactCid,
          status: new_status,
          ..
        } = new_datum
        let expected_status = new_status == Ongoing

        // construct expected output datum
        let expected_output_datum =
          ActiveEscrow {
            buyer,
            seller,
            workflow: new_workflow,
            hashBpmn,
            artifactCid: new_artifactCid,
            status: new_status,
            proceed,
          }

        // validate 
        let is_status_valid = and {
            in_status_valid,
            expected_status,
          }
        let is_new_task_valid = is_next_task_valid(old_workflow, new_workflow)
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        // Only validate old_artifactCid if it's not empty (InitEscrow case)
        let is_old_artifact_valid =
          if old_artifactCid == "" {
            True
          } else {
            is_valid_ipfs_cid(old_artifactCid)
          }
        // trace @"is_new_task_valid": is_new_task_valid
        // trace @"is_status_valid": is_status_valid
        // trace @"is_both_parties_signed": is_both_parties_signed
        // trace @"new_datum": new_datum
        // trace @"expected_output_datum": expected_output_datum
        and {
          new_datum == expected_output_datum,
          is_new_task_valid,
          is_status_valid,
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
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        //trace @"is_seller_signed": extra_signatories
        when old_datum is {
          InitEscrow { seller, proceed, .. } -> {
            // expect Some(pub_key) = address_pub_key(seller)
            let is_seller_signed = key_signed(extra_signatories, seller)
            expect Some(payment) =
              list.find(
                self.outputs,
                fn(output) {
                  output.address.payment_credential == VerificationKey(seller)
                },
              )

            let is_seller_refunded =
              assets.lovelace_of(payment.value) == proceed
            is_seller_signed && is_seller_refunded
          }
          ActiveEscrow { buyer, seller, proceed, .. } -> {
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
        }
      }
      Finalize -> {
        expect ([input], [output]) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        expect ActiveEscrow {
          buyer,
          seller,
          workflow,
          proceed,
          status: old_status,
          ..
        } = old_datum
        let in_status_valid = old_status == Ongoing
        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEscrowDatum = raw_output_datum
        expect ActiveEscrow { status: new_status, .. } = new_datum
        let expected_status = or {
            new_status == Compensated,
            new_status == UnCompensated,
          }
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
        let is_status_valid = and {
            in_status_valid,
            expected_status,
          }
        trace @"is_both_parties_signed": is_both_parties_signed
        trace @"is_status_valid": is_status_valid
        trace @"is_proceed_paid": is_proceed_paid
        trace @"workflow.outgoing": workflow.outgoing
        and {
          is_both_parties_signed,
          is_status_valid,
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
