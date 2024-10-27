use aiken/collection/list
// use aiken/crypto.{Blake2b_224, DataHash}
use cardano/address.{VerificationKey}
use cardano/assets
use cardano/transaction.{InlineDatum, OutputReference, Transaction, find_input}
use constant/typev2.{
  ActiveEscrow, BpmnEscrowDatum, Cancel, EscrowBpmnActions, Finalize, InitEscrow,
  NodeState, Start, Task,
}
use vodka_extra_signatories.{all_key_signed, key_signed, one_of_keys_signed}
use vodka_inputs.{inputs_at}
use vodka_outputs.{outputs_at}

// Steps of the BPMN process with A - Provider and B - Consumer (outdated-newest on obsidian)

validator escrow_bpmn {
  // is the input too big?
  spend(
    _datum: Option<BpmnEscrowDatum>,
    redeemer: EscrowBpmnActions,
    self: Transaction,
    utxo: OutputReference,
  ) {
    // the utxo that is being spent
    let Transaction { inputs, outputs, extra_signatories, .. } = self
    // get the transaction data and store it in inputs, outputs, extra_signatories
    expect Some(own_input) = find_input(inputs, utxo)
    // searches the transaction inputs to find the utxo that is being spent from the contract address
    let own_address = own_input.output.address
    // address of transaction wallet
    when redeemer is {
      Start(buyer) -> {
        //check if datum update buyer
        //check if buyer signed
        expect ([input], [output]) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect input_datum: BpmnEscrowDatum = raw_input_datum
        expect InitEscrow { seller, price, workflow, hashBpmn } = input_datum
        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEscrowDatum = raw_output_datum
        let expected_output_datum =
          ActiveEscrow { buyer, seller, price, workflow, hashBpmn }
        let is_buyer_signed = key_signed(extra_signatories, buyer)
        and {
          new_datum == expected_output_datum,
          is_buyer_signed,
        }
      }
      Task(new_task) -> {
        //check if datum update the bpmn steps correctly
        //check if both parties signed
        expect ([input], [output]) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        expect ActiveEscrow { buyer, seller, price, workflow, hashBpmn } =
          old_datum
        let NodeState { current, incoming: _incoming, outgoing } = workflow
        expect Some(outgoing1) = outgoing

        expect InlineDatum(raw_output_datum) = output.datum
        expect new_datum: BpmnEscrowDatum = raw_output_datum
        let expected_output_datum =
          ActiveEscrow { buyer, seller, price, workflow: new_task, hashBpmn }
        expect Some(new_task_incoming) = new_task.incoming
        let is_new_task_valid =
          list.has(outgoing1, new_task.current) && new_task_incoming == current
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        // trace @"extrasig": extra_signatories // done
        // trace @"prev outgoing": outgoing
        and {
          new_datum == expected_output_datum,
          is_new_task_valid,
          is_both_parties_signed,
        }
      }

      Cancel -> {
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        when old_datum is {
          InitEscrow { seller, .. } -> {
            // expect Some(pub_key) = address_pub_key(seller)
            let is_seller_signed = key_signed(extra_signatories, seller)
            is_seller_signed
          }
          ActiveEscrow { buyer, seller, price, .. } -> {
            let is_both_parties_signed =
              one_of_keys_signed(extra_signatories, [buyer, seller])
            expect Some(payment) =
              list.find(
                self.outputs,
                fn(output) {
                  output.address.payment_credential == VerificationKey(buyer)
                },
              )
            let is_buyer_refunded = assets.lovelace_of(payment.value) == price

            is_both_parties_signed && is_buyer_refunded
          }
        }
      }
      Finalize -> {
        expect ([input], []) =
          (inputs_at(inputs, own_address), outputs_at(outputs, own_address))
        expect InlineDatum(raw_input_datum) = input.output.datum
        expect old_datum: BpmnEscrowDatum = raw_input_datum
        expect ActiveEscrow { buyer, seller, price, .. } = old_datum
        // let NodeState { current, incoming, outgoing } = workflow
        // expect (_) = outgoing
        let is_both_parties_signed =
          all_key_signed(extra_signatories, [buyer, seller])
        expect Some(payment) =
          list.find(
            self.outputs,
            fn(output) {
              output.address.payment_credential == VerificationKey(seller)
            },
          )
        let is_seller_paid = assets.lovelace_of(payment.value) == price
        is_both_parties_signed && is_seller_paid
      }
    }
    // True
  }

  else(_) {
    fail
  }
}
