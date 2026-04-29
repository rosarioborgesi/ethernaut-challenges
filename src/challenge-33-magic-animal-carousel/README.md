# Ethernaut Challenge 33 — Magic Animal Carousel

Welcome, dear Anon, to the Magic Carousel, where creatures spin and twirl in a boundless spell. In this magical, infinite digital wheel, they loop and whirl with enchanting zeal.

Add a creature to join the fun, but heed the rule, or the game’s undone. If an animal joins the ride, take care when you check again, that same animal must be there!

Can you break the magic rule of the carousel?

Instance address:

```bash
CAROUSEL=0x3a822E5557C5a36FFEC2e6d3D259864d03B74aF5
````

---

## 🎯 Goal

The challenge revolves around a packed storage structure that stores three pieces of information inside a single `uint256`:

* the animal name
* the id of the next crate
* the owner

The intended invariant is that once an animal is placed into the carousel, that same animal should still be there when the carousel comes back to that crate.

This invariant can be broken because the contract does **not encode and store animal names consistently** across its write functions.

---

## 🔍 Storage layout

The contract defines these masks:

```solidity
uint16 public constant MAX_CAPACITY = type(uint16).max;
uint256 constant ANIMAL_MASK = uint256(type(uint80).max) << 160 + 16;
uint256 constant NEXT_ID_MASK = uint256(type(uint16).max) << 160;
uint256 constant OWNER_MASK = uint256(type(uint160).max);
```

So each crate is packed as:

```text
| animal (80 bits) | nextId (16 bits) | owner (160 bits) |
|    10 bytes      |      2 bytes     |      20 bytes    |
```

---

## 🧠 Constructor initialization

```solidity
constructor() {
    carousel[0] ^= 1 << 160;
}
```

This initializes:

* `nextId = 1` for crate `0`
* `currentCrateId = 0`

So the first spin goes to crate `1`.

---

## 🔎 Inconsistent encoding

### `encodeAnimalName`

```solidity
function encodeAnimalName(string calldata animalName) public pure returns (uint256) {
    require(bytes(animalName).length <= 12, AnimalNameTooLong());
    return uint256(bytes32(abi.encodePacked(animalName)) >> 160);
}
```

Supports up to **12 bytes**.

---

### `setAnimalAndSpin`

```solidity
uint256 encodedAnimal = encodeAnimalName(animal) >> 16;
```

Removes **2 bytes**, so only **10 bytes (80 bits)** are stored.

---

### `changeAnimal`

```solidity
carousel[crateId] = (encodedAnimal << 160) | ...
```

Stores the **full 12 bytes**, starting at bit `160`.

---

## 🚨 The bug

This creates a mismatch:

* `setAnimalAndSpin()` → stores **10 bytes**
* `changeAnimal()` → writes **12 bytes**

The extra 2 bytes overlap with the `nextId` field.

---

## 🧪 Local proof

Using:

```solidity
carousel.setAnimalAndSpin("abcdefghij");
carousel.changeAnimal("abcdefghijkl", 1);
```

We get:

```text
animal stays: "abcdefghij"
nextId changes: 2 → 27502
```

So we can:

```text
change nextId without changing the visible animal
```

---

## 🧪 Solving the challenge

The validator does:

```solidity
instance.setAnimalAndSpin("Goat");

uint256 currentCrateId = instance.currentCrateId();
uint256 animalInBox = instance.carousel(currentCrateId) >> 176;

return animalInBox != goatEnc;
```

So the goal is:

```text
After inserting "Goat", the stored animal must NOT be "Goat"
```

---

## 🔑 Key idea

Instead of setting `nextId` to a random value, we set it to:

```text
0xffff = 65535
```

Then:

```text
(65535 + 1) % 65535 = 1
```

So the carousel wraps back to crate `1`.

---

## 💥 Exploit

The test file [`MagicAnimalCarouselTest.t.sol`](../../test/challenge-33-magic-animal-carousel/MagicAnimalCarouselTest.t.sol) contains the test `testExploitMagicAnimalCarousel` that proves how to solve the challenge.


---

## 🔍 What happens

1. `changeAnimal()` overwrites `nextId` → `65535`
2. Next spin goes to crate `65535`
3. That crate stores `nextId = 1`
4. The validator calls `setAnimalAndSpin("Goat")`
5. The carousel goes back to crate `1`
6. Crate `1` already contains corrupted data
7. The stored animal is **not equal to "Goat"**

---

## 🚀 Sepolia execution
The script [AttackMagicAnimalCarousel.s.sol](../../script/challenge-33-magic-animal-carousel/AttackMagicAnimalCarousel.s.sol) executes the same steps as the test in Sepolia. 

```bash
CAROUSEL=$CAROUSEL \
forge script script/challenge-33-magic-animal-carousel/AttackMagicAnimalCarousel.s.sol:AttackMagicAnimalCarouselScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast
```

Then submit the instance.

---

## ✅ Result

The invariant is broken:

```text
setAnimalAndSpin("Goat") does NOT result in "Goat"
```

Challenge solved.


