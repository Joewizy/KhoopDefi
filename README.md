# SolyTicket & Minimal Forwarder Integration

## Overview
This project implements a meta-transaction enabled ERC721A NFT contract (`SolyTicket`) using OpenZeppelin's `ERC2771Context` and a Minimal Forwarder contract. This allows users to sign transactions off-chain, which can then be relayed and executed on-chain by a trusted backend or relayer, enabling gasless UX for end-users.

---

## Key Features
- **ERC721A NFT contract** with meta-transaction support via `ERC2771Context`.
- **Minimal Forwarder** contract for EIP-2771 meta-transactions.
- **Secondary sales marketplace** logic with admin controls.
- **Royalty support** (EIP-2981).

---

## Implementation Details

### ERC2771Context Integration
- The `SolyTicket` contract inherits from `ERC2771Context` (OpenZeppelin) to support meta-transactions.
- The constructor takes a `trustedForwarderAddress` parameter, which is the address of the deployed Minimal Forwarder contract.
- All functions that rely on `msg.sender` use `_msgSender()` instead, ensuring correct sender context for both direct and relayed calls.

### Ownable Constructor Change
- The contract uses `Ownable()` (no constructor argument) instead of `Ownable(msg.sender)`.
- **Reason:** To maintain compatibility with an older OpenZeppelin version required for the Minimal Forwarder, and to avoid mixing library versions. Ownership is transferred to the desired owner within the constructor using `_transferOwnership(owner)`.
- Also you can always change the ownership if you wish as well

---

## How to Redeploy the Contracts

1. **Deploy the Minimal Forwarder**
   - Deploy OpenZeppelin's `MinimalForwarder` contract first.
   - Save the deployed address for use in the NFT contract.
   - check `Script::DeploySolyTicket.s.sol` to see how to deploy it

2. **Deploy the SolyTicket Contract**
   - Pass the following parameters to the constructor:
     - `owner` (address): The admin/owner of the contract.
     - `totalNFTs` (uint256): Number of NFTs to mint.
     - `name` (string): NFT collection name.
     - `tag` (string): NFT symbol.
     - `arweaveBaseURI` (string): Base URI for metadata.
     - `trustedForwarderAddress` (address): Address of the deployed Minimal Forwarder.

Example (using Foundry):
```javascript
MinimalForwarder forwarder = new MinimalForwarder();
SolyTicket soly = new SolyTicket(
    owner,
    totalNFTs,
    name,
    tag,
    arweaveBaseURI,
    address(forwarder)
);
```

---

## Organizing Off-Chain User Transactions (Meta-Transactions)

1. **User signs a transaction off-chain**
   - The frontend prepares the calldata for the desired function (e.g., `listNFT`).
   - The frontend constructs a `ForwardRequest` struct with the following fields:
     - `from`: User's address
     - `to`: NFT contract address
     - `value`: 0 (for most cases)
     - `gas`: Estimate (e.g., 1,000,000)
     - `nonce`: Get from `MinimalForwarder.getNonce(user)`
     - `data`: Encoded function call
   - The frontend signs the request using EIP-712 (`signTypedData`).
   - check `contracts/relayTest.js` to see how run the transactions.

2. **Backend/Relayer submits the transaction**
   - The backend receives the signed request and signature from the frontend.
   - The backend calls `MinimalForwarder.execute(request, signature)` on-chain, paying the gas.
   - The NFT contract executes the function as if the user sent it directly.

---

## Example: Setting Up a Meta-Transaction with the Forwarder

**Frontend (User):**
```javascript
const domain = {
  name: "MinimalForwarder",
  version: "0.0.1",
  chainId: <chainId>,
  verifyingContract: <forwarderAddress>,
};
const types = {
  ForwardRequest: [
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "value", type: "uint256" },
    { name: "gas", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "data", type: "bytes" },
  ],
};
const request = {
  from: user.address,
  to: solyTicket.address,
  value: 0,
  gas: 1_000_000,
  nonce: await forwarder.getNonce(user.address),
  data: solyTicket.interface.encodeFunctionData("listNFT", [tokenId, price]),
};
const signature = await user.signTypedData(domain, types, request);
```

**Backend (Relayer):**
```js
await forwarder.execute(request, signature);
```

---

## Summary
- Deploy the Minimal Forwarder first, then the NFT contract with its address.
- We use `_msgSender()` instead of `msg.sender` in the contract to ensure correct sender context for both direct and relayed transactions.
- Users sign transactions off-chain; backend relays them via the forwarder.

For more details, see the contract and `contracts/relayTest.js` for a full working example.
