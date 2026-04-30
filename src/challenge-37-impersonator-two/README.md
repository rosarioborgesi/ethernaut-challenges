# Ethernaut Challenge 37 — Impersonator Two

The goal of this level is to **steal all the funds from the contract**.

> 💡 Hint: look carefully at the two signatures used by the owner.

---

## 📍 Instance

```
0xAc4110d5C826430A8ca11058e92914B44C7E6a98
```

---

## 🧠 Vulnerability — ECDSA Nonce Reuse

From the [ImpersonatorTwoFactory](./ImpersonatorTwoFactory.sol), both signatures share the same `r` value:

```solidity
hex"e5648161e95dbf2bfc687b72b745269fa906031e2108118050aba59524a23c40"
```

👉 This means the same ECDSA nonce `k` was reused.

---

### 🔐 Why this is critical

ECDSA signatures follow:

```
s = k⁻¹ (z + r * d) mod n
```

Where:

* `d` = private key
* `k` = nonce
* `z` = message hash

If the same `k` is reused:

```
s1 = k⁻¹ (z1 + r*d)
s2 = k⁻¹ (z2 + r*d)
```

We can solve:

```
k = (z1 - z2) * inv(s1 - s2) mod n
d = (s1 * k - z1) * inv(r) mod n
```

👉 **Private key fully recovered**

---

## 🔓 Recover the Private Key

Using the script:

👉 [recover_private_key.py](./recover_private_key.py)

Run:

```bash
python recover_private_key.py
```

Output:

```
private key: 0x10a6891de55baf453d66c5faede86eabccf93f3d284540d205f24207670855cc
recovered address: 0x03E2cf81BBE61D1fD1421aFF98e8605a5A9e953a
expected owner:    0x03E2cf81BBE61D1fD1421aFF98e8605a5A9e953a
```

✅ Private key correctly recovered.

---

## 🚀 Exploit Strategy

After the factory setup:

* `nonce = 2`
* contract is locked
* admin is not the player

We must:

### Step 1 — Become admin

Message:

```solidity
abi.encodePacked("admin", "2", PLAYER)
```

Raw bytes:

```
0x61646d696e32ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Sign:

```bash
PLAYER=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
PK=0x10a6891de55baf453d66c5faede86eabccf93f3d284540d205f24207670855cc

MSG=0x61646d696e32ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0

cast wallet sign --private-key $PK $MSG
```

Result:

```
0x0620893ad27949e2b457d1b5ff9e269074f4d3ba8474bb33e7458e66e7d6e598193e0e65047891e42407b4ee1a9dda9f3f43ea26c03bd6c9e030c51361537c3d1c
```

---

### Step 2 — Unlock the contract

Message:

```solidity
abi.encodePacked("lock", "3")
```

Raw bytes:

```
0x6c6f636b33
```

Sign:

```bash
MSG=0x6c6f636b33

cast wallet sign --private-key $PK $MSG
```

Result:

```
0x306cff6fcc22eb595fe43f292d98021816b065ffd3f1ae379ca8e167cca9d6c40c1b5972f86b06d2d9c13b90413c805ef05003ba1ee755765656eae0d8918fa01c
```

---

### 🧪 Python verification

Using `signatures.py`:

```bash
python signatures.py
```

```
setAdmin signature: 0x0620893ad27949e2b457d1b5ff9e269074f4d3ba8474bb33e7458e66e7d6e598193e0e65047891e42407b4ee1a9dda9f3f43ea26c03bd6c9e030c51361537c3d1c
unlock signature: 0x306cff6fcc22eb595fe43f292d98021816b065ffd3f1ae379ca8e167cca9d6c40c1b5972f86b06d2d9c13b90413c805ef05003ba1ee755765656eae0d8918fa01c
```

---

## 🧪 Solve the Challenge Locally

Test:

👉 [ImpersonatorTwoTest.t.sol](../../test/challenge-37-impersonator-two/ImpersonatorTwoTest.t.sol)

---

## 🌐 Solve on Sepolia

Script:

👉 [SolveImpersonatorTwo.s.sol](../../script/challenge-37-impersonator-two/SolveImpersonatorTwo.s.sol)

Run:

```bash
IMPERSONATOR_TWO=0xAc4110d5C826430A8ca11058e92914B44C7E6a98 \
PLAYER=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
SET_ADMIN_SIG=0x0620893ad27949e2b457d1b5ff9e269074f4d3ba8474bb33e7458e66e7d6e598193e0e65047891e42407b4ee1a9dda9f3f43ea26c03bd6c9e030c51361537c3d1c \
SWITCH_LOCK_SIG=0x306cff6fcc22eb595fe43f292d98021816b065ffd3f1ae379ca8e167cca9d6c40c1b5972f86b06d2d9c13b90413c805ef05003ba1ee755765656eae0d8918fa01c \
forge script script/challenge-37-impersonator-two/SolveImpersonatorTwo.s.sol:SolveImpersonatorTwo \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

---

## ✅ Challenge Solved

