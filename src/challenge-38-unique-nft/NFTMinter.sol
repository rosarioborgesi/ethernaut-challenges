// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC721Receiver} from "openzeppelin-contracts-v5.4.0/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "openzeppelin-contracts-v5.4.0/token/ERC721/IERC721.sol";

import {console} from "forge-std/Test.sol";

interface IUniqueNFT is IERC721 {
    function mintNFTSmartContract() external payable returns (uint256 mintedNFT);
    function mintNFTEOA() external returns (uint256 mintedNFT);
}

contract NFTMinter is IERC721Receiver {
    address public constant MY_EOA = 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0;
    IUniqueNFT public s_uniqueNFT;
    uint256 public s_entered;

    function onERC721Received(
        address,
        /* operator */
        address,
        /* from */
        uint256,
        /* tokenId */
        bytes calldata /* data */
    )
        external
        override
        returns (bytes4)
    {
        if (s_entered == 0) {
            s_entered = 1;
            s_uniqueNFT.mintNFTEOA();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUniqueNFT(address _uniqueNFT) external {
        s_uniqueNFT = IUniqueNFT(_uniqueNFT);
    }

    function resetEntered() external {
        s_entered = 0;
    }
}
