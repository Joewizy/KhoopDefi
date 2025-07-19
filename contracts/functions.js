const { ethers } = require("ethers");

// Write: Enable secondary sales
async function enableSecondarySales(solyContract, signer) {
  const tx = await solyContract.connect(signer).toggleSecondarySales(true);
  return tx.wait();
}

// Write: Gift NFT to user
async function giftNFTs(solyContract, signer, nftIds, receiver) {
  const tx = await solyContract.connect(signer).giftNFTs(nftIds, receiver);
  return tx.wait();
}

// Write: Execute meta-transaction via MinimalForwarder
async function executeMetaTx(forwarderContract, signer, request, signature) {
  const tx = await forwarderContract.connect(signer).execute(request, signature, { gasLimit: 1_500_000 });
  return tx.wait();
}

// Utility: Prepare meta-tx signature (EIP-712)
async function signMetaTx(userWallet, domain, types, request) {
  return userWallet.signTypedData(domain, types, request);
}

module.exports = {
  enableSecondarySales,
  giftNFTs,
  executeMetaTx,
  signMetaTx,
};