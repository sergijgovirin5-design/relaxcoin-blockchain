// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyToken.sol";

contract R2RMiningPool is Ownable {
    RelaxCoin public immutable r2rToken;
    uint256 public totalShares;
    uint256 public accRewardPerShare;
    uint256 public pendingRewardPool;
    uint256 public targetBase = type(uint256).max / 1024;
    uint256 public constant ACC_FACTOR = 1e18;
    bool public paused;
    address public timelock;
    uint256 public rewardRate;
    uint256 public miningDifficulty = 1000000;

    struct Miner {
        uint256 shares;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(address => Miner) public miners;

    event ShareSubmitted(address indexed miner, uint256 difficulty, bytes32 challenge);
    event RewardsDistributed(uint256 amount, uint256 accRewardPerShare);
    event RewardsClaimed(address indexed miner, uint256 amount);
    event TargetBaseUpdated(uint256 previousTarget, uint256 newTarget);

    modifier whenNotPaused() {
        require(!paused, "R2RMiningPool: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "R2RMiningPool: not admin");
        _;
    }

    constructor(RelaxCoin _r2rToken) Ownable(msg.sender) {
        require(address(_r2rToken) != address(0), "R2RMiningPool: token zero");
        r2rToken = _r2rToken;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "R2RMiningPool: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "R2RMiningPool: to zero");
        require(r2rToken.transfer(to, amount), "R2RMiningPool: transfer failed");
    }

    function setTargetBase(uint256 newTargetBase) external onlyOwner {
        require(newTargetBase > 0, "R2RMiningPool: target base zero");
        emit TargetBaseUpdated(targetBase, newTargetBase);
        targetBase = newTargetBase;
    }

    function setRewardRate(uint256 newRate) external onlyAdmin {
        rewardRate = newRate;
    }

    function setMiningDifficulty(uint256 newDifficulty) external onlyAdmin {
        require(newDifficulty > 0, "R2RMiningPool: difficulty zero");
        miningDifficulty = newDifficulty;
    }

    function submitShare(uint256 nonce, uint256 difficulty) external whenNotPaused returns (bool) {
        require(difficulty > 0 && difficulty <= miningDifficulty, "R2RMiningPool: invalid difficulty");
        bytes32 challenge = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, nonce, difficulty));
        uint256 target = targetBase / difficulty;
        require(uint256(challenge) < target, "R2RMiningPool: invalid share");

        _updateMiner(msg.sender);

        uint256 shareValue = difficulty;
        miners[msg.sender].shares += shareValue;
        totalShares += shareValue;

        if (pendingRewardPool > 0) {
            accRewardPerShare += (pendingRewardPool * ACC_FACTOR) / totalShares;
            pendingRewardPool = 0;
        }

        miners[msg.sender].rewardDebt = (miners[msg.sender].shares * accRewardPerShare) / ACC_FACTOR;

        emit ShareSubmitted(msg.sender, difficulty, challenge);
        return true;
    }

    function distributeRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "R2RMiningPool: amount zero");

        r2rToken.mintForMining(address(this), amount);

        if (totalShares == 0) {
            pendingRewardPool += amount;
            emit RewardsDistributed(amount, accRewardPerShare);
            return;
        }

        accRewardPerShare += (amount * ACC_FACTOR) / totalShares;

        emit RewardsDistributed(amount, accRewardPerShare);
    }

    function claimRewards() external {
        _updateMiner(msg.sender);

        uint256 reward = miners[msg.sender].pendingRewards;
        require(reward > 0, "R2RMiningPool: no reward");

        miners[msg.sender].pendingRewards = 0;
        require(r2rToken.transfer(msg.sender, reward), "R2RMiningPool: transfer failed");

        emit RewardsClaimed(msg.sender, reward);
    }

    function pendingReward(address miner) external view returns (uint256) {
        uint256 accumulated = (miners[miner].shares * accRewardPerShare) / ACC_FACTOR;
        if (accumulated <= miners[miner].rewardDebt) {
            return miners[miner].pendingRewards;
        }
        return miners[miner].pendingRewards + (accumulated - miners[miner].rewardDebt);
    }

    function _updateMiner(address miner) internal {
        uint256 accumulated = (miners[miner].shares * accRewardPerShare) / ACC_FACTOR;
        if (accumulated > miners[miner].rewardDebt) {
            miners[miner].pendingRewards += accumulated - miners[miner].rewardDebt;
        }
        miners[miner].rewardDebt = accumulated;
    }
}
