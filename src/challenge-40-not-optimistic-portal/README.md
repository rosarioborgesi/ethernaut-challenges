# Ethernaut Challenge 40 — NotOptimisticPortal

This portal relies on a complex chain of cryptographic proofs to verify cross-chain messages. It claims to be secure against invalid state transitions, but the gap between verification and execution might be wider than it looks.

Can you manage to mint some tokens for your wallet?

Things that might help:

* Understanding Function Selectors.
* The Checks-Effects-Interactions (CEI) pattern.
* Merkle Patricia Tries and RLP encoding.

Tips:

* Sometimes the data you verify isn't exactly the same data you execute.
* If a hash cycle seems impossible to solve, look for a way to break the loop.

Instance address:

```text
0xaBB92E563e47D4AE11f15B1Af3f022ee86A69F7d
```

---

# 🎯 Goal

The challenge is solved when the portal mints tokens through the `executeMessage()` function.

---

# 🧠 Initial analysis

The only function capable of minting tokens is:

```solidity
executeMessage(...)
```

The flow of the function is roughly:

1. compute a `withdrawalHash`
2. execute all message operations
3. verify the Merkle Patricia Trie proof
4. mark the message as executed
5. mint tokens

At first glance this looks like a standard bridge message execution flow similar to optimistic rollup bridges.

However, after deeper inspection, several inconsistencies appear between:

* the data that gets verified
* the data that gets executed

---

# 🧪 Local testing & research notes

The exploratory Foundry tests used for this challenge are available here:

[NotOptimisticPortalTest.t.sol](../../test/challenge-40-not-optimistic-portal/NotOptimisticPortalTest.t.sol)

These tests document the main findings so far:

- `executeMessage()` executes external calls before proof verification
- `_computeMessageSlot()` ignores the last receiver/data pair
- `sendMessage()` stores the marker later expected by `_verifyMessageInclusion()`
- the same message slot can be reused with different calldata
- `transferOwnership_____610165642(address)` collides with `onMessageReceived(bytes)`


---

# 🔍 executeMessage executes calls before proof verification

One of the first things I tested was the execution order inside `executeMessage()`.

The contract performs external calls before validating the Merkle Patricia Trie proof.

The test:

```solidity
testExecuteMessageExecutesReceiverBeforeFailingOnEmptyRlpProof
```

demonstrates this behavior.

Using an intentionally invalid proof:

```solidity
ProofData({
    stateTrieProof: hex"",
    storageTrieProof: hex"",
    accountStateRlp: hex""
})
```

the execution flow becomes:

```text
executeMessage()
  -> MockMessageReceiver::onMessageReceived(...)
  -> emit MessageReceived(...)
  -> revert during proof verification
```

This means the portal violates the CEI (Checks-Effects-Interactions) pattern:

```text
Interactions happen before the main proof validation.
```

Even though the entire transaction later reverts, this finding is extremely important because it means untrusted calldata is executed before the bridge confirms the message is valid.

---

# 🔍 `_computeMessageSlot()` ignores the last calldata item

The next step was analyzing how the bridge computes the storage slot later verified by `_verifyMessageInclusion()`.

The vulnerable code is:

```solidity
for(uint i; i < _messageReceivers.length - 1; i++){
    messageReceiversAccumulatedHash =
        keccak256(abi.encode(messageReceiversAccumulatedHash, _messageReceivers[i]));

    messageDatasAccumulatedHash =
        keccak256(abi.encode(messageDatasAccumulatedHash, _messageDatas[i]));
}
```

Notice the loop condition:

```solidity
i < length - 1
```

When arrays contain a single element:

```solidity
address[] memory receivers = new address[](1);
bytes[] memory data = new bytes[](1);
```

the loop becomes:

```solidity
for (i = 0; i < 0; i++)
```

meaning it never executes.

The test:

```solidity
testComputeMessageSlotIgnoresLastReceiverAndLastData
```

proves that completely different receiver/data pairs produce the exact same `withdrawalHash`.

So the computed slot only depends on:

```solidity
keccak256(abi.encode(
    tokenReceiver,
    amount,
    bytes32(0),
    bytes32(0),
    salt
));
```

while completely ignoring:

```solidity
receivers[0]
data[0]
```

This is one of the most important findings in the challenge because it means:

```text
executeMessage() executes calldata
that is NOT committed inside the verified message hash
```

for single-element arrays.

---

# 🔍 Understanding `sendMessage()`

The next thing I wanted to understand was how messages are supposed to be registered.

The test:

```solidity
testSendMessageStoresMessageSlotWithAmountZero
```

proves that:

```solidity
sendMessage()
```

stores:

```text
storage[messageSlot] = 1
```

where:

```solidity
messageSlot = _computeMessageSlot(...)
```

This is important because `_verifyMessageInclusion()` later verifies exactly this condition:

```text
storage[messageSlot] == 1
```

So conceptually the intended bridge flow is:

```text
sendMessage()
    writes storage[messageSlot] = 1

executeMessage()
    proves storage[messageSlot] == 1
```

The test uses:

```solidity
amount = 0
```

so `_burn(msg.sender, 0)` succeeds without needing any token balance.

However, an important nuance exists:

`_verifyMessageInclusion()` is not checking the portal’s current storage directly.

Instead, it verifies a Merkle Patricia Trie proof against:

```solidity
storageRoot
```

extracted from an L2 account state.

So even if we can locally create:

```text
storage[messageSlot] = 1
```

we still need a valid trie proof matching an accepted L2 state root.

---

# 🔍 Reusing the same message slot with different calldata

The next test:

```solidity
testRegisteredMessageSlotCanBeReusedWithDifferentReceiverAndData
```

proves that a message can be registered with one receiver/data pair and later represented with completely different calldata while still producing the exact same `withdrawalHash`.

This works because:

```solidity
_computeMessageSlot()
```

ignores the last element of both arrays.

So:

```text
harmless receiver/data
```

and:

```text
malicious receiver/data
```

produce the same computed slot.

This confirms the core bridge inconsistency:

```text
the data being verified is not necessarily the same data being executed
```

which directly matches the challenge hint.

---

# 🔍 Function selector collision

The next thing I inspected was the selector validation inside `_executeOperation()`:

```solidity
require(
    bytes4(callData[0:4]) == bytes4(0x3a69197e),
    "Invalid message entrypoint"
);
```

The selector:

```text
0x3a69197e
```

is expected to correspond to:

```solidity
onMessageReceived(bytes)
```

However, the test:

```solidity
testInspectRelevantFunctionSelectors
```

proves that another function intentionally shares the exact same selector:

```solidity
transferOwnership_____610165642(address)
```

Both functions resolve to:

```text
0x3a69197e
```

This means calldata intended for:

```solidity
transferOwnership(address)
```

passes the message entrypoint validation.

This appears to be an intentionally crafted selector collision vulnerability.

---

# 🧠 Current understanding of the exploit path

At this point, the likely intended exploit direction appears to be:

1. create or reuse a valid `messageSlot`
2. exploit the ignored last calldata item
3. execute calldata different from the one committed in the verified hash
4. abuse the selector collision to invoke privileged functionality
5. somehow pass `_verifyMessageInclusion()`
6. mint tokens

The hardest remaining part is constructing a valid Merkle Patricia Trie proof matching an accepted `l2StateRoot`.

---

# ⚠️ Current status

At the time of writing this README, I have not fully solved the challenge yet.

I could not find a confirmed public solution, and most public discussions stop at the same point:

* understanding the selector collision
* understanding the ignored calldata bug
* understanding the bridge inconsistency
* struggling with the trie proof construction

This challenge requires a deep understanding of:

* Merkle Patricia Tries
* RLP encoding
* Ethereum state proofs
* storage trie proofs
* bridge architectures
* selector collisions

and likely still requires substantial additional research and experimentation.

---

# 🔮 Possible directions for completing the exploit

Some possible remaining exploit directions could include:

* forging or injecting a custom L2 state root
* abusing ownership transfer to modify trusted bridge state
* becoming the sequencer and submitting a malicious block
* constructing a custom storage trie containing the desired message slot
* exploiting a recursive dependency in the proof generation process
* abusing the selector collision to gain privileged execution before proof validation

At the moment, the challenge remains unfinished and requires more investigation.
