# Ethernaut Challenge 39 — Forger

This challenge demonstrates how replay protection based on raw signature bytes can be bypassed when multiple valid encodings of the same ECDSA signature are accepted.

The contract uses OpenZeppelin’s `ECDSA.recover()` implementation to validate signed mint authorizations, but tracks used signatures incorrectly by hashing the raw signature bytes instead of the signed message.

By exploiting support for both standard 65-byte signatures and compact 64-byte EIP-2098 signatures, it becomes possible to reuse the same authorization twice and mint more tokens than intended.

Instance address:

```bash
FORGER=0xb5Aa9248167E5eaE4bB214366BD9c6e44d423eb9
```

---

# 🎯 Goal

The challenge is solved when:

```solidity
totalSupply() > 100 ether
```

The contract already provides a valid owner signature that authorizes minting `100 ether` worth of tokens.

The intended replay protection is:

```solidity
require(!signatureUsed[keccak256(signature)], SignatureUsed());
```

The challenge is to bypass this protection and mint additional tokens.

---

# 🔍 Initial Analysis

The relevant minting function is:

```solidity
function createNewTokensFromOwnerSignature(
    bytes calldata signature,
    address receiver,
    uint256 amount,
    bytes32 salt,
    uint256 deadline
) public {
    require(block.timestamp <= deadline, SignatureExpired());
    require(!signatureUsed[keccak256(signature)], SignatureUsed());

    bytes32 messageHash =
        keccak256(abi.encode(receiver, amount, salt, deadline));

    address signer = ECDSA.recover(messageHash, signature);

    require(signer == owner, InvalidSigner(signer));

    signatureUsed[keccak256(signature)] = true;

    _mint(receiver, amount);
}
```

The provided signature is:

```text
f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809402f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb1c
```

The contract stores replay protection using:

```solidity
signatureUsed[keccak256(signature)]
```

This means replay protection is based on the **raw signature bytes**, not on the signed message itself.

That detail is the core vulnerability.

---

# 🧠 Understanding the Signature Format

A standard ECDSA signature is 65 bytes long:

```text
r || s || v
```

Where:

* `r` = first 32 bytes
* `s` = next 32 bytes
* `v` = final 1 byte

For the provided signature:

```text
r = f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809

s = 402f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb

v = 1c
```

`0x1c` corresponds to:

```text
v = 28
```

---

# 🔍 The Important OpenZeppelin Detail

The challenge uses OpenZeppelin `v4.6.0`.

Inside `ECDSA.sol`, `recover()` supports both:

* standard 65-byte signatures
* compact 64-byte EIP-2098 signatures

Relevant code:

```solidity
function tryRecover(bytes32 hash, bytes memory signature)
    internal
    pure
    returns (address, RecoverError)
{
    // 65-byte signature
    if (signature.length == 65) {
        ...
    }
    // 64-byte EIP-2098 compact signature
    else if (signature.length == 64) {
        ...
    }
}
```

This is the key insight of the challenge.

---

# 🧠 EIP-2098 Compact Signatures

EIP-2098 compresses:

```text
r || s || v
```

into:

```text
r || vs
```

The `v` value is embedded inside the highest bit of `s`.

Since our original signature has:

```text
v = 28
```

the highest bit of `s` must be set.

Original:

```text
s  = 0x402f...
```

Compact representation:

```text
vs = 0xc02f...
```

because:

```text
0x40 | 0x80 = 0xc0
```

The resulting compact signature becomes:

```solidity
bytes memory sig64 =
    hex"f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809c02f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb";
```

---

# ⚠️ Why Replay Protection Fails

The contract assumes signatures are unique because it stores:

```solidity
signatureUsed[keccak256(signature)]
```

However:

```text
keccak256(sig65) != keccak256(sig64)
```

because the raw bytes are different.

But OpenZeppelin still recovers the exact same signer from both representations.

So both of these calls are valid:

```solidity
forger.createNewTokensFromOwnerSignature(
    sig65,
    RECEIVER,
    AMOUNT,
    SALT,
    DEADLINE
);

forger.createNewTokensFromOwnerSignature(
    sig64,
    RECEIVER,
    AMOUNT,
    SALT,
    DEADLINE
);
```

Each call mints:

```text
100 ether
```

Result:

```text
totalSupply = 200 ether
```

which satisfies the challenge condition.

---

# 🧪 Local Test

To reproduce and validate the exploit locally, I wrote the following Foundry test:

[ForgerTest.t.sol](../../test/challenge-39-forger/ForgerTest.t.sol)

The test demonstrates that:

* the original 65-byte signature is accepted
* the compact 64-byte EIP-2098 version is also accepted
* both signatures recover the same owner
* replay protection fails because it hashes the raw signature bytes

---

# 🚀 Solving the Challenge on Sepolia

To solve the challenge on Sepolia, I wrote the following Foundry script:

[SolveForger.s.sol](../../script/challenge-39-forger/SolveForger.s.sol)

Run it with:

```bash
FORGER=0xb5Aa9248167E5eaE4bB214366BD9c6e44d423eb9 \
forge script script/challenge-39-forger/SolveForger.s.sol:SolveForgerScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

Output:

```text
== Logs ==
Forger: 0xb5Aa9248167E5eaE4bB214366BD9c6e44d423eb9
Total supply: 200000000000000000000
```

Challenge solved.

---

# 🛡️ Security Takeaway

This challenge highlights an important cryptographic design mistake:

> signatures should never be treated as unique identifiers.

Different encodings of the same authorization can exist.

The vulnerable design:

```solidity
signatureUsed[keccak256(signature)]
```

The safer approach is to track replay protection using:

* signed message hashes
* nonces
* EIP-712 typed data
* explicit authorization ids

rather than relying on raw signature bytes.

This challenge is also an excellent example of why understanding low-level ECDSA encoding details matters when building smart contract authorization systems.
