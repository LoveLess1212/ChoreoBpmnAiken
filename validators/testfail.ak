use cardano/assets.{from_lovelace}
use constant/typev2.{
  ActiveState, BpmnEnactDatum, Compensated, Task, Uncompensated,
}
use helper/test_helper.{
  generate_artifact_cid, get_datumOutRun1, get_datumOutRun2, get_datumout_Start,
  get_nth_workflow, get_seller_address,
}
// use helper/helper as t
use mocktail.{
  complete, mocktail_tx, required_signer_hash, tx_in, tx_in_inline_datum, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_address.{mock_script_address}
use mocktail/virgin_key_hash.{mock_key_hash}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}
use validatorv2

// FAILURE TEST CASES - These tests are expected to fail

test enact_bpmn_task_missing_buyer_signature() fail {
  // This should fail because buyer signature is missing
  let seller = #"beef"
  let datumIn = get_datumout_Start()
  let datumOut = get_datumOutRun1()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(9000000))
      |> tx_out_inline_datum(True, datumOut)
      // Missing buyer signature - only seller signs
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_task_missing_seller_signature() fail {
  // This should fail because seller signature is missing
  let buyer = #"face"
  let datumIn = get_datumout_Start()
  let datumOut = get_datumOutRun1()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(9000000))
      |> tx_out_inline_datum(True, datumOut)
      // Missing seller signature - only buyer signs
      |> required_signer_hash(True, buyer)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_task_missing_both_signatures() fail {
  // This should fail because both buyer and seller signatures are missing
  let datumIn = get_datumout_Start()
  let datumOut = get_datumOutRun1()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(9000000))
      |> tx_out_inline_datum(True, datumOut)
      // No signatures at all
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_task_invalid_workflow_transition() fail {
  // This should fail because of invalid workflow transition (skipping steps)
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumout_Start()
  // workflow at step 1
  // Skip to step 3 instead of step 2 - invalid transition
  let invalid_datumOut = get_datumOutRun2()
  // workflow at step 3
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(9000000))
      |> tx_out_inline_datum(True, invalid_datumOut)
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

// Helper function to create datum with invalid IPFS CID
fn get_datum_with_invalid_cid() -> BpmnEnactDatum {
  ActiveState {
    buyer: #"face",
    seller: #"beef",
    workflow: get_nth_workflow(2, False),
    artifactCid: #"",
    // Invalid empty CID
    hashBpmn: mock_key_hash(0),
    proceed: 2000000,
  }
}

test enact_bpmn_task_invalid_artifact_cid() fail {
  // This should fail because of invalid/empty artifact CID
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumOutRun1()
  let invalid_datumOut = get_datum_with_invalid_cid()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(11000000))
      |> tx_out_inline_datum(True, invalid_datumOut)
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

// Helper function to create datum with modified buyer/seller
fn get_datum_with_wrong_buyer() -> BpmnEnactDatum {
  ActiveState {
    buyer: #"dead",
    // Wrong buyer
    seller: #"beef",
    workflow: get_nth_workflow(2, False),
    artifactCid: generate_artifact_cid(1),
    hashBpmn: mock_key_hash(0),
    proceed: 2000000,
  }
}

test enact_bpmn_task_datum_modification() fail {
  // This should fail because output datum has different buyer than input
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumOutRun1()
  let modified_datumOut = get_datum_with_wrong_buyer()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(0),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, mock_script_address(1, None), from_lovelace(11000000))
      |> tx_out_inline_datum(True, modified_datumOut)
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_finalize_missing_buyer_signature() fail {
  // This should fail because buyer signature is missing for finalize
  let seller = #"beef"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      // Missing buyer signature - only seller signs
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Uncompensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_finalize_missing_seller_signature() fail {
  // This should fail because seller signature is missing for finalize
  let buyer = #"face"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      // Missing seller signature - only buyer signs
      |> required_signer_hash(True, buyer)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Uncompensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_finalize_workflow_not_complete() fail {
  // This should fail because workflow is not at the end (outgoing is not None)
  let seller = #"beef"
  let buyer = #"face"
  // Use a datum that's not at the end of workflow
  let datumIn = get_datumOutRun1()
  // This has outgoing transitions
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Uncompensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_cancel_no_signatures() fail {
  // This should fail because neither buyer nor seller signed the cancel transaction
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      // No signatures at all
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_cancel_only_buyer_signature() fail {
  // This should fail because only buyer signed but seller signature is required too
  let buyer = #"face"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      // Only buyer signature, missing seller signature
      |> required_signer_hash(True, buyer)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_cancel_only_seller_signature() fail {
  // This should fail because only seller signed but buyer signature is required too
  let seller = #"beef"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(2000000))
      // Only seller signature, missing buyer signature  
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_cancel_wrong_refund_amount() fail {
  // This should fail because refund amount is incorrect
  let buyer = #"face"
  let seller = #"beef"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(2000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      // Wrong refund amount - should be 2000000 but giving 1000000
      |> tx_out(True, get_seller_address(), from_lovelace(1000000))
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.enact_bpmn.spend(
    Some(datumIn),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}
