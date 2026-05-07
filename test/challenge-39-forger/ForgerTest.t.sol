// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Forger} from "../../src/challenge-39-forger/Forger.sol";
import {ECDSA} from "openzeppelin-contracts-v4.6.0/utils/cryptography/ECDSA.sol";

contract ForgerTest is Test {
    address constant RECEIVER = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
    uint256 constant AMOUNT = 100 ether;
    bytes32 constant SALT = 0x044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d;
    uint256 constant DEADLINE = type(uint256).max; // 115792089237316195423570985008687907853269984665640564039457584007913129639935
    bytes constant ORIGINAL_SIGNATURE =
        hex"f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809402f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb1c";

    Forger public forger;

    function setUp() public {
        forger = new Forger();
    }

    function testSolveChallenge() public {
        bytes memory sig64 =
            hex"f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809c02f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb";

        forger.createNewTokensFromOwnerSignature(ORIGINAL_SIGNATURE, RECEIVER, AMOUNT, SALT, DEADLINE);
        forger.createNewTokensFromOwnerSignature(sig64, RECEIVER, AMOUNT, SALT, DEADLINE);

        assertGt(forger.totalSupply(), 100 ether);
    }
}
