# 🔐 PSCLPAdvancedLocker — Full Smart Contract Documentation

## 📌 Overview

`PSCLPAdvancedLocker` is an advanced LP (Liquidity Provider) token locking smart contract written in Solidity (v0.8.27). It is designed for secure, owner-controlled liquidity management with support for multiple independent locks, time-based vesting, partial releases, and emergency recovery mechanisms.

This contract is suitable for DeFi treasury management, liquidity locking, and controlled token vesting systems.

---

## ⚙️ Key Features

- 🔒 Multi-lock system (multiple independent LP locks)
- ⏳ Time-based unlocking mechanism
- 💸 Partial release tracking per lock
- 🧾 Full lock history stored on-chain
- 🛡️ SafeERC20 integration (secure token transfers)
- 🔐 Owner-only control model
- 🚨 Emergency recovery for ERC20 and ETH
- 📊 Event-driven transparency for indexing

---

## 🧱 Contract Dependencies

This contract uses OpenZeppelin libraries:

- `Ownable` → Access control (onlyOwner restriction)
- `IERC20` → Standard ERC20 interface
- `SafeERC20` → Safe token transfer handling

---

## 🗂️ Core Data Structure

### 🔹 Lock Struct

Each LP lock is stored as:

```solidity
struct Lock {
    uint256 amount;      // Total locked LP tokens
    uint256 unlockTime;  // Timestamp when unlock becomes valid
    uint256 released;    // Already withdrawn amount
}



🔹 Storage Variables
IERC20 public immutable lpToken;
Lock[] public locks;
lpToken → The LP token being locked
locks → Dynamic array storing all lock entries
🧪 Core Functions
🔒 createLock()

Creates a new LP lock.

function createLock(uint256 amount, uint256 unlockTime)
✔ Requirements:
Only owner can call
amount must be > 0
unlockTime must be in the future
⚙️ Process:
Transfers LP tokens from owner → contract
Creates a new lock entry
Stores it in locks[]
Emits event
event LockCreated(uint256 lockId, uint256 amount, uint256 unlockTime);
⏳ extendLock()

Extends an existing lock duration.

function extendLock(uint256 lockId, uint256 newUnlockTime)
✔ Rules:
lockId must exist
newUnlockTime must be greater than current unlockTime
⚙️ Behavior:

Updates only the unlock timestamp and emits:

event LockExtended(uint256 lockId, uint256 newUnlockTime);
💸 releasable()

Calculates how many tokens are available for release.

function releasable(uint256 lockId)
✔ Logic:
If current time < unlockTime → returns 0
Otherwise → returns (amount - released)
🚀 release()

Releases unlocked LP tokens back to owner.

function release(uint256 lockId)
✔ Requirements:
Only owner
Must have releasable amount > 0
⚙️ Process:
Calculates releasable amount
Updates released balance
Transfers tokens to owner
Emits event
event Released(uint256 lockId, uint256 amount);
📊 View Functions
🔹 getLockCount()

Returns total number of locks.

function getLockCount() external view returns (uint256)
🔹 getLock()

Returns full lock details:

(amount, unlockTime, released)
🔹 remainingLock()

Returns remaining time until unlock (in seconds).

🛡️ Emergency Recovery
🔹 recoverERC20()

Allows recovery of accidentally sent ERC20 tokens (except LP token).

function recoverERC20(address token, uint256 amount)

❌ Cannot recover the main LP token for safety.

🔹 recoverETH()

Allows recovery of ETH sent to contract.

function recoverETH(uint256 amount)

✔ Transfers ETH back to owner

🔐 Security Design
🔐 OnlyOwner restriction for all critical actions
🧯 LP token is protected from recovery
🧾 SafeERC20 prevents failed token transfers
⏳ Time-based locking ensures vesting security
📉 No user-deposit risk (owner-controlled model)
📢 Events
Event	Description
LockCreated	New LP lock created
LockExtended	Lock duration extended
Released	Tokens released to owner
🧠 System Flow
Owner deposits LP tokens using createLock
Tokens are locked until unlockTime
After unlock → owner calls release
Partial release is tracked via released
Locks can be extended if needed
Emergency recovery handles accidental transfers

🚀 Summary

PSCLPAdvancedLocker provides a professional-grade LP locking system with:

✔ Multi-lock architecture
✔ Time-based unlocking
✔ Partial withdrawal tracking
✔ Emergency recovery tools
✔ Secure OpenZeppelin integration

It is optimized for DeFi treasury management and liquidity vesting systems.

Parsa Abolhasani Rad
