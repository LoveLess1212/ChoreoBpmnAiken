# Blockchain-Aided Enactment of Choreographed Penalties: From Contractual Obligations to Smart Contracts

This repository contains the **Aiken smart contract implementation** for research on blockchain-based choreography enactment with penalty mechanisms. The project explores how contractual obligations can be transformed into enforceable smart contracts using BPMN (Business Process Model and Notation) workflows.

## Research Overview

This implementation demonstrates a novel approach to:
- **Choreography Enactment**: Automated execution of multi-party business processes through smart contracts
- **Penalty Enforcement**: Blockchain-based mechanisms for enforcing contractual penalties and compensations
- **BPMN Integration**: Translation of business process models into executable smart contract logic
- **Multi-Party Coordination**: Secure coordination between buyers and sellers through cryptographic signatures

## Smart Contract Architecture

The core validator [`validatorv2.ak`](validators/validatorv2.ak) implements a state machine that manages:

### State Types
- **`InitState`**: Initial contract state with buyer, seller, workflow definition, and payment amount
- **`ActiveState`**: Active workflow state tracking current task, artifact CIDs, and progress

### Actions (Redeemers)
- **`Task`**: Progress to the next task in the choreography workflow
- **`Compensated`**: End workflow with penalty compensation to the seller
- **`Uncompensated`**: End workflow with full payment to the seller

### Key Features
- **Workflow Validation**: Ensures proper BPMN task transitions using [`NodeState`](lib/constant/typev2.ak) 
- **Multi-Signature Requirements**: Both buyer and seller must sign all transactions
- **IPFS Integration**: Artifacts are stored off-chain with validated IPFS CIDs
- **Penalty Mechanisms**: Automated compensation based on workflow outcomes

## Project Structure

```
validators/           # Smart contract validators
├── validatorv2.ak   # Main BPMN enactment validator
├── testval.ak       # Positive test cases
└── testfail.ak      # Negative test cases (expected failures)

lib/
├── constant/
│   └── typev2.ak    # Type definitions for contract states and actions
└── helper/
    ├── helper.ak    # Core validation functions
    └── test_helper.ak # Test utilities and mock data

docs/                # Generated documentation
```

## Development

### Building

```sh
aiken build
```

### Testing

The project includes comprehensive test suites demonstrating various choreography scenarios:

**Positive Tests** ([`testval.ak`](validators/testval.ak)):
- Task progression through BPMN workflows
- Contract finalization scenarios
- Cancellation with proper compensations

**Negative Tests** ([`testfail.ak`](validators/testfail.ak)):
- Missing signatures validation
- Invalid workflow transitions
- Improper compensation amounts

Run all tests:
```sh
aiken check
```

Run specific test patterns:
```sh
aiken check -m enact_bpmn
```

### Configuration

### Documentation

Generate HTML documentation:
```sh
aiken docs
```

## Research Context

This implementation supports research into:
- **Smart Contract Choreographies**: How blockchain technology can automate complex multi-party business processes
- **Penalty Enforcement Mechanisms**: Cryptographically secure methods for enforcing contractual penalties
- **Business Process Automation**: Translation of traditional business processes into decentralized autonomous systems
- **Multi-Party Coordination**: Secure protocols for coordinating actions between multiple parties without trusted intermediaries

## Key Validation Logic

The contract enforces several critical properties:
1. **Signature Requirements**: All state transitions require signatures from both buyer and seller
2. **Workflow Integrity**: Task progressions must follow valid BPMN transitions
3. **Artifact Validation**: All referenced artifacts must have valid IPFS content identifiers
4. **Payment Guarantees**: Compensations and final payments are cryptographically enforced
5. **State Consistency**: Contract state remains consistent across all transitions

---

*This implementation is part of ongoing research into blockchain-aided business process automation and smart contract choreographies.*