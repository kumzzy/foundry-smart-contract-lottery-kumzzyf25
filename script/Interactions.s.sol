// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, codeConstant} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, codeConstant {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console2.log("Creating Subscription on ChainId", block.chainid);
        vm.startBroadcast(account);

        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console2.log("This is the subscriptionId", subId);
        console2.log(
            "please update the subscriptionId in your HelperConfig.s.sol file"
        );
        return (subId, vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, codeConstant {
    uint256 public constant FUND_AMOUNT = 4 ether; // 4 link

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, link, account);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address link,
        address account
    ) public {
        console2.log("funding Subscription", subscriptionId);
        console2.log("using vrfCoordinator", vrfCoordinator);
        console2.log("on chainId", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script, codeConstant {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(
            mostRecentlyDeployed,
            subscriptionId,
            vrfCoordinator,
            account
        );
    }

    function addConsumer(
        address contractToAddToVrf,
        uint256 subscriptionId,
        address vrfCoordinator,
        address account
    ) public {
        console2.log("Add Consumer", contractToAddToVrf);
        console2.log("using vrfCoordinator", vrfCoordinator);
        console2.log("on ChainId", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
