// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GovToken} from "../src/GovToken.sol";

contract DeployGovTokenScript is Script {
    function run() external returns (address) {
        return deployGovToken();
    }

    function deployGovToken() public returns (address) {
        vm.startBroadcast();
        GovToken govToken = new GovToken();
        govToken.delegate(msg.sender);
        address govTokenAddr = address(govToken);
        console.log("GovToken deployed at %s", govTokenAddr);
        vm.stopBroadcast();

        return govTokenAddr;
    }
}
