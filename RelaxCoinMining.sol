// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRelaxCoin is IERC20 {
    function mintForMining(address to, uint256 amount) external;
}

contract RelaxCoinMining is Ownable {
    using SafeERC20 for IERC20;

    IRelaxCoin public immutable r2rToken;

    uint256 public totalShares;
    uint256 public accRewardPerShare;
    uint256 public totalRewardsDisbursed;
    uint256 public lastRewardBlock;
    uint256 public pendingRewardPool;
    bool public paused;
    address public timelock;
    uint256 public rewardRate;
    uint256 public minDifficulty = 1;
    uint256 public maxDifficulty = 1_000_000;

    uint256 public constant ACC_SCALE = 1e18;
    uint256 public constant MIN_DIFFICULTY = 1;
    uint256 public constant MAX_DIFFICULTY = 1_000_000;

    struct Miner {
        uint256 shares;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(address => Miner) public miners;

    event ShareSubmitted(address indexed miner, uint256 difficulty, bytes32 challenge);
    event RewardPoolDeposited(uint256 amount);
    event RewardDistributed(uint256 amount, uint256 accRewardPerShare);
    event RewardsClaimed(address indexed miner, uint256 amount);

    modifier whenNotPaused() {
        require(!paused, "RelaxCoinMining: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "RelaxCoinMining: not admin");
        _;
    }

    constructor(address _r2rToken) Ownable(msg.sender) {
        require(_r2rToken != address(0), "RelaxCoinMining: zero token");
        r2rToken = IRelaxCoin(_r2rToken);
        lastRewardBlock = block.number;
        rewardRate = 1;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "RelaxCoinMining: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0) && to != address(0), "RelaxCoinMining: invalid address");
        IERC20(token).transfer(to, amount);
    }

    function setDifficultyRange(uint256 _minDifficulty, uint256 _maxDifficulty) external onlyAdmin {
        require(_minDifficulty >= MIN_DIFFICULTY, "RelaxCoinMining: min too low");
        require(_maxDifficulty >= _minDifficulty && _maxDifficulty <= MAX_DIFFICULTY, "RelaxCoinMining: invalid range");
        minDifficulty = _minDifficulty;
        maxDifficulty = _maxDifficulty;
    }

    function setRewardRate(uint256 newRate) external onlyAdmin {
        rewardRate = newRate;
    }

    function depositRewardPool(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "RelaxCoinMining: amount zero");
        IERC20(address(r2rToken)).safeTransferFrom(msg.sender, address(this), amount);

        _updatePool();
        totalRewardsDisbursed += amount;

        if (totalShares == 0) {
            pendingRewardPool += amount;
            emit RewardPoolDeposited(amount);
            return;
        }

        accRewardPerShare += (amount * ACC_SCALE) / totalShares;

        emit RewardPoolDeposited(amount);
        emit RewardDistributed(amount, accRewardPerShare);
    }

    function submitShare(uint256 nonce, uint256 difficulty) external whenNotPaused returns (bool) {
        require(difficulty >= minDifficulty && difficulty <= maxDifficulty, "RelaxCoinMining: bad difficulty");

        bytes32 challenge = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, nonce, difficulty));
        uint256 target = type(uint256).max / difficulty;
        require(uint256(challenge) < target, "RelaxCoinMining: invalid share");

        _updateMiner(msg.sender);

        miners[msg.sender].shares += difficulty;
        totalShares += difficulty;

        if (pendingRewardPool > 0) {
            accRewardPerShare += (pendingRewardPool * ACC_SCALE) / totalShares;
            pendingRewardPool = 0;
        }

        miners[msg.sender].rewardDebt = (miners[msg.sender].shares * accRewardPerShare) / ACC_SCALE;

        emit ShareSubmitted(msg.sender, difficulty, challenge);
        return true;
    }

    function pendingReward(address wallet) external view returns (uint256) {
        if (miners[wallet].shares == 0) {
            return 0;
        }

        uint256 accumulated = (miners[wallet].shares * accRewardPerShare) / ACC_SCALE;
        if (accumulated <= miners[wallet].rewardDebt) {
            return miners[wallet].pendingRewards;
        }

        return miners[wallet].pendingRewards + (accumulated - miners[wallet].rewardDebt);
    }

    function claimRewards() external whenNotPaused {
        _updateMiner(msg.sender);

        uint256 reward = miners[msg.sender].pendingRewards;
        require(reward > 0, "RelaxCoinMining: no rewards");

        miners[msg.sender].pendingRewards = 0;
        require(r2rToken.transfer(msg.sender, reward), "RelaxCoinMining: transfer failed");

        emit RewardsClaimed(msg.sender, reward);
    }

    function getMinerInfo(address wallet) external view returns (uint256 shares, uint256 rewardDebt, uint256 pendingRewards) {
        Miner storage miner = miners[wallet];
        return (miner.shares, miner.rewardDebt, miner.pendingRewards);
    }

    function _updateMiner(address wallet) internal {
        uint256 accumulated = (miners[wallet].shares * accRewardPerShare) / ACC_SCALE;

        if (accumulated > miners[wallet].rewardDebt) {
            miners[wallet].pendingRewards += accumulated - miners[wallet].rewardDebt;
        }

        miners[wallet].rewardDebt = accumulated;
    }

    function _updatePool() internal {
        lastRewardBlock = block.number;
    }
}
