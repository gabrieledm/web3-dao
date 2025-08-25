// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DeployGovTokenScript} from "./DeployGovToken.s.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployMyGovernorScript is Script {
    address private constant DEFAULT_ANVIL_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant MIN_DELAY = 600; // seconds

    function run() external returns (address, address) {
        return deployMyGovernor();
    }

    function deployMyGovernor() public returns (address, address) {
        DeployGovTokenScript deployGovTokenScript = new DeployGovTokenScript();
        address govToken = deployGovTokenScript.run();

        vm.startBroadcast();
        address[] memory proposers = new address[](1);
        proposers[0] = DEFAULT_ANVIL_ADDRESS;
        address[] memory executors = new address[](1);
        executors[0] = DEFAULT_ANVIL_ADDRESS;

        TimeLock timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        MyGovernor myGovernor = new MyGovernor(IVotes(govToken), timeLock);

        // TODO
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        // Grant Governor roles to propose a new proposal
        timeLock.grantRole(proposerRole, address(myGovernor));
        // Allow any user to execute a proposal
        timeLock.grantRole(executorRole, address(0));
        // Remove the user as admin of the TimeLock
        timeLock.revokeRole(adminRole, msg.sender);

        Box box = new Box();
        box.transferOwnership(address(timeLock));

        address timeLockAddr = address(timeLock);
        address myGovernorAddr = address(myGovernor);
        console.log("TimeLock deployed at %s", timeLockAddr);
        console.log("MyGovernor deployed at %s", myGovernorAddr);
        vm.stopBroadcast();

        return (timeLockAddr, myGovernorAddr);
    }
}
