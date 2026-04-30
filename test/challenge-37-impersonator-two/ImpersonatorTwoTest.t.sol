// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {ImpersonatorTwo} from "../../src/challenge-37-impersonator-two/ImpersonatorTwo.sol";

contract ImpersonatorTwoTest is Test {
    bytes constant SWITCH_LOCK_SIG = abi.encodePacked(
        hex"e5648161e95dbf2bfc687b72b745269fa906031e2108118050aba59524a23c40", // r
        hex"70026fc30e4e02a15468de57155b080f405bd5b88af05412a9c3217e028537e3", // s
        uint8(27) // v
    );
    bytes constant SET_ADMIN_SIG = abi.encodePacked(
        hex"e5648161e95dbf2bfc687b72b745269fa906031e2108118050aba59524a23c40", // r
        hex"4c3ac03b268ae1d2aca1201e8a936adf578a8b95a49986d54de87cd0ccb68a79", // s
        uint8(27) // v
    );

    address constant OWNER = 0x03E2cf81BBE61D1fD1421aFF98e8605a5A9e953a;
    address constant ADMIN = 0xADa4aFfe581d1A31d7F75E1c5a3A98b2D4C40f68;

    address constant PLAYER = 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0;

    bytes constant NEW_SET_ADMIN_SIG =
        hex"0620893ad27949e2b457d1b5ff9e269074f4d3ba8474bb33e7458e66e7d6e598193e0e65047891e42407b4ee1a9dda9f3f43ea26c03bd6c9e030c51361537c3d1c";

    bytes constant NEW_SWITCH_LOCK_SIG =
        hex"306cff6fcc22eb595fe43f292d98021816b065ffd3f1ae379ca8e167cca9d6c40c1b5972f86b06d2d9c13b90413c805ef05003ba1ee755765656eae0d8918fa01c";

    ImpersonatorTwo public impersonator;

    function setUp() public {
        impersonator = new ImpersonatorTwo{value: 0.001 ether}();
        impersonator.transferOwnership(OWNER);
        impersonator.switchLock(SWITCH_LOCK_SIG);
        impersonator.setAdmin(SET_ADMIN_SIG, ADMIN);
    }

    function testSolveChallenge() public {
        assertEq(impersonator.nonce(), 2);

        impersonator.setAdmin(NEW_SET_ADMIN_SIG, PLAYER);
        assertEq(impersonator.admin(), PLAYER);
        assertEq(impersonator.nonce(), 3);

        impersonator.switchLock(NEW_SWITCH_LOCK_SIG);
        assertEq(impersonator.nonce(), 4);

        vm.prank(PLAYER);
        impersonator.withdraw();

        assertEq(address(impersonator).balance, 0);
        assertEq(PLAYER.balance, 0.001 ether);
    }
}
