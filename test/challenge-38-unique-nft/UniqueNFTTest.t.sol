// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniqueNFT} from "../../src/challenge-38-unique-nft/UniqueNFT.sol";
import {NFTMinter} from "../../src/challenge-38-unique-nft/NFTMinter.sol";

contract UniqueNFTTest is Test {
    UniqueNFT uniqueNFT;
    NFTMinter nftMinter;

    Account public playerAccount;
    address public player;

    function setUp() public {
        uniqueNFT = new UniqueNFT();
        nftMinter = new NFTMinter();

        playerAccount = makeAccount("player");
        player = playerAccount.addr;
    }

    function testSolveChallenge() public {
        vm.signAndAttachDelegation(address(nftMinter), playerAccount.key);

        vm.startPrank(player, player);

        NFTMinter(player).setUniqueNFT(address(uniqueNFT));

        uniqueNFT.mintNFTEOA();

        vm.stopPrank();

        assertEq(uniqueNFT.balanceOf(player), 2);
    }
}
