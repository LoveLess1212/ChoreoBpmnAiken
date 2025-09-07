use aiken/builtin.{mod_integer}
use aiken/primitive/bytearray
use cardano/address.{Address, VerificationKey}
use constant/typev2.{ActiveState, BpmnEnactDatum, InitState, NodeState}
// use helper/helper as t
use mocktail/virgin_key_hash.{mock_key_hash}

pub fn get_buyer_address() -> Address {
  let address =
    Address {
      payment_credential: VerificationKey(#"face"),
      stake_credential: None,
    }
  address
}

pub fn get_seller_address() -> Address {
  let address =
    Address {
      payment_credential: VerificationKey(#"beef"),
      stake_credential: None,
    }
  address
}

pub fn generate_artifact_cid(seed: Int) -> ByteArray {
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

pub fn get_nth_workflow(n: Int, end: Bool) -> NodeState {
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

pub fn get_datumIn_Start() -> BpmnEnactDatum {
  let a =
    InitState {
      seller: #"beef",
      buyer: #"face",
      workflow: get_nth_workflow(0, False),
      hashBpmn: mock_key_hash(0),
      proceed: 2000000,
    }
  a
}

pub fn get_datumout_Start() -> BpmnEnactDatum {
  let a =
    ActiveState {
      seller: #"beef",
      buyer: #"face",
      workflow: get_nth_workflow(1, False),
      artifactCid: generate_artifact_cid(0),
      hashBpmn: mock_key_hash(0),
      proceed: 2000000,
    }
  a
}

// could also take this as In run

pub fn get_datumOutRun1() -> BpmnEnactDatum {
  let a =
    ActiveState {
      buyer: #"face",
      seller: #"beef",
      workflow: get_nth_workflow(2, False),
      artifactCid: generate_artifact_cid(1),
      hashBpmn: mock_key_hash(0),
      proceed: 2000000,
    }
  a
}

pub fn get_datumOutRun2() -> BpmnEnactDatum {
  let a =
    ActiveState {
      buyer: #"face",
      seller: #"beef",
      workflow: get_nth_workflow(3, True),
      artifactCid: generate_artifact_cid(2),
      hashBpmn: mock_key_hash(0),
      proceed: 2000000,
    }
  a
}
