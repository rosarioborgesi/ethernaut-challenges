# Ethernaut Challenge 26 — Double Entry Point

This challenge demonstrates how a token migration pattern can introduce a dangerous abstraction mismatch.

A vault protects an underlying token (`DET`) by forbidding direct sweeps of that token. However, the vault also holds a legacy token (`LGT`) whose `transfer()` function does not necessarily move `LGT` balances. Instead, it can delegate the transfer to another contract.

The goal is to register a Forta detection bot that identifies the dangerous delegated transfer and blocks the vault from being drained.

Instance address:

```text
0x2f83dCa66ffDbF6b8615FC87BdE31797e2Dd3d39
````

---

## 🎯 Goal

Protect the `CryptoVault` from losing its `DET` tokens by deploying and registering a Forta detection bot.

---

## 🧠 Thought process

At first glance, the vault looks safe:

```solidity
function sweepToken(IERC20 token) public {
    require(token != underlying, "Can't transfer underlying token");
    token.transfer(sweptTokensRecipient, token.balanceOf(address(this)));
}
```

The intended protection is simple:

* any token can be swept
* except the `underlying` token

So the vault assumes:

> if `token != underlying`, then sweeping is safe

That assumption is false in this system.

The key is that `LegacyToken.transfer()` is not a normal ERC20 transfer once delegation is enabled.

```solidity
function transfer(address to, uint256 value) public override returns (bool) {
    if (address(delegate) == address(0)) {
        return super.transfer(to, value);
    } else {
        return delegate.delegateTransfer(to, value, msg.sender);
    }
}
```

So when the vault tries to sweep `LGT`, it does **not** necessarily move `LGT` balances.

Instead, execution continues here:

```solidity
function delegateTransfer(address to, uint256 value, address origSender)
    public
    override
    onlyDelegateFrom
    fortaNotify
    returns (bool)
{
    _transfer(origSender, to, value);
    return true;
}
```

This is the critical observation:

* `LegacyToken.transfer()` forwards to `DoubleEntryPoint.delegateTransfer()`
* `delegateTransfer()` performs `_transfer(origSender, to, value)`
* `_transfer()` belongs to the `DET` token contract

So the actual token whose balances move is **DET**, not **LGT**.

That means the vault can be tricked into thinking it is sweeping a harmless token while it is actually transferring out the protected underlying token.

---

## 🔍 Vulnerability summary

The dangerous flow is:

```text
CryptoVault.sweepToken(LegacyToken)
        ↓
LegacyToken.transfer(...)
        ↓
DoubleEntryPoint.delegateTransfer(...)
        ↓
DoubleEntryPoint._transfer(...)
```

The vault checks only this:

```solidity
require(token != underlying)
```

But that is not enough, because passing `LegacyToken` can still cause `DET` to be transferred.

So the bug is:

* the vault protects the token address passed into `sweepToken()`
* but it does not protect against another token whose `transfer()` indirectly moves `DET`

---

## 🧪 Step 1 — Prove the bug locally with a test

To verify the behavior, I wrote the test [DoubleEntryPointTest.t.sol](../../test/challenge-26-double-entry-point/DoubleEntryPointTest.t.sol)

This test sets up:

* `Forta`
* `CryptoVault`
* `LegacyToken`
* `DoubleEntryPoint`

and then calls:

```solidity
vault.sweepToken(IERC20(address(legacy)));
```

### Expected result

Before the call:

* vault has `100 LGT`
* vault has `100 DET`
* recipient has `0 LGT`
* recipient has `0 DET`

After the call:

* vault still has `100 LGT`
* vault has `0 DET`
* recipient still has `0 LGT`
* recipient has `100 DET`

That proves that sweeping `LegacyToken` actually transfers out `DET`.

---

## 🧪 Step 2 — Inspect the calldata seen by Forta

`DoubleEntryPoint` uses this modifier:

```solidity
modifier fortaNotify() {
    address detectionBot = address(forta.usersDetectionBots(player));

    uint256 previousValue = forta.botRaisedAlerts(detectionBot);

    forta.notify(player, msg.data);

    _;

    if (forta.botRaisedAlerts(detectionBot) > previousValue) {
        revert("Alert has been triggered, reverting");
    }
}
```

So the detection bot receives the calldata of:

```solidity
delegateTransfer(address to, uint256 value, address origSender)
```

The observed calldata was:

```bash
MSG_DATA=0x9cd1a12100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000056bc75e2d631000000000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b
```

Decode it with:

```bash
cast 4byte-calldata $MSG_DATA
```

Result:

```text
1) "delegateTransfer(address,uint256,address)"
0x0000000000000000000000000000000000000002       --> recipient
100000000000000000000 [1e20]
0x2e234DAe75C793f67A35089C9d99245E1C58470b       --> vault
```

This means:

* `to` is the recipient
* `value` is `100 ether`
* `origSender` is the vault

And since `delegateTransfer()` does:

```solidity
_transfer(origSender, to, value);
```

this means the contract is trying to transfer **DET from the vault to the recipient**.

That is exactly the dangerous pattern.

---

## 🛡️ Step 3 — Detection strategy

The bot does not need to understand `sweepToken()` directly.

It only needs to detect the delegated transfer that would move `DET` out of the vault.

Since `origSender` is the account losing `DET`, the detection rule is:

* if `origSender == vault`
* raise an alert

That is enough to make `fortaNotify` revert the whole transaction.

---

## 🧪 Step 4 — Detection bot

To solve the challenge I implemented: [DetectionBot.sol](DetectionBot.sol) 

This bot decodes the calldata of `delegateTransfer()` and raises an alert whenever the vault is the source of the `DET` transfer.

---

## ✅ Step 5 — Prove the protection locally

I then wrote a second test:

```text
testDetRevertsWhenSweepingDetTokens
```

This test:

1. deploys the detection bot
2. registers it in Forta for the player
3. calls `vault.sweepToken(legacy)`
4. expects the transaction to revert

Core assertion:

```solidity
vm.expectRevert("Alert has been triggered, reverting");
vault.sweepToken(IERC20(address(legacy)));
```

This proves the bot correctly detects the vault-draining flow and prevents the transfer.

---

## 🚀 Step 6 — Reproduce the solution on Sepolia

The instance address is the `DoubleEntryPoint` contract.

```bash
DET=0x2f83dCa66ffDbF6b8615FC87BdE31797e2Dd3d39

VAULT=$(cast call $DET "cryptoVault()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')
FORTA=$(cast call $DET "forta()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')
PLAYER=$(cast call $DET "player()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')
LEGACY=$(cast call $DET "delegatedFrom()(address)" --rpc-url $SEPOLIA_RPC_URL | tr -d '\n')

echo "DET:    $DET"
echo "VAULT:  $VAULT"
echo "FORTA:  $FORTA"
echo "PLAYER: $PLAYER"
echo "LEGACY: $LEGACY"
```

Output:

```text
DET:    0x2f83dCa66ffDbF6b8615FC87BdE31797e2Dd3d39
VAULT:  0x3831569EEa944212951e2D0D1662C9689133715D
FORTA:  0x69Ba8FB26AE08D1833DbeA04260AB0DBd03234C9
PLAYER: 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
LEGACY: 0x584816DbE961d5Ab0b3fd9805b034985369753CD
```

Verify that the underlying token is `DET`:

```bash
cast call $VAULT "underlying()(address)" --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0x2f83dCa66ffDbF6b8615FC87BdE31797e2Dd3d39
```

Check balances:

```bash
cast call $DET "balanceOf(address)(uint256)" $VAULT --rpc-url $SEPOLIA_RPC_URL
cast call $LEGACY "balanceOf(address)(uint256)" $VAULT --rpc-url $SEPOLIA_RPC_URL
```

Both return:

```text
100000000000000000000
```

So the vault holds `100 DET` and `100 LGT`.

---

## 📦 Step 7 — Deploy the bot on Sepolia

```bash
forge create src/challenge-26-double-entry-point/DetectionBot.sol:DetectionBot \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut \
  --broadcast \
  --constructor-args $VAULT $FORTA
```

Deployed bot:

```text
0xDe50fD07303D64291119cf791e008c8ed1B5423C
```

Save it:

```bash
BOT=0xDe50fD07303D64291119cf791e008c8ed1B5423C
```

---

## 🔗 Step 8 — Register the bot in Forta

```bash
cast send $FORTA \
  "setDetectionBot(address)" $BOT \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

Verify registration:

```bash
MY_ADDRESS=0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
cast call $FORTA "usersDetectionBots(address)(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

Result:

```text
0xDe50fD07303D64291119cf791e008c8ed1B5423C
```

So the bot is correctly registered.

---

## ⚠️ Step 9 — Sanity check

Attempting the dangerous call:

```bash
cast send $VAULT \
  "sweepToken(address)" $LEGACY \
  --rpc-url $SEPOLIA_RPC_URL \
  --account ethernaut
```

The command failed during gas estimation with:

```text
Error: Failed to estimate gas: server returned an error response: error code -32003: insufficient funds for gas * price + value
```

So this output does **not** prove the alert was triggered yet. It only proves the account did not have enough Sepolia ETH to send the transaction.

To complete the on-chain verification, the sender wallet needs more Sepolia ETH, then the same command can be retried. At that point, the expected behavior is a revert caused by the Forta alert.

---


