use aiken/builtin.{mod_integer}
use aiken/fuzz
use aiken/primitive/bytearray
use cardano/address.{Address, VerificationKey}
use cardano/assets.{from_lovelace}
use cardano/transaction.{Transaction}
use constant/typev2.{
  ActiveEscrow, BpmnEscrowDatum, Cancel, Finalize, InitEscrow, NodeState,
  Ongoing, Start, Task,
}
use helper/helper.{is_next_task_valid, is_valid_ipfs_cid}
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

fn generate_artifact_cid(seed: Int) -> ByteArray {
  // Generate a mock IPFS CID based on a seed
  // Format: "Qm" prefix + 44 character base58-like string (represented as hex)
  let base_cid =
    #"516d546573744369643132333435363738393061626364656631323334353637383930616263646566"
  // Append seed as hex to make it unique
  let seed_hex =
    if seed == 0 {
      #"30"
    } else if seed == 1 {
      #"31"
    } else if seed == 2 {
      #"32"
    } else if seed == 3 {
      #"33"
    } else {
      #"39"
    }
  bytearray.concat(base_cid, seed_hex)
}

fn get_nth_workflow(n: Int, end: Bool) -> NodeState {
  NodeState {
    current: mock_key_hash(n),
    incoming: if n == 0 {
      None
    } else if mod_integer(n, 2) == 0 {
      Some([mock_key_hash(n - 2), mock_key_hash(n - 1)])
    } else {
      Some([mock_key_hash(n - 1)])
    },
    outgoing: if end {
      None
    } else if mod_integer(n, 2) == 0 {
      Some([mock_key_hash(n + 1), mock_key_hash(n + 2)])
    } else {
      Some([mock_key_hash(n + 1)])
    },
  }
}

fn get_datumIn_Start() -> BpmnEscrowDatum {
  let a =
    InitEscrow {
      seller: #"beef",
      buyer: #"face",
      workflow: get_nth_workflow(0, False),
      hashBpmn: mock_key_hash(0),
      proceed: 2000000,
      status: Start,
    }
  a
}

fn get_datumout_Start() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      seller: #"beef",
      buyer: #"face",
      workflow: get_nth_workflow(1, False),
      artifactCid: generate_artifact_cid(0),
      hashBpmn: mock_key_hash(0),
      status: Start,
      proceed: 2000000,
    }
  a
}

// could also take this as In run

fn get_datumOutRun1() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      buyer: #"face",
      seller: #"beef",
      workflow: get_nth_workflow(2, False),
      artifactCid: generate_artifact_cid(1),
      hashBpmn: mock_key_hash(0),
      status: Ongoing,
      proceed: 2000000,
    }
  a
}

fn get_datumOutRun2() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      buyer: #"face",
      seller: #"beef",
      workflow: get_nth_workflow(3, True),
      artifactCid: generate_artifact_cid(2),
      hashBpmn: mock_key_hash(0),
      status: Ongoing,
      proceed: 2000000,
    }
  a
}

fn get_datumOutRun3() -> BpmnEscrowDatum {
  let a =
    ActiveEscrow {
      buyer: #"face",
      seller: #"beef",
      workflow: get_nth_workflow(3, True),
      artifactCid: generate_artifact_cid(2),
      hashBpmn: mock_key_hash(0),
      status: Ongoing,
      proceed: 2000000,
    }
  a
}

test is_valid_mock_cid() {
  let cid = generate_artifact_cid(0)
  is_valid_ipfs_cid(cid)
}

test test_is_next_task_valid(n: Int via fuzz.int()) {
  let old_task = get_nth_workflow(n, False)
  let new_task = get_nth_workflow(n + 1, False)
  is_next_task_valid(old_task, new_task)
}

test escrow_bpmn_task1() {
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
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}

test escrow_bpmn_task2() {
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
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Task,
    mock_utxo_ref(0, 1),
    mock_tx,
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
          from_lovelace(11000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_seller_address(), from_lovelace(11000000))
      |> required_signer_hash(True, buyer)
      |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Finalize,
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
    |> tx_out(is_buyer_refunded, get_buyer_address(), from_lovelace(5000000))
    |> tx_out(True, get_seller_address(), from_lovelace(6000000))
    |> tx_out(is_initDatum, get_seller_address(), from_lovelace(2000000))
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
          from_lovelace(11000000),
          mock_script_address(1, None),
        )
      |> tx_in_inline_datum(True, datumIn)
      |> tx_out(True, get_buyer_address(), from_lovelace(5000000))
      |> tx_out(True, get_seller_address(), from_lovelace(6000000))
      |> required_signer_hash(True, buyer)
      // |> required_signer_hash(True, seller)
      |> complete()
  validatorv2.escrow_bpmn.spend(
    Some(datumIn),
    Cancel,
    mock_utxo_ref(0, 1),
    mock_tx,
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
    mock_utxo_ref(0, 1),
    mock_tx,
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
    mock_utxo_ref(0, 1),
    mock_tx,
  )
}
