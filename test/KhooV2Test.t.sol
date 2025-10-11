// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefiV2} from "../src/KhoopDefiV2.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";

contract KhoopDefiTest is Test {
    KhoopDefiV2 public khoopDefi;
    MockUSDT public usdt;

    address[4] coreTeam;
    address[15] investors;
    address reserve;
    address buyback;
    address powerCycle;

    uint256 public constant SLOT_PRICE = 15e18;
    uint256 public constant USDT_DECIMALS = 10 ** 18;
    uint256 public constant STARTING_AMOUNT = SLOT_PRICE * 20;
    address user = makeAddr("user");
    address test1 = makeAddr("test1");
    address test2 = makeAddr("test2");
    address test3 = makeAddr("test3");

    function setUp() public {
        usdt = new MockUSDT();

        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = address(this);
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(this);
        }
        reserve = address(this);
        buyback = address(this);
        powerCycle = address(this);

        khoopDefi = new KhoopDefiV2(coreTeam, investors, reserve, powerCycle, address(usdt));
        usdt.mint(address(khoopDefi), STARTING_AMOUNT * 20);
    }

    function testPurchaseEntries() public {
        _registerUser(user);
        vm.startPrank(user);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();
    }

    function testMultipleUsers() public {
        _registerUser(user);
        _registerUser(test1);
        _registerUser(test2);
        _registerUser(test3);
        uint256 initialGas = gasleft();

        vm.startPrank(user);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test1);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test2);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test3);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();
        uint256 finalGas = gasleft();

        console.log("Initial Gas: ", initialGas);
        console.log("Final Gas: ", finalGas);
        console.log("Gas Used: ", initialGas - finalGas);

        // All testers should have cycles completed
        uint256 pendingCyclesCount = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count: ", pendingCyclesCount);
    }

    function testThousandUsers() public {
        address[100_000] memory testUsers;
        uint256 gas = gasleft();
        uint256 startingBalance = khoopDefi.usdt().balanceOf(address(khoopDefi)) / USDT_DECIMALS;
        console.log("KhoopDefi starting balance: ", startingBalance);
        for (uint256 i = 0; i < 100_000; i++) {
            testUsers[i] = address(uint160(1 + i));
            _registerUser(testUsers[i]);
            vm.startPrank(testUsers[i]);
            khoopDefi.purchaseEntries(10);
            vm.stopPrank();
        }

        (
            uint256 totalUsers,
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted
        ) = khoopDefi.getGlobalStats();
        console.log("KhoopDefi ending balance: ", khoopDefi.usdt().balanceOf(address(khoopDefi)) / USDT_DECIMALS);
        console.log("Balance diff: ", startingBalance - khoopDefi.usdt().balanceOf(address(khoopDefi)) / USDT_DECIMALS);
        console.log("Pending Cycles Count: ", khoopDefi.getPendingCyclesCount());
        console.log("Gas Used: ", gas - gasleft());
        console.log("Total Users: ", totalUsers);
        console.log("Total Active Users: ", totalActiveUsers);
        console.log("Total Entries Purchased: ", totalEntriesPurchased);
        console.log("Total Referrer Bonus Paid: ", totalReferrerBonusPaid);
        console.log("Total Payouts Made: ", totalPayoutsMade);
        console.log("Total Cycles Completed: ", totalCyclesCompleted);
    }

    function _registerUser(address user) internal {
        usdt.mint(user, STARTING_AMOUNT);
        vm.startPrank(user);
        khoopDefi.registerUser(user, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        vm.stopPrank();
    }
}
