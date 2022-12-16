// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "../src/Request.sol";

contract DeployRequestScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address fulfill = vm.envAddress("FULFILL_ADDRESS");
        address lightClient = vm.envAddress("LIGHT_CLIENT_ADDRESS");
        TelepathyOracleRequest request = new TelepathyOracleRequest(
            fulfill,
            lightClient
        );
    }
}
