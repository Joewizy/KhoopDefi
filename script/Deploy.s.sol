// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";

contract DeployKhoopDefi is Script {
    function run() external returns (KhoopDefi) {
        vm.startBroadcast();

        // Initialize arrays
        address[4] memory coreTeam;
        address[15] memory investors;
        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = 0x1234567890123456789012345678901234567890;
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = 0x2345678901234567890123456789012345678901;
        }

        // Deploy with team wallets (replace with actual addresses)
        KhoopDefi khoopDefi = new KhoopDefi(
            coreTeam,
            investors,
            0x3456789012345678901234567890123456789012, // reserve
            0x4567890123456789012345678901234567890123, // buyback
            0x6789012345678901234567890123456789012345, // powerCycle
            0x5678901234567890123456789012345678901234 // usdt
        );

        vm.stopBroadcast();
        return khoopDefi;
    }
}
