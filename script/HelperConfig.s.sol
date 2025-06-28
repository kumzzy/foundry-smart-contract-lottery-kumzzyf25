// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract codeConstant {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant M0CK_WEI_PER_UNIT_LINK = 4e15;
    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant MAINNET_ETH_CHAIN_ID = 1;
}

contract HelperConfig is codeConstant, Script {
    error HelperConfig__InvalidConfig();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callBackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public NetworkConfigs;

    constructor() {
        NetworkConfigs[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthConfig();
        NetworkConfigs[MAINNET_ETH_CHAIN_ID] = getMainnetEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (NetworkConfigs[chainId].vrfCoordinator != address(0)) {
            return NetworkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidConfig();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return (getConfigByChainId(block.chainid));
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.05 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 64070931767876321262467568026057503853292036375110013558271132781100237950825, //subscriptionId not generated yet
            callBackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x947cA63b7C83c7954DD8D1EBd1c584287449B64C
        });
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.05 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            subscriptionId: 0, //subscriptionId not generated yet
            callBackGasLimit: 500000,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x947cA63b7C83c7954DD8D1EBd1c584287449B64C
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, M0CK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.05 ether,
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, //subscriptionId not generated yet
            callBackGasLimit: 500000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
