// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

contract MyGovernorTest is Test {
    MyGovernor private governor;
    Box private box;
    TimeLock private timeLock;
    GovToken private govToken;

    uint256 private constant INITIAL_SUPPLY = 100 ether;
    uint256 private constant MIN_DELAY_IN_SECONDS = 3600; // seconds;
    uint256 private constant VOTING_DELAY_AS_BLOCKS = 1;
    uint256 private constant VOTING_PERIOD = 50400;

    address private USER = makeAddr("USER");

    address[] private proposers;
    address[] private executors;

    uint256[] private values;
    bytes[] private calldatas;
    address[] private targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY_IN_SECONDS, proposers, executors);
        governor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        // Grant Governor roles to propose a new proposal
        timeLock.grantRole(proposerRole, address(governor));
        // Allow any user to execute a proposal
        timeLock.grantRole(executorRole, address(0));
        // Remove the USER as admin of the TimeLock
        timeLock.revokeRole(adminRole, USER);

        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));

        // Now a 2-way relationship is set
        // - The Governor (DAO) owns the TimeLock
        // - The TimeLock owns the Governor (DAO)
    }

    function test_canUpdateBoxWithoutGovernance() public{
        bytes memory revertMessage = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER);
        vm.expectRevert(revertMessage);
        vm.prank(USER);
        box.store(1);
    }

    function test_governanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store new value in Box";
        bytes memory encodeFunctionCall = abi.encodeWithSelector(Box.store.selector, valueToStore);

        values.push(0);
        calldatas.push(encodeFunctionCall);
        targets.push(address(box));

        // 1. Propose the change to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // 2. View the state of the new proposal
        // Should return 0 = ProposalState.Pending
        uint256 proposalState = uint256(governor.state(proposalId));
        console.log("Proposal State:", proposalState);
        assertEq(proposalState, uint256(IGovernor.ProposalState.Pending));

        vm.warp(block.timestamp + VOTING_DELAY_AS_BLOCKS + 1);
        vm.roll(block.number + VOTING_DELAY_AS_BLOCKS + 1);

        // Should return 1 = ProposalState.Active
        proposalState = uint256(governor.state(proposalId));
        console.log("Proposal State:", uint256(governor.state(proposalId)));
        assertEq(proposalState, uint256(IGovernor.ProposalState.Active));

        // 3. Vote
        string memory reason = "Blue frog is cool";
        uint8 support = uint8(GovernorCountingSimple.VoteType.For);

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, support, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 4. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY_IN_SECONDS + 1);
        vm.roll(block.number + MIN_DELAY_IN_SECONDS + 1);

        proposalState = uint256(governor.state(proposalId));
        console.log("Proposal State:", uint256(governor.state(proposalId)));
        assertEq(proposalState, uint256(IGovernor.ProposalState.Queued));

        // 5. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        proposalState = uint256(governor.state(proposalId));
        console.log("Proposal State:", uint256(governor.state(proposalId)));
        assertEq(proposalState, uint256(IGovernor.ProposalState.Executed));

        assert(box.getNumber() == valueToStore);
        console.log("Box value:", box.getNumber());
    }
}
