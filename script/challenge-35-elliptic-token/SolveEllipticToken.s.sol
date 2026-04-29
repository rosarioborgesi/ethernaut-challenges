// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ECDSA} from "openzeppelin-contracts-08/utils/cryptography/ECDSA.sol";
import {EllipticToken} from "src/challenge-35-elliptic-token/EllipticToken.sol";

contract SolveEllipticTokenScript is Script {
    address constant ALICE = 0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e;

    function run() external {
        uint256 playerPrivateKey = vm.envUint("PRIVATE_KEY");
        address player = vm.addr(playerPrivateKey);

        address instance = vm.envAddress("ELLIPTIC_TOKEN");

        EllipticToken token = EllipticToken(instance);

        uint256 aliceBalance = token.balanceOf(ALICE);

        console.log("Player:", player);
        console.log("Instance:", instance);
        console.log("Alice balance before:", aliceBalance);

        uint256 craftedAmount = uint256(0xebf90284f84cb6e234a8ecf9393afda9c0ede46f4d6df12bd11a4757c42903c0);

        bytes memory tokenOwnerSignature =
            hex"0ab5b8262a97582b1971d68211e37be02ac5d16339cb0278edffc0a465d64aac7b06ed5cd7bc5798089feda2fac7b577ef49e1f2f84a6d2392ff26078f2192a01c";

        address recovered = ECDSA.recover(bytes32(craftedAmount), tokenOwnerSignature);

        console.log("Recovered token owner:", recovered);

        require(recovered == ALICE, "crafted signature does not recover Alice");

        bytes32 permitAcceptHash = keccak256(abi.encodePacked(ALICE, player, craftedAmount));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPrivateKey, permitAcceptHash);

        bytes memory spenderSignature = abi.encodePacked(r, s, v);

        vm.startBroadcast(playerPrivateKey);

        token.permit(craftedAmount, player, tokenOwnerSignature, spenderSignature);

        token.transferFrom(ALICE, player, aliceBalance);

        vm.stopBroadcast();

        console.log("Alice balance after:", token.balanceOf(ALICE));
        console.log("Player balance after:", token.balanceOf(player));
    }
}
