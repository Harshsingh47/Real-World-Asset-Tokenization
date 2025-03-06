// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./KYCRegistry.sol";
import "./ERC3643Token.sol";

contract CustodialWallet is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");

    IKYCRegistry public kycRegistry;
    ERC3643Token public rwaToken;

    mapping(address => uint256) private _balances;
    mapping(bytes32 => uint256) private _approvals;
    mapping(bytes32 => bool) private _executed;
    uint256 public constant REQUIRED_APPROVALS = 2;

    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(bytes32 indexed txId, address indexed user, uint256 amount);
    event WithdrawalApproved(bytes32 indexed txId, address indexed approver);
    event WithdrawalExecuted(bytes32 indexed txId, address indexed user, uint256 amount);

    constructor(address kycRegistryAddress, address tokenAddress) {
        _grantRole(ADMIN_ROLE, msg.sender);
        kycRegistry = IKYCRegistry(kycRegistryAddress);
        rwaToken = ERC3643Token(tokenAddress);
    }

    function deposit(uint256 amount) external {
        require(kycRegistry.isKYCVerified(msg.sender), "User is not KYC verified");
        rwaToken.transferFrom(msg.sender, address(this), amount);
        _balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function requestWithdrawal(uint256 amount) external {
        require(kycRegistry.isKYCVerified(msg.sender), "User is not KYC verified");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        bytes32 txId = keccak256(abi.encodePacked(msg.sender, amount, block.timestamp));
        emit WithdrawalRequested(txId, msg.sender, amount);
    }

    function approveWithdrawal(bytes32 txId) external onlyRole(APPROVER_ROLE) {
        require(!_executed[txId], "Transaction already executed");
        _approvals[txId]++;
        emit WithdrawalApproved(txId, msg.sender);
    }

    function executeWithdrawal(bytes32 txId, address user, uint256 amount) external onlyRole(CUSTODIAN_ROLE) {
        require(_approvals[txId] >= REQUIRED_APPROVALS, "Not enough approvals");
        require(_balances[user] >= amount, "Insufficient balance");
        require(!_executed[txId], "Transaction already executed");
        _executed[txId] = true;
        _balances[user] -= amount;
        rwaToken.transfer(user, amount);
        emit WithdrawalExecuted(txId, user, amount);
    }

    function getBalance(address user) external view returns (uint256) {
        return _balances[user];
    }
}