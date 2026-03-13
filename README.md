# Ethernaut Solutions

This repository contains my solutions to the **OpenZeppelin Ethernaut challenges**.

https://ethernaut.openzeppelin.com/

---

# Repository Structure

Each challenge has its own folder containing a detailed write-up.

The write-up explains:

- the goal of the challenge
- relevant parts of the contract
- the reasoning used to identify the solution
- the commands used to interact with the contract

Example structure:

```
ethernaut-solutions
│
├── 00-hello-ethernaut
│   └── README.md
│
├── 01-fallback
│   └── README.md
│
├── 02-fallout
│   └── README.md
│
└── ...
```

Each README is written as a **mini technical write-up**, similar to how security researchers document vulnerabilities.


---

# Environment Setup

The Sepolia RPC URL is stored in an `.env` file:

```
SEPOLIA_RPC_URL=<your_rpc_url>
```

Environment variables can be loaded with:

```
source .env
```

This allows Foundry commands such as:

```
cast call
cast send
```

to interact with the Ethernaut contracts on Sepolia.

---

# Ethernaut Contract

Main Ethernaut contract:

```
0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6
```

Etherscan:

https://sepolia.etherscan.io/address/0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6

---

# My Wallet Address

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Transactions executed to solve the challenges can be inspected on Sepolia Etherscan.

---

# Purpose of this Repository

The goal of this repository is to document my learning journey in **smart contract development and security**.

By solving Ethernaut levels and documenting the reasoning behind each solution, I aim to build a deeper understanding of:

- Solidity design patterns
- common smart contract vulnerabilities
- secure smart contract development practices
- low-level interaction with Ethereum contracts

Each challenge demonstrates a specific concept that frequently appears in real-world smart contracts.

---

# Author

Rosario Borgesi

Solidity developer focused on smart contract development and security.