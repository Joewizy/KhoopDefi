require("dotenv").config();
const { ethers } = require("ethers");
const fs = require("fs");

// Load ABI files for the smart contract and forwarder
const SolyTicketJSON = JSON.parse(fs.readFileSync("./out/SolyTicket.sol/SolyTicket.json"));
const ForwarderJSON = JSON.parse(fs.readFileSync("./out/MinimalForwarder.sol/MinimalForwarder.json"));
const SolyTicketABI = SolyTicketJSON.abi;
const ForwarderABI = ForwarderJSON.abi;

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const owner = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY, provider);
  const user = new ethers.Wallet(process.env.USER_PRIVATE_KEY, provider);

  const soly = new ethers.Contract(process.env.SOLYTICKET_ADDRESS, SolyTicketABI, owner);
  const forwarder = new ethers.Contract(process.env.FORWARDER_ADDRESS, ForwarderABI, provider);

  // Enable secondary sales on the contract
  const enableTx = await soly.toggleSecondarySales(true);
  await enableTx.wait();
  console.log("✅ Secondary sales enabled");

  // Gift an NFT to the user
  // Use a unique NFT ID for each run to avoid errors from gifting an already transferred NFT
  let nextNftId = 5; 
  const nftIds = [nextNftId];
  const tx = await soly.giftNFTs(nftIds, user.address);
  await tx.wait();
  console.log(`✅ NFT ${nextNftId} gifted to`, user.address);

  // Prepare meta-transaction: user lists the gifted NFT via the forwarder
  const interface = new ethers.Interface(SolyTicketABI);
  const tokenIdToList = nextNftId; // Use the same ID as the gifted NFT
  const encoded = interface.encodeFunctionData("listNFT", [tokenIdToList, ethers.parseEther("0.0001")]);

  // Get the user's nonce from the forwarder
  const nonce = await forwarder.getNonce(user.address);
  console.log("User nonce:", nonce.toString());

  // Construct the meta-transaction request
  const request = {
    from: user.address,
    to: await soly.getAddress(),
    value: 0,
    gas: 1_000_000,
    nonce: nonce,
    data: encoded,
  };
  console.log("Request object:", request);

  // Define the EIP-712 domain for the MinimalForwarder
  const domain = {
    name: "MinimalForwarder",
    version: "0.0.1",
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: await forwarder.getAddress(),
  };

  // Define the EIP-712 types for the ForwardRequest
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

  // Sign the typed data
  console.log("Signing typed data...");
  const signature = await user.signTypedData(domain, types, request);
  console.log("Signature:", signature);

  // Execute the meta-transaction
  let tx2;
  try {
    console.log("Executing meta-transaction...");
    console.log("Calling forwarder.execute(request, signature)");
    tx2 = await forwarder.connect(owner).execute(request, signature, { gasLimit: 1_500_000 });
    const receipt = await tx2.wait();
    console.log("✅ Meta-transaction executed successfully!");
    console.log("Transaction hash:", receipt.hash);
    console.log("Gas used:", receipt.gasUsed.toString());

    // Verify the listing was created
    const nextListingId = await soly.nextListingId();
    console.log("Next listing ID:", nextListingId.toString());
    if (nextListingId > 0) {
      const listing = await soly.getListing(nextListingId - 1n);
      console.log("✅ Listing created:");
      console.log("  Token ID:", listing.tokenId.toString());
      console.log("  Seller:", listing.seller);
      console.log("  Price:", ethers.formatEther(listing.price), "ETH");
      console.log("  Active:", listing.active);
    }
  } catch (error) {
    console.error("❌ Meta-transaction failed:", error);
    if (error.data) console.log("Error data:", error.data);
    if (error.reason) console.log("Error reason:", error.reason);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});