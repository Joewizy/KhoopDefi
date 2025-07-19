// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { SolyTicket } from "../src/SolyTicket.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { MinimalForwarder } from "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

contract SolyTicketTest is Test {
    address owner;
    address user;
    address trustedForwarder;
    string name;
    string tag;
    string arweaveBaseURI;
    uint256 totalNFTs;

    ///////////////////
    //   contracts ///
    ///////////////////
    SolyTicket public solyTicket;
    MinimalForwarder public forwarder;

    function setUp() public {
        owner = address(this);
        user = vm.addr(1);
        
        // deploy the forwarder contract (Relayer)
        forwarder = new MinimalForwarder();
        trustedForwarder = address(forwarder);

        name = "SolyTicket";
        tag = "SOLY";
        arweaveBaseURI = "ar://base/";
        totalNFTs = 10;

        solyTicket = new SolyTicket(
            owner,
            totalNFTs,
            name,
            tag,
            arweaveBaseURI,
            trustedForwarder
        );
    }

    function testTrustedForwarderSet() public {
        assertEq(solyTicket.trustedForwarderAddress(), trustedForwarder);
    }

    function testMsgSenderViaForwarder() public {
        // Gift NFT to user
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        solyTicket.giftNFTs(nftIds, user);

        // Enable secondary sales
        solyTicket.toggleSecondarySales(true);

        // Prepare the calldata for listNFT function
        bytes memory callData = abi.encodeWithSelector(
            solyTicket.listNFT.selector,
            1, // tokenId
            1 ether // price
        );

        // Get current nonce
        uint256 nonce = forwarder.getNonce(user);

        // Construct ForwardRequest
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: user,
            to: address(solyTicket),
            value: 0,
            gas: 1_000_000,
            nonce: nonce,
            data: callData
        });

        // Build EIP-712 digest manually
        bytes32 structHash = keccak256(abi.encode(
            keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"),
            req.from,
            req.to,
            req.value,
            req.gas,
            req.nonce,
            keccak256(req.data)
        ));

        // Get domain separator from the forwarder
        bytes32 domainSeparator = _computeDomainSeparator(address(forwarder));
        
        // Compute the full EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // Sign the digest with user's private key (corresponding to vm.addr(1))
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute meta-transaction via forwarder
        (bool success, bytes memory returndata) = forwarder.execute(req, signature);
        assertTrue(success, "Meta-transaction execution failed");

        // Validate listing creation
        assertEq(solyTicket.nextListingId(), 1);
        SolyTicket.Listing memory listing = solyTicket.getListing(0);

        assertEq(listing.tokenId, 1);
        assertEq(listing.seller, user);
        assertEq(listing.price, 1 ether);
        assertTrue(listing.active);

        // Confirm nonce increment, this is very important so it is not vulnerable to replay attack!
        assertEq(forwarder.getNonce(user), nonce + 1);
    }

    // Helper function to compute domain separator
    function _computeDomainSeparator(address forwarderAddress) internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("MinimalForwarder"),
            keccak256("0.0.1"),
            block.chainid,
            forwarderAddress
        ));
    }
}