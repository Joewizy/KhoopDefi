// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SolyTicket} from "../src/SolyTicket.sol";
import {MinimalForwarder} from "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

contract DeploySolyTicket is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the trusted forwarder (meta-transaction relayer)
        MinimalForwarder minimalForwarder = new MinimalForwarder();
        console.log("Forwarder deployed at:", address(minimalForwarder));

        address owner = msg.sender;
        uint256 totalNFTs = 10;
        string memory name = "SolyTicket";
        string memory tag = "SOLY";
        string memory arweaveBaseURI = "ar://base/";
        address trustedForwarder = address(minimalForwarder);

        // Deploy the SolyTicket contract
        SolyTicket solyTicket = new SolyTicket(owner, totalNFTs, name, tag, arweaveBaseURI, trustedForwarder);

        console.log("SolyTicket deployed at:", address(solyTicket));

        vm.stopBroadcast();
    }
}
