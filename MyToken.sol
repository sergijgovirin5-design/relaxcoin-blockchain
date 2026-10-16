// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import  @openzeppelin/contracts/token/ERC20/ERC20.sol;
import @openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol;
import @openzeppelin/contracts/access/Ownable.sol;

interface IR2RStaking {
    function industryTaxPercentFor(address account) external view returns (uint256);
}

contract RelaxCoin is ERC20, ERC20Burnable, Ownable {
    uint256 public burnPercent = 60;
    uint256 public constant INDUSTRY_TAX_PERCENT = 1050;
    uint256 public constant TREASURY_TAX_PERCENT = 50;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant MIN_SUPPLY_LIMIT = 870000000 * 10 ** 18;

    uint256 public lastHalvingTime;
    address public industryWallet;
    address public treasuryWallet;
    address public stakingContract;

    event IndustryWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event TreasuryWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event StakingContractUpdated(address indexed previousContract, address indexed newContract);

    constructor(address _industryWallet, address _treasuryWallet) ERC20(RelaxCoin, R2R) {
        require(_industryWallet != address(0), RelaxCoin: industry wallet zero);
        require(_treasuryWallet != address(0), RelaxCoin: treasury wallet zero);

        _mint(msg.sender, 8000000000 * 10 ** decimals());
        industryWallet = _industryWallet;
        treasuryWallet = _treasuryWallet;
        lastHalvingTime = block.timestamp;
    }

    function setIndustryWallet(address _industryWallet) external onlyOwner {
        require(_industryWallet != address(0), RelaxCoin: industry wallet zero);
        emit IndustryWalletUpdated(industryWallet, _industryWallet);
        industryWallet = _industryWallet;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), RelaxCoin: treasury wallet zero);
        emit TreasuryWalletUpdated(treasuryWallet, _treasuryWallet);
        treasuryWallet = _treasuryWallet;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        emit StakingContractUpdated(stakingContract, _stakingContract);
        stakingContract = _stakingContract;
    }

    function _checkAndApplyHalving() internal {
        if (block.timestamp >= lastHalvingTime + 315360000) {
            burnPercent = burnPercent / 2;
            lastHalvingTime = block.timestamp;
        }
    }

    function _currentIndustryTaxPercent(address account) internal view returns (uint256) {
        if (stakingContract != address(0)) {
            uint256 customTax = IR2RStaking(stakingContract).industryTaxPercentFor(account);
            if (customTax > 0 ; customTax <= INDUSTRY_TAX_PERCENT) {
                return customTax;
            }
        }
        return INDUSTRY_TAX_PERCENT;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _checkAndApplyHalving();

        uint256 burnAmount = 0;
        if (totalSupply() - ((amount * burnPercent) / DIVISOR) >= MIN_SUPPLY_LIMIT) {
            burnAmount = (amount * burnPercent) / DIVISOR;
            _burn(msg.sender, burnAmount);
        }

        uint256 industryAmount = (amount * _currentIndustryTaxPercent(msg.sender)) / DIVISOR;
        uint256 treasuryAmount = (amount * TREASURY_TAX_PERCENT) / DIVISOR;

        if (industryAmount > 0) {
            super.transfer(industryWallet, industryAmount);
        }
        if (treasuryAmount > 0) {
            super.transfer(treasuryWallet, treasuryAmount);
        }

        uint256 sendAmount = amount - burnAmount - industryAmount - treasuryAmount;
        return super.transfer(to, sendAmount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _checkAndApplyHalving();

        uint256 burnAmount = 0;
        if (totalSupply() - ((amount * burnPercent) / DIVISOR) >= MIN_SUPPLY_LIMIT) {
            burnAmount = (amount * burnPercent) / DIVISOR;
            _burn(from, burnAmount);
        }

        uint256 industryAmount = (amount * _currentIndustryTaxPercent(from)) / DIVISOR;
        uint256 treasuryAmount = (amount * TREASURY_TAX_PERCENT) / DIVISOR;
        uint256 sendAmount = amount - burnAmount - industryAmount - treasuryAmount;

        _spendAllowance(from, msg.sender, amount);

        if (industryAmount > 0) {
            _transfer(from, industryWallet, industryAmount);
        }
        if (treasuryAmount > 0) {
            _transfer(from, treasuryWallet, treasuryAmount);
        }
        _transfer(from, to, sendAmount);

        return true;
    }
}
