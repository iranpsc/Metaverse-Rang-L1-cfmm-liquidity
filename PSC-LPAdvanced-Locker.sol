// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PSC LP Advanced Locker.
/// @notice Advanced LP locking contract with multi-lock, partial unlock, and public info
contract PSCLPAdvancedLocker is Ownable {
    using SafeERC20 for IERC20;

    struct Lock {
        uint256 amount;        // total amount locked
        uint256 unlockTime;    // timestamp when fully unlocked
        uint256 released;      // amount already withdrawn
    }

    IERC20 public immutable lpToken;

    Lock[] public locks;

    event LockCreated(uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event LockExtended(uint256 indexed lockId, uint256 newUnlockTime);
    event Released(uint256 indexed lockId, uint256 amount);

    constructor(address _lpToken) Ownable(msg.sender) {
        require(_lpToken != address(0), "Invalid LP token");
        lpToken = IERC20(_lpToken);
    }

    // ================= CREATE LOCK =================

    function createLock(uint256 amount, uint256 unlockTime) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(unlockTime > block.timestamp, "Invalid unlock time");

        lpToken.safeTransferFrom(msg.sender, address(this), amount);

        locks.push(Lock({
            amount: amount,
            unlockTime: unlockTime,
            released: 0
        }));

        emit LockCreated(locks.length - 1, amount, unlockTime);
    }

    // ================= EXTEND LOCK =================

    function extendLock(uint256 lockId, uint256 newUnlockTime) external onlyOwner {
        require(lockId < locks.length, "Invalid lockId");
        Lock storage l = locks[lockId];
        require(newUnlockTime > l.unlockTime, "Must extend");

        l.unlockTime = newUnlockTime;

        emit LockExtended(lockId, newUnlockTime);
    }

    // ================= RELEASE =================

    function releasable(uint256 lockId) public view returns (uint256) {
        require(lockId < locks.length, "Invalid lockId");
        Lock storage l = locks[lockId];

        if (block.timestamp < l.unlockTime) return 0;
        return l.amount - l.released;
    }

    function release(uint256 lockId) external onlyOwner {
        uint256 amount = releasable(lockId);
        require(amount > 0, "Nothing to release");

        Lock storage l = locks[lockId];
        l.released += amount;

        lpToken.safeTransfer(owner(), amount);

        emit Released(lockId, amount);
    }

    // ================= VIEW FUNCTIONS =================

    function getLockCount() external view returns (uint256) {
        return locks.length;
    }

    function getLock(uint256 lockId) external view returns (uint256 amount, uint256 unlockTime, uint256 released) {
        require(lockId < locks.length, "Invalid lockId");
        Lock storage l = locks[lockId];
        return (l.amount, l.unlockTime, l.released);
    }

    function remainingLock(uint256 lockId) external view returns (uint256) {
        require(lockId < locks.length, "Invalid lockId");
        Lock storage l = locks[lockId];
        if (block.timestamp >= l.unlockTime) return 0;
        return l.unlockTime - block.timestamp;
    }

    // ================= EMERGENCY RECOVERY =================

    function recoverERC20(address _token, uint256 amount) external onlyOwner {
        require(_token != address(lpToken), "Cannot recover main LP");
        IERC20(_token).safeTransfer(owner(), amount);
    }

    function recoverETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient ETH");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
