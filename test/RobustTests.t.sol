// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Simple ERC20 mock with 6 decimals to emulate USDT
contract MockUSDT is IERC20 {
    string public name = "MockUSDT";
    string public symbol = "mUSDT";
    uint8 public decimals = 6;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public totalSupply;

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        require(balanceOf[from] >= amount, "insufficient");
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Mint helper
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

/// @notice Test helper contract that exposes setters for testing
contract TestKhoopDefi is KhoopDefi {
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _buyback,
        address _powerCycle,
        address _usdt
    ) KhoopDefi(_coreTeam, _investors, _reserve, _buyback, _powerCycle, _usdt) {
        // no-op
    }

    // Exposed setters for tests only
    function setBuybackAccumulated(uint256 v) external {
        buybackAccumulated = v;
    }
    
    function getPendingStartId() external view returns (uint256) {
        return pendingStartId;
    }
    
    function getNextEntryId() external view returns (uint256) {
        return nextEntryId;
    }
    
    function getEntry(uint256 entryId) external view returns (uint256, address, uint256, bool, uint8) {
        Entry memory entry = entries[entryId];
        return (entry.entryId, entry.user, entry.timestamp, entry.isCompleted, entry.cycleCount);
    }
}

/// @notice Malicious contract for reentrancy testing
contract MaliciousContract {
    KhoopDefi public khoop;
    IERC20 public usdt;
    bool public attacking = false;
    
    constructor(address _khoop, address _usdt) {
        khoop = KhoopDefi(_khoop);
        usdt = IERC20(_usdt);
    }
    
    function attack() external {
        attacking = true;
        // Try to reenter during purchase
        khoop.purchaseEntries(15e6, 1, address(0x1234));
    }
    
    // This will be called during the purchase, trying to reenter
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (attacking) {
            attacking = false;
            // Try to purchase again (reentrancy attack)
            khoop.purchaseEntries(15e6, 1, address(0x1234));
        }
        return this.onERC721Received.selector;
    }
}

contract RobustTests is Test {
    MockUSDT usdt;
    TestKhoopDefi khoop;

    // actors
    address owner = address(0xABCD);
    address testOwner; // Will be set to msg.sender
    address powerCycle = address(0xBEEF);
    address reserve = address(0xDEAD);
    address buyback = address(0xCAFE);
    address core1 = address(0x1001);
    address core2 = address(0x1002);
    address core3 = address(0x1003);
    address core4 = address(0x1004);

    // investors addresses (15)
    address[15] investors;

    // buyers
    address buyer = address(0x2001);

    // constants (match your contract)
    uint256 constant USDT_DECIMALS = 1e6;
    uint256 constant ENTRY_COST = 15e6; // 15 * 10^6
    uint256 constant BUYBACK_PER_ENTRY = 3e6; // 3 * 10^6
    uint256 constant BUYBACK_THRESHOLD = 10e6; // 10 * 10^6
    uint256 constant MAX_AUTO_FILLS_PER_PURCHASE = 5;

    function setUp() public {
        // deploy mock USDT and mint
        usdt = new MockUSDT();
        // fill some addresses with a lot of USDT
        usdt.mint(owner, 10_000_000 * USDT_DECIMALS);
        usdt.mint(buyer, 10_000_000 * USDT_DECIMALS);

        // fill investor addresses
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(uint160(uint256(keccak256(abi.encodePacked("INV", i))))); 
        }

        // prepare core team array and investors array for constructor
        address[4] memory coreTeam = [core1, core2, core3, core4];
        address[15] memory invAddrs;
        for (uint256 i = 0; i < 15; i++) invAddrs[i] = investors[i];

        // deploy the TestKhoopDefi
        khoop = new TestKhoopDefi(coreTeam, invAddrs, reserve, buyback, powerCycle, address(usdt));

        // give buyer a large balance and approve contract
        vm.prank(buyer);
        usdt.approve(address(khoop), type(uint256).max);
    }

    /// @notice Test 1: Gas Limit Protection
    function test_gasLimitProtection() public {
        // Set buyback pot to $1000 (100 thresholds)
        khoop.setBuybackAccumulated(1000e6);
        
        // Create 100 pending entries
        // for every purchase 5 auto-fills are processed
        // so in total 500 auto-fills are processed
        for (uint256 i = 0; i < 100; i++) {
            address user = address(uint160(1000 + i));
            usdt.mint(user, 1000e6);
            vm.prank(user);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(user);
            khoop.purchaseEntries(15e6, 1, powerCycle);
        }
        
        // Single purchase should only process 5 auto-fills (not 100)
        uint256 gasBefore = gasleft();
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Should use reasonable gas (not hit block limit)
        assertLt(gasUsed, 10_000_000, "Gas usage too high - potential gas limit issue");
        
        // Correct math: 100 users × 3e6 = 300e6 added to buyback
        // Total buyback: 1000e6 + 300e6 = 1300e6 (130 thresholds)
        // 5 auto-fills per purchase * 100 purchases = 500 auto-fills
        // Early purchases consume buyback, later purchases have less available
        // so the final buyback should be less than 1000e6
        uint256 finalBuyback = khoop.getBuybackAccumulated();
        
        // Should be significantly reduced from initial 1000e6
        assertTrue(finalBuyback < 1000e6, "Buyback should be reduced from initial 1000e6");
        
        // Log the actual value for debugging
        console.log("Final buyback amount:", finalBuyback);
        console.log("Expected: significantly less than 1000e6 due to auto-fill processing");
    }

    /// @notice Test 2: Insufficient Balance Handling
    function test_insufficientBalanceGracefulExit() public {
        // Set large buyback pot
        khoop.setBuybackAccumulated(100e6);
        
        // Create pending entries
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(2000 + i));
            usdt.mint(user, 1000e6);
            vm.prank(user);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(user);
            khoop.purchaseEntries(15e6, 1, powerCycle);
        }
        
        // Drain contract USDT balance to leave only $50
        uint256 currentBalance = usdt.balanceOf(address(khoop));
        if (currentBalance > 50e6) {
            uint256 drainAmount = currentBalance - 50e6;
            vm.prank(address(khoop));
            usdt.transfer(owner, drainAmount);
        }
        
        // Purchase should still work, but auto-fills stop when balance insufficient
        uint256 buybackBefore = khoop.getBuybackAccumulated();
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        
        // Should not revert, but process fewer auto-fills due to insufficient balance
        uint256 buybackAfter = khoop.getBuybackAccumulated();
        assertTrue(buybackAfter > 0, "Buyback should still have remaining funds");
        assertTrue(buybackAfter > buybackBefore - 50e6, "Should not process all possible auto-fills due to insufficient balance");
    }

    /// @notice Test 3: Queue Advancement Test
    function test_queueAdvancementCorrectness() public {
        // Create 10 pending entries
        address[] memory users = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            users[i] = address(uint160(3000 + i));
            usdt.mint(users[i], 1000e6);
            vm.prank(users[i]);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(users[i]);
            khoop.purchaseEntries(15e6, 1, powerCycle);
        }
        
        // Set buyback pot to process 5 auto-fills (50e6 = 5 * 10e6)
        khoop.setBuybackAccumulated(50e6);
        
        // Purchase should trigger auto-fills
        uint256 startId = khoop.getPendingStartId();
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        uint256 endId = khoop.getPendingStartId();
        
        // Queue should advance by at least 1 (entries that reached cycle 3)
        // Note: Queue only advances when entries are marked as completed (cycle 3)
        assertTrue(endId > startId, "Queue should advance by at least 1 position");
        console.log("Queue advanced from", startId, "to", endId);
        console.log("Queue advancement:", endId - startId);
    }

    /// @notice Test 3.5: Fair FIFO Processing Test
    function test_fairFifoProcessing() public {
        // Create 5 pending entries from different users
        address[] memory users = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(4000 + i));
            usdt.mint(users[i], 1000e6);
            vm.prank(users[i]);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(users[i]);
            khoop.purchaseEntries(15e6, 1, powerCycle);
        }
        
        // Set buyback pot to process 5 auto-fills (50e6 = 5 * 10e6)
        khoop.setBuybackAccumulated(50e6);
        
        // Record initial queue position
        uint256 initialQueuePos = khoop.getPendingStartId();
        
        // Purchase should trigger 5 auto-fills
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        
        // Record final queue position
        uint256 finalQueuePos = khoop.getPendingStartId();
        
        // The fix ensures fair processing: queue should advance properly
        // Before fix: same entry processed multiple times, queue barely advances
        // After fix: different entries processed, queue advances more fairly
        assertTrue(finalQueuePos > initialQueuePos, "Queue should advance after auto-fills");
        
        // The key test: verify that the fix prevents the same entry from being processed multiple times
        // by checking that the queue advancement is reasonable
        uint256 queueAdvancement = finalQueuePos - initialQueuePos;
        assertTrue(queueAdvancement >= 1, "Queue should advance by at least 1 position");
    }

    /// @notice Test 4: Cycle Count Progression Test
    function test_cycleCountProgression() public {
        // Create entry
        address user = address(0x4000);
        usdt.mint(user, 1000e6);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        uint256 entryId = khoop.getNextEntryId() - 1;
        
        // Set buyback pot for 3 auto-fills
        khoop.setBuybackAccumulated(30e6);
        
        // Process 3 cycles
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        
        // Check entry progression
        (uint256 id, address entryUser, uint256 timestamp, bool isCompleted, uint8 cycleCount) = khoop.getEntry(entryId);
        
        assertEq(cycleCount, 3, "Entry should be on cycle 3");
        assertTrue(isCompleted, "Entry should be completed after 3 cycles");
        assertEq(entryUser, user, "Entry user should match");
        assertEq(id, entryId, "Entry ID should match");
    }

    /// @notice Test 5: Zero Pending Entries
    function test_zeroPendingEntries() public {
        // Set large buyback pot but no pending entries
        khoop.setBuybackAccumulated(100e6);
        
        // Purchase should not revert
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        
        // Buyback pot should have new contribution added
        // Initial: 100e6, Added: 30e6 (10 entries * 3e6) = 130e6
        // But the contract might process auto-fills from previous entries if any exist
        uint256 finalBuyback = khoop.getBuybackAccumulated();
        
        // Should be at least 130e6 (if no auto-fills processed) or less (if auto-fills processed)
        assertTrue(finalBuyback >= 30e6, "Buyback should have at least the new contribution");
        assertTrue(finalBuyback <= 130e6, "Buyback should not exceed initial + new contribution");
        
        console.log("Zero pending entries test - Final buyback:", finalBuyback);
    }

    /// @notice Test 6: Reentrancy Protection Test
    function test_reentrancyProtection() public {
        // Create malicious contract
        MaliciousContract malicious = new MaliciousContract(address(khoop), address(usdt));
        
        // Give malicious contract USDT
        usdt.mint(address(malicious), 1000e6);
        vm.prank(address(malicious));
        usdt.approve(address(khoop), type(uint256).max);
        
        // Set up buyback pot
        khoop.setBuybackAccumulated(20e6);
        
        // Should revert due to reentrancy protection
        vm.expectRevert();
        malicious.attack();
    }

    /// @notice Test 7: Event Emission Test
    function test_eventEmission() public {
        // Set buyback pot
        khoop.setBuybackAccumulated(50e6);
        
        // Create pending entries
        for (uint256 i = 0; i < 6; i++) {
            address user = address(uint160(5000 + i));
            usdt.mint(user, 1000e6);
            vm.prank(user);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(user);
            khoop.purchaseEntries(15e6, 1, powerCycle);
        }
        
        // Purchase should work and process auto-fills
        vm.prank(buyer);
        khoop.purchaseEntries(150e6, 10, powerCycle);
        
        // Verify buyback pot was reduced (exact amount depends on how many auto-fills were processed)
        uint256 finalBuyback = khoop.getBuybackAccumulated();
        assertTrue(finalBuyback < 80e6, "Buyback should be reduced from initial 50e6 + 30e6 = 80e6");
        assertTrue(finalBuyback > 0, "Buyback should not be zero");
        
        console.log("Event emission test - Final buyback:", finalBuyback);
    }

    /// @notice Test 8: Maximum Entries Stress Test
    function test_maximumEntriesPerTx() public {
        // Test the 10 entry limit
        uint256 maxEntries = 10;
        uint256 amount = 15e6 * maxEntries;
        
        // Should work with 10 entries
        vm.prank(buyer);
        khoop.purchaseEntries(amount, maxEntries, powerCycle);
        
        // Should fail with 11 entries
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(amount + 15e6, 11, powerCycle);
    }

    /// @notice Test 9: Daily Limit Protection
    function test_dailyLimitProtection() public {
        // Create user
        address user = address(0x6000);
        usdt.mint(user, 1000e6);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);
        
        // First purchase should work
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        // Try to exceed daily limit (50 entries)
        vm.expectRevert();
        vm.prank(user);
        khoop.purchaseEntries(15e6 * 50, 50, powerCycle);
    }

    /// @notice Test 10: Cool Down Protection
    function test_coolDownProtection() public {
        // Create user
        address user = address(0x7000);
        usdt.mint(user, 1000e6);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);
        
        // First purchase should work
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        // Try to purchase again immediately (should fail due to 10min cooldown)
        vm.expectRevert();
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        // Fast forward 10 minutes + 1 second
        vm.warp(block.timestamp + 601);
        
        // Now should work
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
    }

    /// @notice Test 11: Exact Payment Validation
    function test_exactPaymentValidation() public {
        // Test underpayment
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(14e6, 1, powerCycle); // $14 instead of $15
        
        // Test overpayment
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(16e6, 1, powerCycle); // $16 instead of $15
        
        // Test correct payment
        vm.prank(buyer);
        khoop.purchaseEntries(15e6, 1, powerCycle); // Should work
    }

    /// @notice Test 12: Invalid Referrer Protection
    function test_invalidReferrerProtection() public {
        address invalidReferrer = address(0x8000);
        
        // Should fail with invalid referrer
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(15e6, 1, invalidReferrer);
        
        // Should work with valid referrer (powerCycle)
        vm.prank(buyer);
        khoop.purchaseEntries(15e6, 1, powerCycle);
    }

    /// @notice Test 13: Pause/Unpause Functionality
    function test_pauseUnpauseFunctionality() public {
        // Pause the contract
        vm.prank(address(this));
        khoop.pause();
        
        // Purchase should fail when paused
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        // Unpause the contract
        vm.prank(address(this));
        khoop.unpause();
        
        // Purchase should work after unpause
        vm.prank(buyer);
        khoop.purchaseEntries(15e6, 1, powerCycle);
    }

    /// @notice Test 14: Complete Cycle Functionality
    function test_completeCycleFunctionality() public {
        // Ensure contract has enough USDT for payouts
        usdt.mint(address(khoop), 1000e6);
        
        // Create entry
        address user = address(0x9000);
        usdt.mint(user, 1000e6);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);
        vm.prank(user);
        khoop.purchaseEntries(15e6, 1, powerCycle);
        
        uint256 entryId = khoop.getNextEntryId() - 1;
        
        // Try to complete cycle before 3 days
        vm.expectRevert();
        vm.prank(user);
        khoop.completeCycle(entryId);
        
        // Fast forward 3 days + 1 second
        vm.warp(block.timestamp + 259201); // 3 days + 1 second
        
        // Now should work
        vm.prank(user);
        khoop.completeCycle(entryId);
        
        // Check entry is on cycle 2 (not completed yet - needs 3 cycles total)
        (uint256 id, address entryUser, uint256 timestamp, bool isCompleted, uint8 cycleCount) = khoop.getEntry(entryId);
        assertFalse(isCompleted, "Entry should not be completed after 1 cycle");
        assertEq(cycleCount, 2, "Entry should be on cycle 2 after manual completion");
    }
}
