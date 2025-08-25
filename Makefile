# Import '.env' file
-include .env

# Install foundry modules
install:
	forge install foundry-rs/forge-std@v1.9.7 && \
	forge install OpenZeppelin/openzeppelin-contracts@v5.3.0

# Remove foundry modules
remove:
	rm -rf lib

format:
	forge fmt

# Build the project
# ; is to write the command in the same line
build :; forge fmt && forge build
build-force :; forge build --force

test-simple:
	forge test
test-verbose:
	forge test -vvvv

coverage:
	forge coverage
coverage-debug:
	forge coverage --report debug > coverage-report.txt

anvil :; anvil --disable-code-size-limit

deploy-govToken-anvil:
	forge script script/DeployGovToken.s.sol:DeployGovTokenScript \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast
deploy-governor-anvil:
	forge script script/DeployMyGovernor.s.sol:DeployMyGovernorScript \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast
