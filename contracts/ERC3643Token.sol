// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IKYCRegistry {
    function isKYCVerified(address user) external view returns (bool);
}

contract ERC3643Token is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IKYCRegistry public kycRegistry;

    mapping(address => string) private _tokenMetadata; // Stores IPFS metadata per address

    constructor(string memory name, string memory symbol, address kycRegistryAddress) ERC20(name, symbol) {
        _grantRole(ADMIN_ROLE, msg.sender);
        kycRegistry = IKYCRegistry(kycRegistryAddress);
    }

    function mint(address to, uint256 amount, string memory ipfsHash) external onlyRole(ADMIN_ROLE) {
        require(kycRegistry.isKYCVerified(to), "Recipient is not KYC verified");
        _mint(to, amount);
        _tokenMetadata[to] = ipfsHash; // Store metadata reference
    }

    function getMetadata(address account) external view returns (string memory) {
        return _tokenMetadata[account];
    }

}