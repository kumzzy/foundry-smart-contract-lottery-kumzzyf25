-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil

build:; forge build

test:; forge test

install :; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 && forge install transmissions11/solmate@v6

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_NAME) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_NAME) --broadcast -vvvv
deploy-addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_NAME) --broadcast -vvvv

deploy-fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_NAME) --broadcast -vvvv