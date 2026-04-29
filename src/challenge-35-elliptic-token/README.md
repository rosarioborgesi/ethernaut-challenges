# Ethernaut Challenge 35 — Elliptic Token
BOB created and owns a new ERC20 token with an elliptic curve–based signed voucher redemption system called `EllipticToken` (`ETK`).

Bob can create vouchers off-chain that can be redeemed on-chain for tokens.  
The contract also includes a custom permit system based on ECDSA signatures.

Bob is a lazy developer and “optimized” some steps of the ECDSA algorithm.

Your goal is to steal the `ETK` tokens that ALICE (`0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e`) just redeemed.

---

## Instance Address

```bash
ELLIPTIC_TOKEN=0x551c9cD11a73Bb4b85d4381fEac66ba2fd23596B
````

---

# 🎯 Goal

Drain Alice’s balance so that:

```solidity
balanceOf(ALICE) == 0
```

---

# 🔍 Initial Analysis

## Check Alice balance

```bash
ALICE_ADDRESS=0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e

cast call $ELLIPTIC_TOKEN \
    "balanceOf(address)(uint256)" \
    $ALICE_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
10000000000000000000
```

Alice owns `10 ETK`.

---

## Check total supply

```bash
cast call $ELLIPTIC_TOKEN \
    "totalSupply()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
10000000000000000000
```

Alice owns the entire token supply.

So the cleanest path is not to mint more tokens, but to obtain permission to move Alice’s balance.

That means the interesting function is:

```solidity
permit(...)
```

---

# 🔍 Inspect permit()

```solidity
function permit(
    uint256 amount,
    address spender,
    bytes memory tokenOwnerSignature,
    bytes memory spenderSignature
) external {
    bytes32 permitHash = keccak256(abi.encode(amount));

    require(!usedHashes[permitHash], HashAlreadyUsed());
    require(!usedHashes[bytes32(amount)], HashAlreadyUsed());

    address tokenOwner =
        ECDSA.recover(bytes32(amount), tokenOwnerSignature);

    bytes32 permitAcceptHash =
        keccak256(
            abi.encodePacked(
                tokenOwner,
                spender,
                amount
            )
        );

    require(
        ECDSA.recover(
            permitAcceptHash,
            spenderSignature
        ) == spender
    );

    usedHashes[permitHash] = true;

    _approve(tokenOwner, spender, amount);
}
```

---

# 🚨 The Suspicious Line

```solidity
address tokenOwner =
    ECDSA.recover(bytes32(amount), tokenOwnerSignature);
```

This is highly unusual.

Normally signature verification should recover from a **real message hash**, not from:

```solidity
bytes32(amount)
```

which is only the raw 32-byte representation of a number.

---

# 🔍 Verify Replay Checks

For `10 ether`, both replay-protection slots are unused.

## keccak256(abi.encode(amount))

```bash
cast keccak $(cast abi-encode "f(uint256)" 10000000000000000000)
```

```text
0xf32d90031fda796f2c8c61d0d96e5f36268ff2ba2d0b2382738d725572d0cf76
```

```bash
cast call $ELLIPTIC_TOKEN \
    "usedHashes(bytes32)(bool)" \
    0xf32d90031fda796f2c8c61d0d96e5f36268ff2ba2d0b2382738d725572d0cf76 \
    --rpc-url $SEPOLIA_RPC_URL
```

```text
false
```

---

## bytes32(amount)

```bash
cast abi-encode "f(uint256)" 10000000000000000000
```

```text
0x0000000000000000000000000000000000000000000000008ac7230489e80000
```

```bash
cast call $ELLIPTIC_TOKEN \
    "usedHashes(bytes32)(bool)" \
    0x0000000000000000000000000000000000000000000000008ac7230489e80000 \
    --rpc-url $SEPOLIA_RPC_URL
```

```text
false
```

So `permit()` can still be used.

---

# 🔍 How Alice Got the Tokens

The mint happened during the Ethernaut setup transaction.

By inspecting the factory:

```solidity
instance.redeemVoucher(
    INITIAL_AMOUNT,
    ALICE,
    salt,
    bobSignature,
    aliceSignature
);
```

So Alice is intentionally preloaded with `10 ETK`.

---

# 🚨 OpenZeppelin Warning

The `ECDSA.recover()` documentation explicitly says:

```solidity
IMPORTANT: `hash` must be the result of a hash operation
for the verification to be secure:
it is possible to craft signatures that recover
to arbitrary addresses for non-hashed data.
```

But Bob uses:

```solidity
ECDSA.recover(bytes32(amount), ...)
```

That is exactly the unsafe pattern warned about.

---

# 🧪 Local Proof of Unsafe Recovery

I reproduced the behavior locally in [EllipticTokenTest.t.sol](../../test/challenge-35-elliptic-token/EllipticTokenTest.t.sol):

```solidity
function test_ecrecoverPlayground() public view {
    bytes32 h = bytes32(uint256(10 ether));

    uint8 v = 27;
    bytes32 r = bytes32(uint256(1));
    bytes32 s = bytes32(uint256(2));

    address signer = ecrecover(h, v, r, s);

    console.log("signer", signer);
}
```

Output:

```text
signer 0x3705772bBDb18A2Cc7355F3bF9dD4d891A79eBA8
```

So even arbitrary `(v,r,s)` values can recover to a signer address.

---

# 🧠 Solution

The final exploit is to choose a special `amount` together with a crafted `tokenOwnerSignature` such that:

```solidity
ECDSA.recover(bytes32(amount), tokenOwnerSignature) == ALICE
```

This is possible because the contract uses `bytes32(amount)` as the message digest instead of a properly hashed message.

Since this value is fully attacker-controlled and not the result of a secure hash, it becomes possible to craft a `(amount, signature)` pair that makes `ECDSA.recover()` return an arbitrary address.

This vulnerability is a direct consequence of misusing `ECDSA.recover()` with non-hashed, attacker-controlled data — effectively allowing signature forgery.

Then:

1. `permit()` believes Alice approved the allowance
2. The attacker signs as `spender`
3. `_approve(ALICE, attacker, amount)` is executed
4. `transferFrom(ALICE, attacker, 10 ether)` drains Alice

---

# 📚 Public Full Solution

To understand how to derive the crafted `amount` and `tokenOwnerSignature`, refer to:

[https://piatoss3612.tistory.com/202](https://piatoss3612.tistory.com/202)

I used the values derived there to complete the exploit.

---

# 🧪 Solve Locally

The exploit is implemented in [EllipticTokenTest.t.sol](../../test/challenge-35-elliptic-token/EllipticTokenTest.t.sol):

Specifically in: `testSolveEllipticToken`

This test demonstrates two key properties:

### 1. Signature Forgery

```solidity
ECDSA.recover(bytes32(craftedAmount), tokenOwnerSignature) == ALICE
```

This proves the crafted pair is valid.

---

### 2. Full Exploit

```solidity
token.permit(craftedAmount, attacker, tokenOwnerSignature, spenderSignature);
```

This sets:

```solidity
allowance[ALICE][attacker] = craftedAmount;
```

Then:

```solidity
token.transferFrom(ALICE, attacker, AMOUNT);
```

drains Alice’s balance.

---

# 🚀 Solve on Sepolia

Run the exploit script [SolveEllipticToken.s.sol](../../script/challenge-35-elliptic-token/SolveEllipticToken.s.sol):

```bash
ELLIPTIC_TOKEN=$ELLIPTIC_TOKEN \
PRIVATE_KEY=$PRIVATE_KEY \
forge script script/challenge-35-elliptic-token/SolveEllipticToken.s.sol:SolveEllipticTokenScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

Example output:

```text
Player: 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
Instance: 0x551c9cD11a73Bb4b85d4381fEac66ba2fd23596B
Alice balance before: 10000000000000000000
Recovered token owner: 0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e
Alice balance after: 0
Player balance after: 10000000000000000000
```

---


