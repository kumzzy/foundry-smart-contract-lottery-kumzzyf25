// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, codeConstant} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, codeConstant {
    /*Constant Variable*/
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    Raffle public raffle;
    HelperConfig public helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callBackGasLimit;

    address public PLAYER = makeAddr("Player");

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callBackGasLimit = config.callBackGasLimit;
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier enteredRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier onlyOnDeployedContracts() {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyRunAfterPerformUpKeep() public enteredRaffle onlyOnDeployedContracts {
        // Act // Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords((0), address(raffle));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords((1), address(raffle));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords((2), address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetRaffleStateAndSendsMoneyToWinner()
        public
        enteredRaffle
        onlyOnDeployedContracts
    {
        address expectedWinner = address(1);

        // Arrange

        uint256 additionalEntrants = 4;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address numPlayer = address(uint160(i));
            hoax(numPlayer, 4 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // ACT
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = (recentWinner).balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
