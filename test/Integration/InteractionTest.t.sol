// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, codeConstant} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test, codeConstant {
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    Raffle public raffle;
    HelperConfig public helperConfig;
    LinkToken public linkToken;

    CreateSubscription public createSubscription;
    FundSubscription public fundSubscription;
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
        linkToken = new LinkToken();
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callBackGasLimit = config.callBackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier enteredRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testCreateSubscriptionIncrementsSubscriptionCount() public {
        // Since getTotalSubscriptions() does not exist, we can check subscriptionId increment instead
        (uint256 newSubId, ) = createSubscription.createSubscription(
            address(vrfCoordinator),
            address(raffle)
        );
        assertGt(newSubId, 0);
        subscriptionId = uint64(newSubId);
    }

    function testFundSubscriptionIncreasesBalance() public {
        // Step 1: Set up and get config once
        HelperConfig localHelperConfig = new HelperConfig();
        address localVrfCoordinator = localHelperConfig
            .getConfig()
            .vrfCoordinator;
        address link = localHelperConfig.getConfig().link;
        address account = localHelperConfig.getConfig().account;

        // Step 2: Create subscription
        CreateSubscription createsubscription = new CreateSubscription();
        (uint256 subId, ) = createsubscription.createSubscription(
            localVrfCoordinator,
            account
        );

        // Step 3: Check balance before funding
        (uint96 beforeBalance, , , , ) = VRFCoordinatorV2_5Mock(
            localVrfCoordinator
        ).getSubscription(subId);

        // Step 4: Mint & Approve LINK
        LinkToken(link).mint(address(raffle), 4 ether);
        LinkToken(link).approve(address(localVrfCoordinator), 4 ether);

        // Step 5: Fund subscription
        FundSubscription fund = new FundSubscription();
        fund.fundSubscription(localVrfCoordinator, subId, link, account);

        // Step 6: Check balance after funding
        (uint96 afterBalance, , , , ) = VRFCoordinatorV2_5Mock(
            localVrfCoordinator
        ).getSubscription(subId);
        console2.log("Balance before funding:", beforeBalance);
        console2.log("Balance after funding:", afterBalance);
        // Step 7: Assertion
        assertGt(afterBalance, beforeBalance);
    }
}
