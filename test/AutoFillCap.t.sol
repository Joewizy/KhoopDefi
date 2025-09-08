// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/KhoopDefi.sol"; // adjust path if needed

/// @notice Simple ERC20 mock with 18 decimals to emulate USDT on BSC
contract MockUSDT is IERC20 {
    string public name = "MockUSDT";
    string public symbol = "mUSDT";
    uint8 public decimals = 18;

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

    // IERC20 events are already defined in IERC20 interface
}

/// @notice Test helper contract that exposes setter to manipulate buybackAccumulated for tests.
/// It inherits your production contract (KhoopDefi). Adjust constructor params if needed.
contract TestKhoopDefi is KhoopDefi {
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _buyback,
        address _powerCycle,
        address _usdt
    ) KhoopDefi(_coreTeam, _investors, _reserve, _buyback, _powerCycle, _usdt) /* if your base uses Ownable(msg.sender) it will still compile */ {
        // no-op
    }

    // exposed setter for tests only
    function setBuybackAccumulated(uint256 v) external {
        buybackAccumulated = v;
    }
}

contract AutoFillCapTest is Test {
    MockUSDT usdt;
    TestKhoopDefi khoop;

    // actors
    address owner = address(0xABCD);
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
    uint256 constant USDT_DECIMALS = 1e18;
    uint256 constant ENTRY_COST = 15e18; // 15 * 10^18
    uint256 constant BUYBACK_PER_ENTRY = 3e18; // 3 * 10^18
    uint256 constant BUYBACK_THRESHOLD = 10e18; // 10 * 10^18
    uint256 constant AUTO_FILL_CAP = 5; // should match contract's AUTO_FILL_CAP

    function setUp() public {
        // deploy mock USDT and mint
        usdt = new MockUSDT();
        // fill some addresses with a lot of USDT
        usdt.mint(owner, 1_000_000 * USDT_DECIMALS);
        usdt.mint(buyer, 1_000_000 * USDT_DECIMALS);

        // fill investor addresses
        for (uint256 i = 0; i < 15; i++) {
            // just create unique addresses
            investors[i] = address(uint160(uint256(keccak256(abi.encodePacked("INV", i))))); 
        }

        // prepare core team array and investors array for constructor
        address[4] memory coreTeam = [core1, core2, core3, core4];
        address[15] memory invAddrs;
        for (uint256 i = 0; i < 15; i++) invAddrs[i] = investors[i];

        // deploy the TestKhoopDefi
        khoop = new TestKhoopDefi(coreTeam, invAddrs, reserve, buyback, powerCycle, address(usdt));

        // give buyer a large balance (done) and approve contract
        vm.prank(buyer);
        usdt.approve(address(khoop), type(uint256).max);

        // ensure owner (msg.sender in test) is setup for anything if needed
    }

    /// @notice This test simulates a large pre-existing buyback pot, then a buyer buys 10 entries.
    /// The contract should add buyback contribution for the 10 entries, then process up to AUTO_FILL_CAP thresholds.
    function test_purchaseTriggersCappedAutoFills() public {
        // Setup: set buybackAccumulated to a pre-existing large value: e.g., 79 * 10^6 (79 USDT)
        uint256 pre = 79e18;
        khoop.setBuybackAccumulated(pre);

        // sanity check
        assertEq(khoop.getBuybackAccumulated(), pre);

        // buyer is not registered yet. Use powerCycle as referrer for first purchase
        // need to mint sufficient tokens (already minted) and approve (already approved)
        uint256 numEntries = 10;
        uint256 amount = ENTRY_COST * numEntries; // 15e6 * 10 = 150e6

        // impersonate buyer for purchase
        vm.prank(buyer);
        console.log("Gas before purchase", gasleft());
        khoop.purchaseEntries(amount, numEntries, powerCycle);
        uint256 gasBefore = gasleft();
        console.log("Gas after purchase", gasleft());    
        console.log("Gas consumed", gasBefore - gasleft()); 

        // After purchase: contract adds buybackAccumulated += numEntries * BUYBACK_PER_ENTRY
        uint256 added = numEntries * BUYBACK_PER_ENTRY; // 10 * 3e18 = 30e18

        // total before processing loop = pre + added
        uint256 beforeLoop = pre + added; // 79e18 + 30e18 = 109e18

        // The loop should process min(possible, AUTO_FILL_CAP) thresholds,
        // where possible = floor(beforeLoop / BUYBACK_THRESHOLD) = floor(109 / 10) = 10
        // cap = AUTO_FILL_CAP = 5 -> processed = 5
        uint256 processed = AUTO_FILL_CAP;

        // expected final pot = beforeLoop - processed * BUYBACK_THRESHOLD
        uint256 expectedFinal = beforeLoop - (processed * BUYBACK_THRESHOLD); // 109e18 - 50e18 = 59e18

        // read actual pot from contract
        uint256 actualFinal = khoop.getBuybackAccumulated();

        // assert equality
        assertEq(actualFinal, expectedFinal, "buybackAccumulated mismatch after capped auto-fill");

        // sanity: check nextEntryId advanced by 10 entries from initial (constructor registered powerCycle as 1 entry if any)
        // You can also check other invariants (global stats, etc.) as needed.
    }
}
