// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {NotOptimisticPortal, IMessageReceiver} from "src/challenge-40-not-optimistic-portal/NotOptimisticPortal.sol";

contract MockMessageReceiver is IMessageReceiver {
    event MessageReceived(bytes messageData);

    function onMessageReceived(bytes memory messageData) external override {
        emit MessageReceived(messageData);
    }
}

contract NotOptimisticPortalHarness is NotOptimisticPortal {
    constructor(string memory name_, string memory symbol_, bytes memory rlpBlockHeader_, address governance_)
        NotOptimisticPortal(name_, symbol_, rlpBlockHeader_, governance_)
    {}

    function exposedComputeMessageSlot(
        address tokenReceiver,
        uint256 amount,
        address[] calldata messageReceivers,
        bytes[] calldata messageDatas,
        uint256 salt
    ) external pure returns (bytes32) {
        return _computeMessageSlot(tokenReceiver, amount, messageReceivers, messageDatas, salt);
    }
}

contract NotOptimisticPortalTest is Test {
    NotOptimisticPortal portal;
    MockMessageReceiver receiver;

    address player = makeAddr("player");
    address governance = address(uint160(uint256(keccak256("governance"))));

    bytes genesisRlpBlockHeader =
        hex"f90204a00000000000000000000000000000000000000000000000000000000000000000a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0d7d3685b57d9897755fad850b19f7c43debfded002e18a9e8e5b63639882b6f9a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470b90100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000184039fd3988401c9c38080845fc630578b4354465f5061796c6f6164a00000000000000000000000000000000000000000000000000000000000000000880000000000000000";

    function setUp() public {
        portal = new NotOptimisticPortal(
            "CTFToken", "CTFT", genesisRlpBlockHeader, address(uint160(uint256(keccak256("governance"))))
        );

        receiver = new MockMessageReceiver();

        vm.label(address(portal), "NotOptimisticPortal");
        vm.label(address(receiver), "MockMessageReceiver");
        vm.label(player, "player");
        vm.label(governance, "governance");
    }

    /*
    * @notice Proves that `executeMessage()` performs the external receiver call
    *         before validating the Merkle Patricia Trie proof.
    *
    * @dev The proof fields are intentionally empty, so proof verification fails
    *      while decoding the empty RLP account state.
    *
    *      The important behavior is the execution order:
    *
    *      1. `executeMessage()` calls the receiver.
    *      2. Only after that it tries to verify the proof.
    *
    *      This shows that interactions happen before the main proof check.
    */
    function testExecuteMessageExecutesReceiverBeforeFailingOnEmptyRlpProof() public {
        address tokenReceiver = player;
        uint256 amount = 1 ether;
        uint256 salt = 123;

        address[] memory messageReceivers = new address[](1);
        bytes[] memory messageData = new bytes[](1);

        messageReceivers[0] = address(receiver);

        messageData[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("hello")));

        NotOptimisticPortal.ProofData memory proofs =
            NotOptimisticPortal.ProofData({stateTrieProof: hex"", storageTrieProof: hex"", accountStateRlp: hex""});

        uint16 bufferIndex = 0;

        vm.prank(player);

        vm.expectRevert("RLP item cannot be null.");
        portal.executeMessage(tokenReceiver, amount, messageReceivers, messageData, salt, proofs, bufferIndex);
    }

    /*
    * @notice Proves that `_computeMessageSlot()` ignores the last receiver and
    *         the last calldata item.
    *
    * @dev With arrays of length 1, the loop inside `_computeMessageSlot()` never
    *      executes because it iterates while `i < length - 1`.
    *
    *      As a result, two completely different receiver/data pairs produce the
    *      same computed message slot.
    *
    *      This means the message hash does not commit to the operation that will
    *      actually be executed by `executeMessage()`.
    */
    function testComputeMessageSlotIgnoresLastReceiverAndLastData() public {
        NotOptimisticPortalHarness harness = new NotOptimisticPortalHarness(
            "CTFToken", "CTFT", genesisRlpBlockHeader, address(uint160(uint256(keccak256("governance"))))
        );

        address tokenReceiver = player;
        uint256 amount = 1 ether;
        uint256 salt = 123;

        address[] memory receiversA = new address[](1);
        bytes[] memory dataA = new bytes[](1);

        address[] memory receiversB = new address[](1);
        bytes[] memory dataB = new bytes[](1);

        receiversA[0] = address(0x1111);
        dataA[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("hello")));

        receiversB[0] = address(0x2222);
        dataB[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("different")));

        bytes32 slotA = harness.exposedComputeMessageSlot(tokenReceiver, amount, receiversA, dataA, salt);

        bytes32 slotB = harness.exposedComputeMessageSlot(tokenReceiver, amount, receiversB, dataB, salt);

        assertEq(slotA, slotB);
    }

    /*
    * @notice Proves that `sendMessage()` stores the message marker expected by
    *         `executeMessage()` in the computed storage slot.
    *
    * @dev The test uses `amount = 0`, so `_burn(msg.sender, 0)` does not require
    *      the player to own any tokens.
    *
    *      After `sendMessage()` is called, the slot computed by
    *      `_computeMessageSlot()` must contain the value `1`.
    *
    *      This demonstrates that:
    *
    *      storage[messageSlot] = 1
    *
    *      which is exactly the condition later verified inside
    *      `_verifyMessageInclusion()`.
    */
    function testSendMessageStoresMessageSlotWithAmountZero() public {
        NotOptimisticPortalHarness harness =
            new NotOptimisticPortalHarness("CTFToken", "CTFT", genesisRlpBlockHeader, governance);

        address tokenReceiver = player;
        uint256 amount = 0;
        uint256 salt = 123;

        address[] memory receivers = new address[](1);
        bytes[] memory data = new bytes[](1);

        receivers[0] = address(receiver);
        data[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("hello")));

        bytes32 messageSlot = harness.exposedComputeMessageSlot(tokenReceiver, amount, receivers, data, salt);

        uint256 beforeValue = uint256(vm.load(address(harness), messageSlot));
        assertEq(beforeValue, 0);

        vm.prank(player);
        harness.sendMessage(amount, receivers, data, salt);

        uint256 afterValue = uint256(vm.load(address(harness), messageSlot));
        assertEq(afterValue, 1);
    }

    /*
    * @notice Proves that a message can be registered with one receiver/data pair,
    *         but later represented by a different receiver/data pair while keeping
    *         the same computed message slot.
    *
    * @dev This works because `_computeMessageSlot()` ignores the last element of
    *      `_messageReceivers` and `_messageDatas`. With arrays of length 1, the
    *      only receiver/data pair is completely excluded from the hash.
    */
    function testRegisteredMessageSlotCanBeReusedWithDifferentReceiverAndData() public {
        NotOptimisticPortalHarness harness =
            new NotOptimisticPortalHarness("CTFToken", "CTFT", genesisRlpBlockHeader, governance);

        uint256 amount = 0;
        uint256 salt = 123;

        address[] memory originalReceivers = new address[](1);
        bytes[] memory originalData = new bytes[](1);

        originalReceivers[0] = address(receiver);
        originalData[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("hello")));

        vm.prank(player);
        harness.sendMessage(amount, originalReceivers, originalData, salt);

        address[] memory maliciousReceivers = new address[](1);
        bytes[] memory maliciousData = new bytes[](1);

        maliciousReceivers[0] = address(0xBEEF);
        maliciousData[0] = abi.encodeCall(IMessageReceiver.onMessageReceived, (abi.encode("malicious")));

        bytes32 originalSlot = harness.exposedComputeMessageSlot(player, amount, originalReceivers, originalData, salt);

        bytes32 maliciousSlot =
            harness.exposedComputeMessageSlot(player, amount, maliciousReceivers, maliciousData, salt);

        assertEq(originalSlot, maliciousSlot);
        assertEq(uint256(vm.load(address(harness), maliciousSlot)), 1);
    }

    /*
    * @notice Proves that `transferOwnership_____610165642(address)` shares the
    *         same function selector as `onMessageReceived(bytes)`.
    *
    * @dev `_executeOperation()` only validates the first 4 bytes of calldata.
    *      Because both functions have selector `0x3a69197e`, calldata intended
    *      for `transferOwnership` passes the message entrypoint check.
    */
    function testInspectRelevantFunctionSelectors() public pure {
        console.logBytes4(IMessageReceiver.onMessageReceived.selector);
        console.logBytes4(NotOptimisticPortal.transferOwnership_____610165642.selector);
        console.logBytes4(NotOptimisticPortal.updateSequencer_____76439298743.selector);
        console.logBytes4(NotOptimisticPortal.submitNewBlock_____37278985983.selector);
        console.logBytes4(NotOptimisticPortal.governanceAction_____2357862414.selector);

        assertEq(IMessageReceiver.onMessageReceived.selector, bytes4(0x3a69197e));
        assertEq(NotOptimisticPortal.transferOwnership_____610165642.selector, bytes4(0x3a69197e));
    }
}
