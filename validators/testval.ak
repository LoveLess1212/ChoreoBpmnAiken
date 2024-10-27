use cardano/address.{Address, VerificationKey}
use cardano/assets.{from_lovelace}
use cardano/transaction.{Transaction}
use constant/typev2.{
  ActiveEscrow, BpmnEscrowDatum, Cancel, Finalize, InitEscrow, NodeState, Start,
  Task,
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

fn get_buyer_address() -> Address {
  let address =
    Address {
      payment_credential: VerificationKey(#"face"),
      stake_credential: None,
    }
  address
}

fn get_seller_address() -> Address {
  let address =
    Address {
      payment_credential: VerificationKey(#"beef"),
      stake_credential: None,
    }
  address
}

fn get_datumIn_Start() -> BpmnEscrowDatum {
  let a =
    InitEscrow {
      seller: #"beef",
      price: 200,
      workflow: NodeState {
        current: mock_key_hash(0),
        incoming: None,
        outgoing: Some([mock_key_hash(1), mock_key_hash(2)]),
      },
      hashBpmn: mock_key_hash(0),
    }
  a
}

fn get_datumout_Start() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      seller: #"beef",
      buyer: #"face",
      price: 200,
      workflow: NodeState {
        current: mock_key_hash(0),
        incoming: None,
        outgoing: Some([mock_key_hash(1), mock_key_hash(2)]),
      },
      hashBpmn: mock_key_hash(0),
    }
  a
}

// could also take this as In run

fn get_datumOutRun1() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      buyer: #"face",
      seller: #"beef",
      price: 200,
      workflow: NodeState {
        current: mock_key_hash(1),
        incoming: Some(mock_key_hash(0)),
        outgoing: Some([mock_key_hash(3)]),
      },
      hashBpmn: mock_key_hash(0),
    }
  a
}

fn get_datumOutRun2() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      buyer: #"face",
      seller: #"beef",
      price: 200,
      workflow: NodeState {
        current: mock_key_hash(3),
        incoming: Some(mock_key_hash(1)),
        outgoing: None,
      },
      hashBpmn: mock_key_hash(0),
    }
  a
}

test escrow_bpmn_start() {
  let buyer = #"face"
  //   let output_reference = tx_in(0, 1)
  let datumIn = get_datumIn_Start()
  let datumOut = get_datumout_Start()
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
      |> tx_out(True, mock_script_address(1, None), from_lovelace(0))
      |> tx_out_inline_datum(True, datumOut)
      |> required_signer_hash(True, buyer)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Start(buyer),
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}

fn sampleTaskIn1() -> NodeState {
  NodeState {
    current: mock_key_hash(1),
    incoming: Some(mock_key_hash(0)),
    outgoing: Some([mock_key_hash(3)]),
  }
}

test escrow_bpmn_task1() {
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumout_Start()
  let datumOut = get_datumOutRun1()
  let taskIn = sampleTaskIn1()
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
      |> tx_out(True, mock_script_address(1, None), from_lovelace(0))
      |> tx_out_inline_datum(True, datumOut)
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Task(taskIn),
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}

test escrow_bpmn_task2() {
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumOutRun1()
  let datumOut = get_datumOutRun2()
  let taskIn =
    NodeState {
      current: mock_key_hash(3),
      incoming: Some(mock_key_hash(1)),
      outgoing: None,
    }
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
      |> tx_out(True, mock_script_address(1, None), from_lovelace(0))
      |> tx_out_inline_datum(True, datumOut)
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Task(taskIn),
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}

test escrow_bpmn_finalize() {
  let seller = #"beef"
  let buyer = #"face"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(200),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(200))
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Finalize,
    mock_tx,
    mock_utxo_ref(0, 1),
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
        from_lovelace(200),
        mock_script_address(1, None),
      )
    |> tx_in_inline_datum(is_initDatum, get_datumIn_Start())
    |> tx_in_inline_datum(is_activeDatum, get_datumout_Start())
    |> tx_out(is_buyer_refunded, get_buyer_address(), from_lovelace(200))
    |> complete()
}

test escrow_bpmn_cancel() {
  let buyer = #"face"
  let datumIn = get_datumOutRun2()
  let mock_tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(200),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_buyer_address(), from_lovelace(200))
      |> required_signer_hash(True, buyer) // |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Cancel,
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}

test escrow_bpmn_cancel_init() {
  let test_case =
    TestCaseCancel {
      is_buyer_signed: False,
      is_seller_signed: True,
      is_initDatum: True,
      is_activeDatum: False,
      is_buyer_refunded: False,
    }
  let mock_tx = get_cancel_tx(test_case)
  validatorv2.escrow_bpmn.spend(
    Some(get_datumIn_Start()),
    Cancel,
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}

test escrow_bpmn_cancel_active() {
  let test_case =
    TestCaseCancel {
      is_buyer_signed: False,
      is_seller_signed: True,
      is_initDatum: False,
      is_activeDatum: True,
      is_buyer_refunded: True,
    }
  let mock_tx = get_cancel_tx(test_case)
  validatorv2.escrow_bpmn.spend(
    Some(get_datumout_Start()),
    Cancel,
    mock_tx,
    mock_utxo_ref(0, 1),
  )
}
