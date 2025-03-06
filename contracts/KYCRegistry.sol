// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract KYCRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant KYC_VERIFIED_ROLE = keccak256("KYC_VERIFIED_ROLE");

    mapping(address => bool) private _kycStatus;

    event KYCApproved(address indexed user);
    event KYCRevoked(address indexed user);

    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function approveKYC(address user) external onlyRole(ADMIN_ROLE) {
        _grantRole(KYC_VERIFIED_ROLE, user);
        _kycStatus[user] = true;
        emit KYCApproved(user);
    }

    function revokeKYC(address user) external onlyRole(ADMIN_ROLE) {
        _revokeRole(KYC_VERIFIED_ROLE, user);
        _kycStatus[user] = false;
        emit KYCRevoked(user);
    }

    function isKYCVerified(address user) external view returns (bool) {
        return _kycStatus[user];
    }
}
