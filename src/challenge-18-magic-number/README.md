# Ethernaut Challenge 18 — Magic Number

This challenge requires deploying a **very small contract** (≤ 10 bytes) that returns the answer to:

```solidity
whatIsTheMeaningOfLife() -> bytes32
````

The correct answer is:

```solidity
bytes32(uint256(42))
```

Instance address:

```
0x804197e08B99b7953cC146DAdED199a7210F491b
```

---

## 🎯 Goal

Provide a **solver contract** that returns `42` as a `bytes32`, with runtime code size ≤ 10 bytes.

---

## 🧠 Thought process

A normal Solidity contract like this:

```solidity
contract Solver {
    function whatIsTheMeaningOfLife() external pure returns (bytes32) {
        return bytes32(uint256(42));
    }
}
```

does **not** work because:

* Solidity adds function dispatching logic
* ABI encoding/decoding
* metadata

👉 Result: compiled bytecode is **much larger than 10 bytes**

So we must:

> Write the contract **directly in EVM bytecode**

🔗 Opcodes reference: [https://www.evm.codes/](https://www.evm.codes/)

---

## ⚙️ Key mental model

### Creation code

* runs **once** at deployment
* returns the runtime code

### Runtime code

* becomes the contract code on-chain
* executes on every call
* must return `42`

---

## 🔬 Step 1 — Build the runtime code

We want the contract to:

1. store `42` in memory
2. return 32 bytes from memory

### Final runtime bytecode

```
602a60005260206000f3
```

---

### 🔍 Breakdown

#### Push value `42`

```
60 2a   // PUSH1 0x2a
```

Stack:

```
[0x2a]
```

---

#### Push memory offset `0`

```
60 00   // PUSH1 0x00
```

Stack:

```
[0x2a, 0x00]
```

---

#### Store value in memory

```
52      // MSTORE
```

This stores `42` as a full 32-byte word:

```
memory[0x00...0x1f] = 0x...002a
```

---

#### Push return size (32 bytes)

```
60 20   // PUSH1 0x20
```

---

#### Push return offset

```
60 00   // PUSH1 0x00
```

---

#### Return data

```
f3      // RETURN
```

Returns:

* offset = 0
* size = 32

Result:

```
0x000000000000000000000000000000000000000000000000000000000000002a
```

---

## 📏 Runtime size check

```
60 2a → 2 bytes  
60 00 → 2 bytes  
52    → 1 byte  
60 20 → 2 bytes  
60 00 → 2 bytes  
f3    → 1 byte  
```

Total:

```
10 bytes ✅
```

---

## 🏗️ Step 2 — Build the creation code

The runtime code is:

```
602a60005260206000f3
```

We now need creation code that:

1. stores this runtime code in memory
2. returns it

---

### Final creation bytecode

```
69602a60005260206000f3600052600a6016f3
```

---

### 🔍 Breakdown

#### Push runtime code (10 bytes)

```
69 602a60005260206000f3   // PUSH10 runtime_code
```

---

#### Push memory offset

```
60 00
```

---

#### Store in memory

```
52   // MSTORE
```

⚠️ Important detail:

* MSTORE always writes **32 bytes**
* the value is **right-aligned**

Memory becomes:

```
0x000...000602a60005260206000f3
```

So the runtime code starts at:

```
32 - 10 = 22 bytes = 0x16
```

---

#### Push size (10 bytes)

```
60 0a
```

---

#### Push offset (0x16)

```
60 16
```

---

#### Return runtime code

```
f3
```

This returns:

* 10 bytes
* starting from offset `0x16`

👉 This becomes the deployed contract code

---

## 🧾 Visual summary

### Runtime code

```
602a      PUSH1 0x2a
6000      PUSH1 0x00
52        MSTORE
6020      PUSH1 0x20
6000      PUSH1 0x00
f3        RETURN
```

---

### Creation code

```
69 602a60005260206000f3   PUSH10 runtime_code
60 00                     PUSH1 0x00
52                        MSTORE
60 0a                     PUSH1 0x0a
60 16                     PUSH1 0x16
f3                        RETURN
```

---

## 🚀 Step 3 — Deploy the solver

```bash
cast --rpc-url $SEPOLIA_RPC_URL \
     --account ethernaut \
     send --create 0x69602a60005260206000f3600052600a6016f3
```

Tx hash:

```
0xa23ec3618f66484840eb5571c40668ef96ee27678a2459fbf90763b15e3247f1
```

Solver address:

```
0x886416F67cCff70084Eb6ED76f66E4673d5dBade
```

---

## 🔗 Step 4 — Register the solver

```bash
cast send $MAGIC_NUMBER_SEPOLIA \
    "setSolver(address)" $SOLVER_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Tx hash:

```
0xb5aad3f37243666f90c01593204af3d5723bae0f9532670f34144fa221c9515d
```

---

## ✅ Step 5 — Verify

```bash
cast call $MAGIC_NUMBER_SEPOLIA \
    "solver()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000886416f67ccff70084eb6ed76f66e4673d5dbade
```

---

## 🛡️ Key takeaways

* Smart contracts are ultimately just **EVM bytecode**
* Solidity is only an abstraction layer
* Deployment code and runtime code are different
* Extreme optimization sometimes requires writing raw opcodes
* Understanding stack + memory is fundamental for low-level security

