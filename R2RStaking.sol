// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRelaxCoin {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract R2RStaking is Ownable {
    IRelaxCoin public immutable r2rToken;

    struct Tier {
        uint256 minStake;
        string label;
    }

    Tier[] public tiers;
    mapping(address => uint256) public staked;
    uint256 public totalStaked;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event TierUpdated(uint256 index, uint256 minStake, uint256 industryTaxPercent, string label);

    constructor(address _r2rToken) {
        require(_r2rToken != address(0), "R2RStaking: token zero");
        r2rToken = IRelaxCoin(_r2rToken);

        tiers.push(Tier({minStake: 5000000 * 10 ** 18, industryTaxPercent: 900, label: "Bronze"}));
        tiers.push(Tier({minStake: 20000000 * 10 ** 18, industryTaxPercent: 600, label: "Silver"}));
        tiers.push(Tier({minStake: 50000000 * 10 ** 18, industryTaxPercent: 250, label: "Gold"}));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "R2RStaking: amount zero");
        staked[msg.sender] += amount;
        totalStaked += amount;
        require(r2rToken.transferFrom(msg.sender, address(this), amount), "R2RStaking: transfer failed");
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "R2RStaking: amount zero");
        require(staked[msg.sender] >= amount, "R2RStaking: insufficient stake");
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        require(IERC20(address(r2rToken)).transfer(msg.sender, amount), "R2RStaking: transfer failed");
        emit Unstaked(msg.sender, amount);
    }

    function industryTaxPercentFor(address account) external view returns (uint256) {
        uint256 balance = staked[account];
        for (uint256 i = tiers.length; i > 0; ) {
            unchecked { i--; }
            if (balance >= tiers[i].minStake) {
                return tiers[i].industryTaxPercent;
            }
        }
        return 1050;
    }

    function tierFor(address account) external view returns (string memory) {
        uint256 balance = staked[account];
        for (uint256 i = tiers.length; i > 0; ) {
            unchecked { i--; }
            if (balance >= tiers[i].minStake) {
                return tiers[i].label;
            }
        }
        return "None";
    }

    function updateTier(uint256 index, uint256 minStake, uint256 industryTaxPercent, string calldata label) external onlyOwner {
        require(index < tiers.length, "R2RStaking: invalid tier");
        tiers[index] = Tier({minStake: minStake, industryTaxPercent: industryTaxPercent, label: label});
        emit TierUpdated(index, minStake, industryTaxPercent, label);
    }
}
