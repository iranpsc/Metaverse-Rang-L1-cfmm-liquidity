// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

// =====================================================
// =================== IMPORTS =========================
// =====================================================
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

// =====================================================
// ================== INTERFACES =======================
// =====================================================
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

// =====================================================
// ==================== PSC TOKEN =====================
// =====================================================
contract MyToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 20_000_000 ether;
    uint256 public constant PUBLIC_PERCENT = 10;
    uint256 public constant TEAM_PERCENT = 3;

    uint64 public constant TEAM_CLIFF = 365 days;
    uint64 public constant TEAM_VESTING_DURATION = 730 days;
    uint64 public constant INVESTOR_STEP = 180 days;
    uint8 public constant INVESTOR_STEPS = 4;

    VestingWallet[] public teamVestings;
    InvestorStepVesting public investorVesting;

    event TeamVestingCreated(address indexed beneficiary, address vestingWallet, uint256 amount);
    event InvestorVestingCreated(address indexed investor, address vestingWallet, uint256 amount);
    event PublicDistributed(address indexed publicWallet, uint256 amount);

    constructor(
        address publicWallet,
        address[] memory teamWallets,
        address investorWallet,
        uint64 startTimestamp
    ) ERC20("Paradaise Supply Chain", "PSC") Ownable(msg.sender) {
        require(teamWallets.length == 15, "Team wallets must be 15");
        _mint(address(this), TOTAL_SUPPLY);

        // Public
        uint256 publicAmount = (TOTAL_SUPPLY * PUBLIC_PERCENT) / 100;
        _transfer(address(this), publicWallet, publicAmount);
        emit PublicDistributed(publicWallet, publicAmount);

        // Team Vesting
        uint256 teamTotalAmount = (TOTAL_SUPPLY * TEAM_PERCENT) / 100;
        uint256 perTeamMember = teamTotalAmount / teamWallets.length;
        for (uint256 i = 0; i < teamWallets.length; i++) {
            VestingWallet vesting = new VestingWallet(
                teamWallets[i],
                startTimestamp + TEAM_CLIFF,
                TEAM_VESTING_DURATION
            );
            _transfer(address(this), address(vesting), perTeamMember);
            teamVestings.push(vesting);
            emit TeamVestingCreated(teamWallets[i], address(vesting), perTeamMember);
        }

        // Investor Step Vesting
        uint256 investorAmount = TOTAL_SUPPLY - publicAmount - teamTotalAmount;
        investorVesting = new InvestorStepVesting(
            investorWallet,
            startTimestamp,
            INVESTOR_STEP,
            INVESTOR_STEPS
        );
        _transfer(address(this), address(investorVesting), investorAmount);
        emit InvestorVestingCreated(investorWallet, address(investorVesting), investorAmount);
    }

    function teamVestingsCount() external view returns (uint256) { return teamVestings.length; }
    function getTeamVestings() external view returns (VestingWallet[] memory) { return teamVestings; }
}

// =====================================================
// ==================== INVESTOR STEP VESTING =========
// =====================================================
contract InvestorStepVesting is Ownable {
    address public immutable beneficiary;
    uint64 public immutable start;
    uint64 public immutable stepDuration;
    uint8 public immutable totalSteps;
    uint256 public released;

    constructor(address _beneficiary, uint64 _start, uint64 _stepDuration, uint8 _totalSteps) Ownable(msg.sender) {
        beneficiary = _beneficiary;
        start = _start;
        stepDuration = _stepDuration;
        totalSteps = _totalSteps;
    }

    function releasable(address token) public view returns (uint256) {
        uint256 vested = vestedAmount(token, uint64(block.timestamp));
        return vested - released;
    }

    function release(address token) external {
        uint256 amount = releasable(token);
        require(amount > 0, "Nothing to release");
        released += amount;
        IERC20(token).transfer(beneficiary, amount);
    }

    function vestedAmount(address token, uint64 timestamp) public view returns (uint256) {
        uint256 totalAllocation = IERC20(token).balanceOf(address(this)) + released;
        if (timestamp < start) return 0;
        uint256 elapsedSteps = (timestamp - start) / stepDuration + 1;
        if (elapsedSteps >= totalSteps) return totalAllocation;
        return (totalAllocation * elapsedSteps) / totalSteps;
    }
}

// =====================================================
// =================== ADVANCED LP LOCKER ==============
// =====================================================
contract PSCLPAdvancedLocker is Ownable {
    using SafeERC20 for IERC20;

    struct Lock { uint256 amount; uint256 unlockTime; uint256 released; }
    IERC20 public immutable lpToken;
    Lock[] public locks;

    event LockCreated(uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event LockExtended(uint256 indexed lockId, uint256 newUnlockTime);
    event Released(uint256 indexed lockId, uint256 amount);

    constructor(address _lpToken) Ownable(msg.sender) { lpToken = IERC20(_lpToken); }

    function createLock(uint256 amount, uint256 unlockTime) external onlyOwner {
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        locks.push(Lock({amount: amount, unlockTime: unlockTime, released: 0}));
        emit LockCreated(locks.length - 1, amount, unlockTime);
    }

    function extendLock(uint256 lockId, uint256 newUnlockTime) external onlyOwner {
        Lock storage l = locks[lockId]; require(newUnlockTime > l.unlockTime, "Must extend");
        l.unlockTime = newUnlockTime; emit LockExtended(lockId, newUnlockTime);
    }

    function releasable(uint256 lockId) public view returns (uint256) {
        Lock storage l = locks[lockId]; if (block.timestamp < l.unlockTime) return 0;
        return l.amount - l.released;
    }

    function release(uint256 lockId) external onlyOwner {
        uint256 amount = releasable(lockId); require(amount > 0, "Nothing to release");
        Lock storage l = locks[lockId]; l.released += amount;
        lpToken.safeTransfer(owner(), amount); emit Released(lockId, amount);
    }

    function getLockCount() external view returns (uint256) { return locks.length; }
    function getLock(uint256 lockId) external view returns (uint256 amount, uint256 unlockTime, uint256 released) {
        Lock storage l = locks[lockId]; return (l.amount, l.unlockTime, l.released);
    }
    function remainingLock(uint256 lockId) external view returns (uint256) {
        Lock storage l = locks[lockId]; if (block.timestamp >= l.unlockTime) return 0;
        return l.unlockTime - block.timestamp;
    }

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

// =====================================================
// =================== LIQUIDITY MANAGER ===============
// =====================================================
contract PSCLiquidityManager is Ownable {
    using SafeERC20 for IERC20;

    address public immutable token;
    IUniswapV2Router02 public immutable router;
    address public pair;
    bool public liquidityAdded;

    event PairCreated(address indexed pair);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    constructor(address _token, address _router) Ownable(msg.sender) {
        token = _token; router = IUniswapV2Router02(_router);
    }

    receive() external payable {}

    function createPoolAndAddLiquidityAndLock(
        uint256 tokenAmount,
        uint256 minToken,
        uint256 minETH,
        address lpLocker,
        uint256 unlockTime
    ) external payable onlyOwner {
        require(!liquidityAdded, "Liquidity already added");
        require(tokenAmount > 0 && msg.value > 0, "Invalid amounts");
        require(lpLocker != address(0), "Invalid LP Locker");

        // ---------- create or fetch pair ----------
        address factory = router.factory(); 
        address weth = router.WETH();
        address existingPair = IUniswapV2Factory(factory).getPair(token, weth);
        if (existingPair == address(0)) { 
            pair = IUniswapV2Factory(factory).createPair(token, weth); 
            emit PairCreated(pair); 
        } else { 
            pair = existingPair; 
        }

        // ---------- pull tokens ----------
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).approve(address(router), tokenAmount);

        // ---------- add liquidity ----------
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: msg.value}(
            token, tokenAmount, minToken, minETH, address(this), block.timestamp + 15 minutes
        );

        liquidityAdded = true;
        emit LiquidityAdded(amountToken, amountETH, liquidity);

        // ---------- approve and auto-lock LP ----------
        IERC20(pair).approve(lpLocker, 0);         // reset previous allowance
        IERC20(pair).approve(lpLocker, liquidity); // approve new amount
        PSCLPAdvancedLocker(lpLocker).createLock(liquidity, unlockTime);
    }
}
