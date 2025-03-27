// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MasterOwnerModifier} from "../src/MasterOwnerModifier.sol";
import {MasterContract} from "../src/Master.sol";
import {TreasuryFund} from "../src/TreasuryFund.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract DeployScript is Script {
    function run() external {

        // address eth_usdc_token_testnet_address = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238); // USDC testnet address
        // address eth_usdc_token_mainnet_address = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC mainnet address
        
        address base_usdc_token_testnet_address = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // USDC testnet address

        // Ambil private key dan RPC URL dari .env
        console.log("Deploying MasterContract...");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        console.log("Deployer private key:", deployerPrivateKey);
        string memory chain = "BASE"; // BASE, BSC, POLYGON, etc
        string memory network = "SEPOLIA"; // SEPOLIA, MAINNET
        string memory rpcUrl;

        if (keccak256(bytes(network)) == keccak256(bytes("SEPOLIA"))) {
            rpcUrl = vm.envString(string.concat(chain, "_SEPOLIA_RPC_URL"));
            console.log(" Deploying to ",chain," Sepolia...");
        } else if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
            rpcUrl = vm.envString(string.concat(chain, "_MAINNET_RPC_URL"));
            console.log(" Deploying to ",chain," Mainnet...");
        } else {
            revert(" Unsupported network! Use 'sepolia' or 'mainnet'.");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MasterOwnerModifier
        MasterOwnerModifier masterOwnerModifier = new MasterOwnerModifier();
        console.log(" MasterOwnerModifier deployed at:", address(masterOwnerModifier));

        // Deploy TreasuryFund
        TreasuryFund treasuryFund = new TreasuryFund();
        console.log("TreasuryFund deployed at:", address(treasuryFund));

        // Deploy MasterContract
        MasterContract masterContract = new MasterContract(
            address(treasuryFund),
            base_usdc_token_testnet_address,
            address(masterOwnerModifier)
        );
        console.log("MasterContract deployed at:", address(masterContract));

        // Create an event using MasterContract
        console.log("Creating an event...");
        address eventAddress = masterContract.createEvent(
            "Sample Event",       // Event name
            "SEVT",               // NFT symbol
            block.timestamp + 1 days, // Event start time
            block.timestamp + 2 days, // Event end time
            block.timestamp,          // Ticket sale start time
            block.timestamp + 12 hours // Ticket sale end time
        );
        console.log("EventContract deployed at:", eventAddress);

        vm.stopBroadcast();

        // Verify the deployed event contract
        console.log("Verifying EventContract...");
        string[] memory verifyArgs = new string[](4);
        verifyArgs[0] = "forge";
        verifyArgs[1] = "verify-contract";
        verifyArgs[2] = vm.toString(eventAddress);
        verifyArgs[3] = "src/EventContract.sol:EventContract";
        vm.ffi(verifyArgs);
        console.log("EventContract verified successfully.");
    }
}
/*
forge script script/deploy.s.sol --rpc-url $(grep ${NETWORK}_RPC_URL .env | cut -d '=' -f2) --broadcast --private-key $DEPLOYER_PRIVATE_KEY

auto deploy and verify
forge script script/deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify --etherscan-api-key $BASESCAN_API_KEY

*/