// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldFarm
 * @dev Staking and reward distribution contract for QIE Liquidity Nexus
 */
contract YieldFarm is ReentrancyGuard, Ownable {
    IERC20 public rewardToken;
    IERC20 public stakingToken;
    
    uint256 public rewardRate = 100 * 10**18; // 100 tokens per second
    uint256 public totalStaked;
    uint256 public lastRewardTime;
    uint256 public rewardPerTokenStored;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    constructor(address _rewardToken, address _stakingToken) {
        require(_rewardToken != address(0) && _stakingToken != address(0), "Invalid addresses");
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);
        lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev Update reward per token based on elapsed time
     */
    function updateRewardPerToken() public {
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        
        uint256 timePassed = block.timestamp - lastRewardTime;
        rewardPerTokenStored += (rewardRate * timePassed * 1e18) / (totalStaked * 1e18);
        lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev Get earned rewards for a user
     */
    function earned(address user) public view returns (uint256) {
        uint256 timePassed = block.timestamp - lastRewardTime;
        uint256 currentRewardPerToken = rewardPerTokenStored;
        
        if (totalStaked > 0) {
            currentRewardPerToken += (rewardRate * timePassed * 1e18) / (totalStaked * 1e18);
        }
        
        return rewards[user] + (balances[user] * (currentRewardPerToken - userRewardPerTokenPaid[user])) / 1e18;
    }
    
    /**
     * @dev Stake tokens
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        
        updateRewardPerToken();
        
        // Update earned rewards
        rewards[msg.sender] += (balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18;
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        
        // Transfer tokens and update balance
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev Unstake tokens
     */
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        updateRewardPerToken();
        
        // Update earned rewards
        rewards[msg.sender] += (balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18;
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        
        // Update balance and unstake
        balances[msg.sender] -= amount;
        totalStaked -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        updateRewardPerToken();
        
        // Calculate earned rewards
        rewards[msg.sender] += (balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18;
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        rewards[msg.sender] = 0;
        require(rewardToken.transfer(msg.sender, reward), "Transfer failed");
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    /**
     * @dev Set reward rate (only owner)
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        updateRewardPerToken();
        rewardRate = _rewardRate;
    }
}
