// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "../src/Fulfill.sol";

contract DeployFulfillScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address succinct = vm.envAddress("SUCCINCT_ADDRESS");
        TelepathyOracleFulfill fulfill = new TelepathyOracleFulfill(succinct);
    }
}
