// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/KhoopDefi.sol";
import "../test/mocks/MockUSDT.sol";

contract BatchPurchases is Script {
    function run() external {
        // 1) Deploy mocks and contract via deterministic deployer key
        uint256 deployerPk = uint256(keccak256(abi.encodePacked("deployer")));
        vm.startBroadcast(deployerPk);
        MockUSDT usdt = new MockUSDT();

        // Initialize arrays
        address[4] memory coreTeam;
        address[15] memory investors;
        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = address(this);
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(this);
        }

        KhoopDefi kde = new KhoopDefi(coreTeam, investors, address(this), address(this), address(this), address(usdt));
        vm.stopBroadcast();

        // 2) Execute actions from multiple users using per-user private keys
        // Derive 20 deterministic private keys and use them as distinct senders
        uint256 totalGas;
        uint256 maxGas;
        for (uint256 i = 0; i < 10_000; i++) {
            uint256 userPk = uint256(keccak256(abi.encodePacked("user-pk", i)));
            address user = vm.addr(userPk);

            vm.startBroadcast(userPk);
            // Fund and approve from the user's account
            usdt.mint(user, 1_000e6);
            usdt.approve(address(kde), type(uint256).max);
            // Perform the purchase
            uint256 g0 = gasleft();
            kde.purchaseEntries(15e6, 1, address(0));
            uint256 used = g0 - gasleft();
            totalGas += used;
            if (used > maxGas) maxGas = used;
            if (i % 100 == 0) {
                console2.log("purchase #", i + 1, "gas:", used);
            }
            vm.stopBroadcast();
        }
        console2.log("totalGas:", totalGas);
        console2.log("maxGas:", maxGas);
    }
}
