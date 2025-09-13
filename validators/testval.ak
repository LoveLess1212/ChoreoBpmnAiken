use aiken/fuzz
use cardano/assets.{from_lovelace}
use cardano/transaction.{Transaction}
use constant/typev2.{Compensated, Task, Uncompensated}
use helper/helper.{is_next_task_valid, is_valid_ipfs_cid}
use helper/test_helper.{
  generate_artifact_cid, get_buyer_address, get_datumIn_Start, get_datumOutRun1,
  get_datumOutRun2, get_datumout_Start, get_nth_workflow, get_seller_address,
}
use mocktail.{
  complete, mocktail_tx, required_signer_hash, tx_in, tx_in_inline_datum, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_address.{mock_script_address}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}
use validatorv2

test is_valid_mock_cid() {
  let cid = generate_artifact_cid(0)
  is_valid_ipfs_cid(cid)
}

test test_is_next_task_valid(n: Int via fuzz.int_between(0, 100)) {
  let old_task = get_nth_workflow(n, False)
  let new_task = get_nth_workflow(n + 1, False)
  is_next_task_valid(old_task, new_task)
}

test enact_bpmn_task1() {
  let seller = #"beef"
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

test enact_bpmn_task2() {
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumOutRun1()
  let datumOut = get_datumOutRun2()
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
      |> tx_out_inline_datum(True, datumOut)
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

test enact_bpmn_finalize() {
  let seller = #"beef"
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

type TestCaseCancel {
  is_buyer_signed: Bool,
  is_seller_signed: Bool,
  is_initDatum: Bool,
  is_activeDatum: Bool,
  is_buyer_refunded: Bool,
}

fn get_cancel_tx(test_case: TestCaseCancel) -> Transaction {
  let buyer = #"face"
  let seller = #"beef"
  let TestCaseCancel {
    is_buyer_signed,
    is_seller_signed,
    is_initDatum,
    is_activeDatum,
    is_buyer_refunded,
  } = test_case
  mocktail_tx()
    |> required_signer_hash(is_buyer_signed, buyer)
    |> required_signer_hash(is_seller_signed, seller)
    |> tx_in(
        True,
        mock_tx_hash(0),
        1,
        from_lovelace(11000000),
        mock_script_address(1, None),
      )
    |> tx_in_inline_datum(is_initDatum, get_datumIn_Start())
    |> tx_in_inline_datum(is_activeDatum, get_datumOutRun2())
    |> tx_out(is_buyer_refunded, get_buyer_address(), from_lovelace(2000000))
    |> tx_out(True, get_seller_address(), from_lovelace(2000000))
    |> tx_out(is_initDatum, get_seller_address(), from_lovelace(2000000))
    |> complete()
}

test enact_bpmn_cancel_init() {
  let test_case =
    TestCaseCancel {
      is_buyer_signed: True,
      is_seller_signed: True,
      is_initDatum: True,
      is_activeDatum: False,
      is_buyer_refunded: False,
    }
  let mock_tx = get_cancel_tx(test_case)
  validatorv2.enact_bpmn.spend(
    Some(get_datumIn_Start()),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test enact_bpmn_cancel_active() {
  let test_case =
    TestCaseCancel {
      is_buyer_signed: True,
      is_seller_signed: True,
      is_initDatum: False,
      is_activeDatum: True,
      is_buyer_refunded: True,
    }
  let mock_tx = get_cancel_tx(test_case)
  validatorv2.enact_bpmn.spend(
    Some(get_datumout_Start()),
    Compensated,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}
