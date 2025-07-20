// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SolyTicket} from "../src/SolyTicket.sol";
import {Factory} from "../src/SolyFactory.sol";
import {MinimalForwarder} from "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

contract DeploySolyTicket is Script {
    function run() external {
        vm.startBroadcast();

        MinimalForwarder minimalForwarder = new MinimalForwarder();
        address forwarderAddr = address(minimalForwarder);

        address owner = msg.sender;
        uint256 totalNFTs = 10;
        string memory name = "SolyTicket";
        string memory tag = "SOLY";
        string memory arweaveBaseURI = "ar://base/";
        address trustedForwarder = forwarderAddr;

        SolyTicket solyTicket = new SolyTicket(owner, totalNFTs, name, tag, arweaveBaseURI, trustedForwarder);

        string memory factoryName = "FactoryContract1";
        string memory factoryTag = "FAC";
        Factory solyFactory = new Factory(factoryName, factoryTag, trustedForwarder);

        saveAddresses(address(solyTicket), address(solyFactory), forwarderAddr);

        console.log("SolyTicket deployed at:", address(solyTicket));
        console.log("SolyFactory deployed at:", address(solyFactory));
        console.log("MinimalForwarder deployed at:", forwarderAddr);

        vm.stopBroadcast();
    }

    function saveAddresses(address solyTicket, address solyFactory, address forwarderAddr) internal {
        string memory deploymentFile = "deployments/contracts.env";
        string memory newline = "\n";
        string memory deploymentData = string.concat(
            "SOLY_TICKET=", vm.toString(solyTicket), newline,
            "SOLY_FACTORY=", vm.toString(solyFactory), newline,
            "MINIMAL_FORWARDER=", vm.toString(forwarderAddr)
        );
        vm.writeFile(deploymentFile, deploymentData);
        console.log("Deployment data saved to:", deploymentFile);
    }
}