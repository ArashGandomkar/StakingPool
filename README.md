# ERC20 Staking Pool

A simple and secure ERC20 staking pool smart contract built with **Solidity** and tested using **Foundry**.

This project allows users to stake ERC20 tokens, earn rewards over time, withdraw their stake, and claim accumulated rewards. The contract is protected against reentrancy attacks and uses OpenZeppelin's audited libraries.

---

## Features

- Stake ERC20 tokens
- Withdraw staked tokens
- Time-based reward distribution
- Claim accumulated rewards
- Owner-funded reward pool
- Configurable reward rate
- Reentrancy protection
- Comprehensive unit tests using Foundry

---

## Technologies

- Solidity `^0.8.20`
- Foundry
- OpenZeppelin Contracts

---

## Project Structure

```
.
├── src/
│   └── StakingPool.sol
├── test/
│   └── StakingPool.t.sol
├── script/
├── lib/
├── foundry.toml
└── README.md
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/ArashGandomkar/StakingPool.git
cd StakingPool
```

Install dependencies:

```bash
forge install
```

---

## Build

```bash
forge build
```

---

## Run Tests

Run all tests:

```bash
forge test
```

Run tests with verbose output:

```bash
forge test -vvvv
```

Generate gas report:

```bash
forge test --gas-report
```

---

## Contract Overview

### Stake

Users deposit ERC20 tokens into the staking pool.

### Withdraw

Users can withdraw part or all of their staked tokens.

### Rewards

Rewards accumulate over time according to the configured reward rate.

### Claim Rewards

Users can claim their earned rewards at any time, provided the reward pool contains sufficient funds.

### Owner Functions

The contract owner can:

- Fund the reward pool
- Update the reward rate

---

## Security

The contract uses:

- OpenZeppelin `SafeERC20`
- OpenZeppelin `Ownable`
- OpenZeppelin `ReentrancyGuard`

to improve security and reduce common vulnerabilities.

---

## Testing

The project includes unit tests covering:

- Staking
- Withdrawals
- Reward calculation
- Reward claiming
- Reward funding
- Owner permissions
- Revert scenarios
- Event emission

---

## License

This project is licensed under the MIT License.
