// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {
    DoubleEntryPoint,
    LegacyToken,
    CryptoVault,
    Forta,
    IERC20
} from "src/challenge-26-double-entry-point/DoubleEntryPoint.sol";
import {DetectionBot} from "src/challenge-26-double-entry-point/DetectionBot.sol";

contract DoubleEntryPointTest is Test {
    Forta forta;
    CryptoVault vault;
    LegacyToken legacy;
    DoubleEntryPoint det;

    address player = address(1);
    address recipient = address(2);

    function setUp() public {
        forta = new Forta();
        vault = new CryptoVault(recipient);
        legacy = new LegacyToken();

        det = new DoubleEntryPoint(address(legacy), address(vault), address(forta), player);

        // Link legacy → DET
        legacy.delegateToNewContract(det);

        // Set underlying token in vault
        vault.setUnderlying(address(det));

        // Mint LegacyToken to vault
        legacy.mint(address(vault), 100 ether);

        vm.label(player, "Player");
        vm.label(recipient, "Recipient");
        vm.label(address(forta), "Forta");
        vm.label(address(vault), "Vault");
        vm.label(address(legacy), "Legacy");
        vm.label(address(det), "Det");
    }

    function testSweepTokenWithLegacy() public {
        // --- BEFORE ---
        uint256 vaultLegacyBefore = legacy.balanceOf(address(vault));
        uint256 vaultDetBefore = det.balanceOf(address(vault));

        uint256 recipientLegacyBefore = legacy.balanceOf(recipient);
        uint256 recipientDetBefore = det.balanceOf(recipient);

        assertEq(vaultLegacyBefore, 100 ether);
        assertEq(vaultDetBefore, 100 ether);
        assertEq(recipientLegacyBefore, 0);
        assertEq(recipientDetBefore, 0);

        // --- ACTION ---
        vault.sweepToken(IERC20(address(legacy)));

        // --- AFTER ---
        uint256 vaultLegacyAfter = legacy.balanceOf(address(vault));
        uint256 vaultDetAfter = det.balanceOf(address(vault));

        uint256 recipientLegacyAfter = legacy.balanceOf(recipient);
        uint256 recipientDetAfter = det.balanceOf(recipient);

        assertEq(vaultLegacyAfter, 100 ether);
        assertEq(vaultDetAfter, 0);
        assertEq(recipientLegacyAfter, 0);
        assertEq(recipientDetAfter, 100 ether);
    }

    function testDetRevertsWhenSweepingDetTokens() public {
        // Deploy bot
        DetectionBot bot = new DetectionBot(address(vault), address(forta));

        // Register bot for the player
        vm.prank(player);
        forta.setDetectionBot(address(bot));

        // Sanity check: the player's bot is correctly registered
        assertEq(address(forta.usersDetectionBots(player)), address(bot));

        // Trigger the flow:
        // CryptoVault.sweepToken(legacy)
        //   -> LegacyToken.transfer(...)
        //   -> DoubleEntryPoint.delegateTransfer(...)
        //   -> Forta.notify(...)
        //   -> DetectionBot.handleTransaction(...)
        vm.expectRevert("Alert has been triggered, reverting");
        vault.sweepToken(IERC20(address(legacy)));
    }
}
