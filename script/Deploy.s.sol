// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "../test/mocks/MockUSDT.sol";

contract DeployKhoopDefi is Script {
    function run() external returns (KhoopDefi) {
        vm.startBroadcast();
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

        // uint256 USDT_AMOUNT = 100e18;

        // Parse additional single addresses
        address reserve = abi.decode(vm.parseJson(json, ".additional.contingency"), (address));
        address buyback = abi.decode(vm.parseJson(json, ".additional.buyback"), (address));
        address powerCycle = abi.decode(vm.parseJson(json, ".additional.PowerLine"), (address));

        // MockUSDT usdtToken = new MockUSDT();
        // usdtToken.mint(msg.sender, USDT_AMOUNT);

        // // Mint to team wallets
        // for (uint256 i = 0; i < 4; i++) {
        //     usdtToken.mint(coreTeam[i], USDT_AMOUNT);
        // }
        // for (uint256 i = 0; i < 15; i++) {
        //     usdtToken.mint(investors[i], USDT_AMOUNT);
        // }
        // usdtToken.mint(reserve, USDT_AMOUNT);
        // usdtToken.mint(buyback, USDT_AMOUNT);
        // usdtToken.mint(powerCycle, USDT_AMOUNT);

        // console.log("Mock USDT contract", address(usdtToken));
       // address usdtTokenBaseMainnet = 0x55d398326f99059fF775485246999027B3197955;
        address usdtToken= 0x1648C0B178EEbCb57Aa31E3C62Ee2B52bfD1A123;
        address usdt = address(usdtToken);

        // Deploy with addresses from JSON/env
        KhoopDefi khoopDefi = new KhoopDefi(coreTeam, investors, reserve, buyback, powerCycle, usdt);

        // usdtToken.mint(address(khoopDefi), USDT_AMOUNT);

        vm.stopBroadcast();
        return khoopDefi;
    }
}
