// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SolyTicket} from "./SolyTicket.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Factory is Ownable {
    string public _factoryName;
    string public _factoryTag;

    SolyTicket[] public solyContracts;

    // Minimal Forwarder Address
    address public trustedForwarder;

    event SolyContractDeployed(address indexed by, address indexed contractAddress);

    constructor(string memory factoryName, string memory factoryTag, address _trustedForwader) Ownable() {
        _factoryName = factoryName;
        _factoryTag = factoryTag;
        trustedForwarder = _trustedForwader;
    }

    /// @notice Deploy new SolyTicket event contract
    function createTicket(uint256 totalNFTs, string memory name, string memory tag, string memory arweaveBaseURI)
        public
        onlyOwner
        returns (address)
    {
        SolyTicket solyTicket = new SolyTicket(owner(), totalNFTs, name, tag, arweaveBaseURI, trustedForwarder);
        solyContracts.push(solyTicket);
        emit SolyContractDeployed(msg.sender, address(solyTicket));
        return address(solyTicket);
    }

    /// @notice Get total number of deployed SolyTicket contracts
    function totalSolyContracts() public view returns (uint256) {
        return solyContracts.length;
    }
}
