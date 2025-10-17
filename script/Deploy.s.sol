// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";

contract DeployKhoopDefi is Script {
    function run() external returns (KhoopDefi) {
        // Read wallet config from JSON
        string memory json = vm.readFile("src/wallets.json");

        // Parse arrays from JSON and cast to fixed-size
        address[] memory coreTeamDynamic = abi.decode(vm.parseJson(json, ".coreTeam"), (address[]));
        address[] memory investorsDynamic = abi.decode(vm.parseJson(json, ".investors"), (address[]));

        require(coreTeamDynamic.length == 4, "coreTeam length must be 4");
        require(investorsDynamic.length == 15, "investors length must be 15");

        address[4] memory coreTeam;
        address[15] memory investors;
        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = coreTeamDynamic[i];
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = investorsDynamic[i];
        }

        // Parse additional single addresses
        address reserve = abi.decode(vm.parseJson(json, ".additional.contingency"), (address));
        address powerCycle = abi.decode(vm.parseJson(json, ".additional.PowerLine"), (address));
        address usdtToken = 0x1648C0B178EEbCb57Aa31E3C62Ee2B52bfD1A123; // bscTestnet

        // Deploy with broadcast
        vm.startBroadcast();
        KhoopDefi khoopDefi = new KhoopDefi(coreTeam, investors, reserve, powerCycle, usdtToken);
        vm.stopBroadcast();

        console.log("KhoopDefi deployed to:", address(khoopDefi));
        return khoopDefi;
    }
}
