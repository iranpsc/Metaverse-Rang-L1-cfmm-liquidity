// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

// =====================================================
// =================== IMPORTS ==========================
// =====================================================

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// =====================================================
// ================== INTERFACES ========================
// =====================================================

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
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
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        );
}

// =====================================================
// ============== PSC LIQUIDITY MANAGER =================
// =====================================================

/// @title PSC Liquidity Manager
/// @notice Creates Uniswap pair and adds initial liquidity safely
contract PSCLiquidityManager is Ownable {
    using SafeERC20 for IERC20;

    // =================================================
    // ================= STORAGE =======================
    // =================================================

    address public immutable token;
    IUniswapV2Router02 public immutable router;

    address public pair;
    bool public liquidityAdded;

    // =================================================
    // ================= EVENTS ========================
    // =================================================

    event PairCreated(address indexed pair);
    event LiquidityAdded(
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );
    event EmergencyTokenRecovered(address token, uint256 amount);
    event EmergencyETHRecovered(uint256 amount);

    // =================================================
    // ================= CONSTRUCTOR ===================
    // =================================================

    constructor(address _token, address _router) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");
        require(_router != address(0), "Invalid router");

        token = _token;
        router = IUniswapV2Router02(_router);
    }

    receive() external payable {}

    // =================================================
    // ========= CREATE PAIR + ADD LIQUIDITY ===========
    // =================================================

    function createPoolAndAddLiquidity(
        uint256 tokenAmount,
        uint256 minToken,
        uint256 minETH
    ) external payable onlyOwner {
        require(!liquidityAdded, "Liquidity already added");
        require(tokenAmount > 0, "Zero token amount");
        require(msg.value > 0, "ETH required");

        address factory = router.factory();
        address weth = router.WETH();

        // ---------- create or fetch pair ----------
        address existingPair =
            IUniswapV2Factory(factory).getPair(token, weth);

        if (existingPair == address(0)) {
            pair = IUniswapV2Factory(factory).createPair(token, weth);
            emit PairCreated(pair);
        } else {
            pair = existingPair;
        }

        // ---------- pull tokens ----------
        IERC20(token).safeTransferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );

        IERC20(token).forceApprove(address(router), tokenAmount);

        // ---------- add liquidity ----------
        (
            uint amountToken,
            uint amountETH,
            uint liquidity
        ) = router.addLiquidityETH{value: msg.value}(
                token,
                tokenAmount,
                minToken,
                minETH,
                owner(),
                block.timestamp + 15 minutes
            );

        liquidityAdded = true;

        emit LiquidityAdded(amountToken, amountETH, liquidity);
    }

    // =================================================
    // ============== EMERGENCY RECOVERY ===============
    // =================================================

    function recoverERC20(address _token, uint256 amount)
        external
        onlyOwner
    {
        require(_token != token, "Cannot recover main token");

        IERC20(_token).safeTransfer(owner(), amount);
        emit EmergencyTokenRecovered(_token, amount);
    }

  function recoverETH(uint256 amount) external onlyOwner {
    require(amount <= address(this).balance, "Insufficient ETH");

    (bool success, ) = payable(owner()).call{value: amount}("");
    require(success, "ETH transfer failed");

    emit EmergencyETHRecovered(amount);
}


}
