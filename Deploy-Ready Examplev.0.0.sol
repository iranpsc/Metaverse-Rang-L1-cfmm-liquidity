// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

// =================== IMPORTS =========================
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

// =================== INTERFACES ======================
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

// =================== PSC TOKEN =======================
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

    constructor() ERC20("Paradaise Supply Chain", "PSC") Ownable(msg.sender) {
        // ===== Example addresses – جایگزین بشه با آدرس ئلت های واقعی=====
        address publicWallet = 0x1111111111111111111111111111111111111111;
        address[15] memory teamWallets = [
            0x2222222222222222222222222222222222222222,
            0x3333333333333333333333333333333333333333,
            0x4444444444444444444444444444444444444444,
            0x5555555555555555555555555555555555555555,
            0x6666666666666666666666666666666666666666,
            0x7777777777777777777777777777777777777777,
            0x8888888888888888888888888888888888888888,
            0x9999999999999999999999999999999999999999,
            0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
            0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,
            0xcccccccccccccccccccccccccccccccccccccccc,
            0xdddddddddddddddddddddddddddddddddddddddd,
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
            0xffffffffffffffffffffffffffffffffffffffff,
            0x1234567890123456789012345678901234567890
        ];
        address investorWallet = 0x0987654321098765432109876543210987654321;

        uint64 startTimestamp = uint64(block.timestamp + 60); // 1 دقیقه بعد

        _mint(address(this), TOTAL_SUPPLY);

        // ===== Public =====
        uint256 publicAmount = (TOTAL_SUPPLY * PUBLIC_PERCENT) / 100;
        _transfer(address(this), publicWallet, publicAmount);

        // ===== Team Vesting =====
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
        }

        // ===== Investor Step Vesting =====
        uint256 investorAmount = TOTAL_SUPPLY - publicAmount - teamTotalAmount;
        investorVesting = new InvestorStepVesting(
            investorWallet,
            startTimestamp,
            INVESTOR_STEP,
            INVESTOR_STEPS
        );
        _transfer(address(this), address(investorVesting), investorAmount);
    }
}

// =================== INVESTOR STEP VESTING =============
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

// =================== ADVANCED LP LOCKER ==================
contract PSCLPAdvancedLocker is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable lpToken;
    struct Lock { uint256 amount; uint256 unlockTime; uint256 released; }
    Lock[] public locks;

    constructor(address _lpToken) Ownable(msg.sender) { lpToken = IERC20(_lpToken); }

    function createLock(uint256 amount, uint256 unlockTime) external onlyOwner {
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        locks.push(Lock(amount, unlockTime, 0));
    }

    function release(uint256 lockId) external onlyOwner {
        Lock storage l = locks[lockId];
        require(block.timestamp >= l.unlockTime, "Not unlocked");
        uint256 amount = l.amount - l.released;
        require(amount > 0, "Nothing to release");
        l.released += amount;
        lpToken.safeTransfer(owner(), amount);
    }
}

// =================== LIQUIDITY MANAGER ==================
contract PSCLiquidityManager is Ownable {
    using SafeERC20 for IERC20;
    address public immutable token;
    IUniswapV2Router02 public immutable router;
    address public pair;
    bool public liquidityAdded;

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
        require(!liquidityAdded, "Already added");
        require(tokenAmount > 0 && msg.value > 0, "Invalid amounts");

        // Create or fetch pair
        address existingPair = IUniswapV2Factory(router.factory()).getPair(token, router.WETH());
        if (existingPair == address(0)) { 
            pair = IUniswapV2Factory(router.factory()).createPair(token, router.WETH());
        } else { pair = existingPair; }

        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).approve(address(router), tokenAmount);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: msg.value}(
            token, tokenAmount, minToken, minETH, address(this), block.timestamp + 15 minutes
        );

        liquidityAdded = true;

        // Approve and auto-lock LP
        IERC20(pair).approve(lpLocker, 0);
        IERC20(pair).approve(lpLocker, liquidity);
        PSCLPAdvancedLocker(lpLocker).createLock(liquidity, unlockTime);
    }
}
