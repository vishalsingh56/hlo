// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityPool
 * @dev Automated Market Maker (AMM) contract for QIE Blockchain
 * Implements constant product formula: x * y = k
 */
contract LiquidityPool is ReentrancyGuard, Ownable {
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    
    uint256 public constant FEE_PERCENTAGE = 25; // 0.25% fee
    
    mapping(address => uint256) public liquidityBalance;
    
    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    
    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    /**
     * @dev Add liquidity to the pool
     * @param amountA Amount of token A
     * @param amountB Amount of token B
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");
        
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        reserveA += amountA;
        reserveB += amountB;
        
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Remove liquidity from the pool
     * @param liquidity Amount of LP tokens to burn
     * @return amountA Amount of token A returned
     * @return amountB Amount of token B returned
     */
    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Invalid amount");
        require(liquidityBalance[msg.sender] >= liquidity, "Insufficient balance");
        
        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;
        
        require(amountA > 0 && amountB > 0, "Insufficient output amounts");
        
        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;
        
        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Swap tokens using the constant product formula
     * @param tokenIn Address of input token
     * @param amountIn Amount of input tokens
     * @return amountOut Amount of output tokens
     */
    function swap(address tokenIn, uint256 amountIn) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid amount");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        bool isTokenA = tokenIn == address(tokenA);
        IERC20 inToken = isTokenA ? tokenA : tokenB;
        IERC20 outToken = isTokenA ? tokenB : tokenA;
        uint256 inReserve = isTokenA ? reserveA : reserveB;
        uint256 outReserve = isTokenA ? reserveB : reserveA;
        
        require(inToken.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        
        // Calculate fee and amount after fee
        uint256 fee = (amountIn * FEE_PERCENTAGE) / 10000;
        uint256 amountInAfterFee = amountIn - fee;
        
        // Calculate output using x*y=k formula
        amountOut = (amountInAfterFee * outReserve) / (inReserve + amountInAfterFee);
        require(amountOut > 0, "Insufficient output amount");
        
        // Update reserves
        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }
        
        require(outToken.transfer(msg.sender, amountOut), "Transfer failed");
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }
    
    /**
     * @dev Get quote for a swap without executing it
     * @param tokenIn Address of input token
     * @param amountIn Amount of input tokens
     * @return amountOut Estimated amount of output tokens
     */
    function getQuote(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        bool isTokenA = tokenIn == address(tokenA);
        uint256 inReserve = isTokenA ? reserveA : reserveB;
        uint256 outReserve = isTokenA ? reserveB : reserveA;
        
        uint256 fee = (amountIn * FEE_PERCENTAGE) / 10000;
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = (amountInAfterFee * outReserve) / (inReserve + amountInAfterFee);
    }
    
    /**
     * @dev Calculate square root using Babylonian method
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
