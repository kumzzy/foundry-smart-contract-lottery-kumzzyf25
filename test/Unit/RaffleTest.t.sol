// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    modifier EnteringRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier enteredRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipfork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

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

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWithoutEnoughEntranceFee() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordPlayerWhenTheyEnterRaffle() public EnteringRaffle {
        address PlayerRecord = raffle.getPlayer(0);
        assertEq(PlayerRecord, PLAYER);
    }

    function testEmitEventsOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerCantJoinRaffleWhenRaffleIsCalculating() public EnteringRaffle {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep(""); // weve added consumer

        // Act /assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleStateNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpKeepReturnFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act // Assert
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnFalseIfItHasNoPlayer() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act // Assert
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnFalseIfRaffleStateIsntOpen() public enteredRaffle {
        raffle.performUpKeep("");
        //Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        //  Assert.
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act // Assert
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnTrueIfAllParameterAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act // Assert
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        assert(upKeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                              PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public enteredRaffle {
        // ACT // ASSERT

        raffle.performUpKeep("");
    }

    function testPerformUpKeepRevertIfCheckUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upKeepNeededNotAvailable.selector, currentBalance, numPlayers, raffleState
            )
        );
        raffle.performUpKeep("");
    }

    function testPerformUpKeepChangeRaffleStateToCalculating() public enteredRaffle {
        // Act
        raffle.performUpKeep("");

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public enteredRaffle {
        // Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /*//////////////////////////////////////////////////////////////
                              FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyRunAfterPerformUpKeep(uint256 randomRequestId)
        public
        enteredRaffle
        skipfork
    {
        // Act // Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetRaffleStateAndSendsMoneyToWinner() public enteredRaffle skipfork {
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
