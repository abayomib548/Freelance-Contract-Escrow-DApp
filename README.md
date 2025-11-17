# 🤝 Freelance Contract Escrow DApp

A decentralized escrow system for freelance contracts built on the Stacks blockchain using Clarity smart contracts. This DApp ensures secure payments between clients and freelancers by holding funds in escrow until work completion and approval.

## 🌟 Features

- **Secure Escrow**: Funds are locked in the contract until work is completed and approved
- **Dispute Resolution**: Community-based voting system for resolving conflicts
- **Deadline Management**: Automatic contract expiration handling
- **Multi-Status Tracking**: Complete workflow from creation to completion
- **Emergency Controls**: Admin functions for critical situations

## 📋 Contract Workflow

1. **Create Contract** 💼 - Client creates a contract with freelancer details, amount, and deadline
2. **Submit Work** 📝 - Freelancer submits completed work
3. **Review & Approve** ✅ - Client reviews and approves/rejects work
4. **Payment Release** 💰 - Funds automatically released to freelancer upon approval
5. **Dispute Resolution** ⚖️ - Community voting system for conflicts

## 🚀 Usage Instructions

### Creating a Contract

```clarity
(contract-call? .Freelance-Contract-Escrow-DApp create-contract 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; freelancer address
  u1000000                                        ;; amount in microSTX
  u1000                                          ;; deadline block height
  "Website development project")                  ;; description
```

### Submitting Work

```clarity
(contract-call? .Freelance-Contract-Escrow-DApp submit-work u0) ;; contract-id
```

### Approving Work

```clarity
(contract-call? .Freelance-Contract-Escrow-DApp approve-work u0) ;; contract-id
```

### Initiating Dispute

```clarity
(contract-call? .Freelance-Contract-Escrow-DApp initiate-dispute u0) ;; contract-id
```

### Voting on Dispute

```clarity
(contract-call? .Freelance-Contract-Escrow-DApp vote-dispute u0 "client") ;; contract-id, vote
```

## 📊 Contract States

- **active** - Contract is live and work is in progress
- **submitted** - Freelancer has submitted work for review
- **completed** - Work approved and payment released
- **disputed** - Dispute initiated, awaiting resolution
- **cancelled** - Contract cancelled, funds returned to client
- **expired** - Contract expired past deadline
- **emergency-withdrawn** - Emergency admin withdrawal

## 🔍 Read-Only Functions

- `get-contract` - Retrieve contract details
- `get-contract-funds` - Check escrowed funds
- `get-next-contract-id` - Get next available contract ID
- `get-dispute-vote` - Check user's dispute vote
- `get-dispute-counts` - View dispute voting statistics

## ⚠️ Error Codes

- `u100` - Owner only function
- `u101` - Contract not found
- `u102` - Unauthorized access
- `u103` - Invalid contract status
- `u104` - Insufficient funds
- `u105` - Already exists
- `u106` - Contract expired
- `u107` - Contract not expired

