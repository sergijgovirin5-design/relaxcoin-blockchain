// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IR2RStaking {
    function industryTaxPercentFor(address account) external view returns (uint256);
}

contract RelaxCoin is ERC20, ERC20Burnable, Ownable {
    // Burn percent in basis points (bp). Default 100 = 1%.
    uint256 public burnPercent = 100;
    // Industry tax default in bp (admin-settable). Default 0 = no industry tax.
    uint256 public industryTaxPercent = 0;
    uint256 public constant TREASURY_TAX_PERCENT = 50;
    uint256 public constant MINING_FEE_BP = 10;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant MAX_TOTAL_SUPPLY = 16000000000 * 10 ** 18;
    uint256 public constant MIN_SUPPLY_LIMIT = 870000000 * 10 ** 18;
    // Halving interval in seconds (default ~1 year)
    uint256 public halvingIntervalSeconds = 31536000;

    uint256 public constant WITHDRAWAL_WINDOW = 68700;
    uint256 public constant WITHDRAWAL_LIMIT_BP = 140; // 1.4%
    uint256 public constant OWNER_REWARD_BP = 1900;
    uint256 public constant BUSINESS_REWARD_BP = 1000;
    uint256 public constant CREATOR_REWARD_BP = 10;
    uint256 public constant RESERVE_FUND_BP = 5000;
    uint256 public constant CONSUMER_REWARD_BP = 2090;
    uint256 public constant PURCHASE_BURN_BP = 1500;
    uint256 public constant PURCHASE_BONUS_BP = 1190;
    // 15% + 11.90% + 73.10% = 100%; 75% would make the split 101.90%.
    uint256 public constant PURCHASE_SELLER_BP = 7310;
    uint256 public constant MODEL_SHARE_BP = OWNER_REWARD_BP;
    uint256 public constant OWNER_SHARE_BP = BUSINESS_REWARD_BP;
    uint256 public constant COMPANY_SHARE_BP = CREATOR_REWARD_BP;
    uint256 public constant SHARE_DIVISOR = DIVISOR;

    uint256 public lastHalvingTime;
    address public industryWallet;
    address public treasuryWallet;
    address public stakingContract;
    address public miningPool;
    bool public paused;
    address public timelock;
    uint256 public maxTransferPerTx;
    uint256 public transferFeeBp;
    bool public mintingEnabled = true;

    mapping(address => bool) public withdrawalSource;
    mapping(address => uint256) public withdrawalWindowStart;
    mapping(address => uint256) public withdrawalWindowStartBalance;
    mapping(address => uint256) public withdrawalWindowSpent;

    address public modelWallet;
    address public ownerFeeWallet;
    address public companyWallet;
    address public ownerRewardWallet;
    address public businessRewardWallet;
    address public reserveFundWallet;

    mapping(address => address) public creatorWalletOf;
    mapping(address => bool) public purchaseContract;
    mapping(address => bool) public bonusMerchant;
    mapping(address => uint256) public bonusBalance;

    struct Withdrawal {
        address account;
        address destination;
        uint256 amount;
        uint256 availableAt;
        bool cancelled;
        bool executed;
    }

    uint256 public nextWithdrawalId;
    mapping(uint256 => Withdrawal) public withdrawals;

    mapping(address => bool) public isExchange;

    event IndustryWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event TreasuryWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event StakingContractUpdated(address indexed previousContract, address indexed newContract);
    event MiningPoolUpdated(address indexed previousPool, address indexed newPool);
    event WithdrawalSourceUpdated(address indexed account, bool enabled);
    event PayoutWalletsUpdated(address indexed modelWallet, address indexed ownerWallet, address indexed companyWallet);
    event RewardWalletsUpdated(address indexed ownerReward, address indexed businessReward, address indexed reserveFund);
    event CreatorWalletUpdated(address indexed account, address indexed creatorWallet);
    event PurchaseContractUpdated(address indexed account, bool enabled);
    event BonusMerchantUpdated(address indexed account, bool enabled);
    event PurchaseProcessed(address indexed payer, address indexed seller, uint256 amount, uint256 burned, uint256 bonus, uint256 sellerAmount);
    event BonusSpent(address indexed account, address indexed merchant, uint256 amount);
    event WithdrawalRequested(uint256 indexed withdrawalId, address indexed account, address indexed destination, uint256 amount, uint256 availableAt);
    event WithdrawalCancelled(uint256 indexed withdrawalId);
    event WithdrawalExecuted(uint256 indexed withdrawalId);

    constructor(address _industryWallet, address _treasuryWallet)
        ERC20("RelaxCoin", "R2R")
        Ownable(msg.sender)
    {
        require(_industryWallet != address(0), "RelaxCoin: industry wallet zero");
        require(_treasuryWallet != address(0), "RelaxCoin: treasury wallet zero");

        _mint(msg.sender, 8000000000 * 10 ** decimals());
        industryWallet = _industryWallet;
        treasuryWallet = _treasuryWallet;
        ownerRewardWallet = msg.sender;
        businessRewardWallet = _industryWallet;
        reserveFundWallet = _treasuryWallet;
        lastHalvingTime = block.timestamp;
    }

    modifier whenNotPaused() {
        require(!paused, "RelaxCoin: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "RelaxCoin: not admin");
        _;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "RelaxCoin: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function setMaxTransferPerTx(uint256 amount) external onlyAdmin {
        maxTransferPerTx = amount;
    }

    function setTransferFee(uint256 feeBp) external onlyAdmin {
        require(feeBp <= DIVISOR, "RelaxCoin: fee too high");
        transferFeeBp = feeBp;
    }

    function disableMinting() external onlyAdmin {
        mintingEnabled = false;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0) && to != address(0), "RelaxCoin: invalid address");
        IERC20(token).transfer(to, amount);
    }

    function setIndustryWallet(address _industryWallet) external onlyOwner {
        require(_industryWallet != address(0), "RelaxCoin: industry wallet zero");
        emit IndustryWalletUpdated(industryWallet, _industryWallet);
        industryWallet = _industryWallet;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "RelaxCoin: treasury wallet zero");
        emit TreasuryWalletUpdated(treasuryWallet, _treasuryWallet);
        treasuryWallet = _treasuryWallet;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        emit StakingContractUpdated(stakingContract, _stakingContract);
        stakingContract = _stakingContract;
    }

    function setMiningPool(address _miningPool) external onlyOwner {
        emit MiningPoolUpdated(miningPool, _miningPool);
        miningPool = _miningPool;
    }

    // --- Tokenomics administration ---
    function setBurnPercent(uint256 bp) external onlyOwner {
        require(bp <= DIVISOR, "RelaxCoin: burn too high");
        burnPercent = bp;
    }

    function setHalvingIntervalSeconds(uint256 secs) external onlyOwner {
        require(secs >= 86400, "RelaxCoin: interval too small");
        halvingIntervalSeconds = secs;
    }

    function setIndustryTaxPercent(uint256 bp) external onlyOwner {
        require(bp <= DIVISOR, "RelaxCoin: tax too high");
        industryTaxPercent = bp;
    }

    function setWithdrawalSource(address account, bool enabled) external onlyOwner {
        withdrawalSource[account] = enabled;
        emit WithdrawalSourceUpdated(account, enabled);
    }

    function setExchangeAddress(address account, bool enabled) external onlyOwner {
        require(account != address(0), "RelaxCoin: zero address");
        isExchange[account] = enabled;
    }

    function _collectMiningFee(address from, uint256 amount) internal returns (uint256) {
        if (miningPool == address(0)) {
            return 0;
        }

        uint256 feeAmount = (amount * MINING_FEE_BP) / DIVISOR;
        if (feeAmount > 0) {
            _transfer(from, miningPool, feeAmount);
        }
        return feeAmount;
    }

    function _isWithdrawalSource(address account) internal view returns (bool) {
        return withdrawalSource[account] || isExchange[account] || account.code.length > 0;
    }

    function setPayoutWallets(address _modelWallet, address _ownerFeeWallet, address _companyWallet) external onlyOwner {
        require(_modelWallet != address(0), "RelaxCoin: model wallet zero");
        require(_ownerFeeWallet != address(0), "RelaxCoin: owner wallet zero");
        require(_companyWallet != address(0), "RelaxCoin: company wallet zero");

        modelWallet = _modelWallet;
        ownerFeeWallet = _ownerFeeWallet;
        companyWallet = _companyWallet;
        ownerRewardWallet = _modelWallet;
        businessRewardWallet = _ownerFeeWallet;
        emit PayoutWalletsUpdated(_modelWallet, _ownerFeeWallet, _companyWallet);
    }

    function setRewardWallets(address _ownerReward, address _businessReward, address _reserveFund) external onlyOwner {
        require(_ownerReward != address(0) && _businessReward != address(0) && _reserveFund != address(0), "RelaxCoin: reward wallet zero");
        ownerRewardWallet = _ownerReward;
        businessRewardWallet = _businessReward;
        reserveFundWallet = _reserveFund;
        emit RewardWalletsUpdated(_ownerReward, _businessReward, _reserveFund);
    }

    function setCreatorWallet(address account, address creatorWallet) external onlyOwner {
        require(account != address(0) && creatorWallet != address(0), "RelaxCoin: creator wallet zero");
        creatorWalletOf[account] = creatorWallet;
        emit CreatorWalletUpdated(account, creatorWallet);
    }

    function setPurchaseContract(address account, bool enabled) external onlyOwner {
        require(account != address(0), "RelaxCoin: purchase contract zero");
        purchaseContract[account] = enabled;
        emit PurchaseContractUpdated(account, enabled);
    }

    function setBonusMerchant(address account, bool enabled) external onlyOwner {
        require(account != address(0), "RelaxCoin: merchant zero");
        bonusMerchant[account] = enabled;
        emit BonusMerchantUpdated(account, enabled);
    }

    modifier onlyPurchaseContract() {
        require(purchaseContract[msg.sender], "RelaxCoin: caller is not purchase contract");
        _;
    }

    function purchase(address payer, address seller, uint256 amount) external onlyPurchaseContract whenNotPaused returns (bool) {
        require(payer != address(0) && seller != address(0), "RelaxCoin: purchase address zero");
        require(amount > 0, "RelaxCoin: purchase amount zero");

        _spendAllowance(payer, msg.sender, amount);
        _processPurchase(payer, seller, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        if (maxTransferPerTx != 0) {
            require(amount <= maxTransferPerTx, "RelaxCoin: transfer too large");
        }

        if (transferFeeBp == 0) {
            return super.transfer(to, amount);
        }

        address sender = _msgSender();
        uint256 fee = (amount * transferFeeBp) / DIVISOR;
        uint256 netAmount = amount - fee;
        _transfer(sender, treasuryWallet, fee);
        _transfer(sender, to, netAmount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        if (maxTransferPerTx != 0) {
            require(amount <= maxTransferPerTx, "RelaxCoin: transfer too large");
        }

        if (transferFeeBp == 0) {
            return super.transferFrom(from, to, amount);
        }

        uint256 fee = (amount * transferFeeBp) / DIVISOR;
        uint256 netAmount = amount - fee;

        bool success = super.transferFrom(from, treasuryWallet, fee);
        require(success, "RelaxCoin: fee transfer failed");
        success = super.transferFrom(from, to, netAmount);
        require(success, "RelaxCoin: transfer failed");
        return true;
    }

    function purchaseTransfer(address from, address to, uint256 amount) external onlyPurchaseContract returns (bool) {
        require(from != address(0) && to != address(0), "RelaxCoin: purchase address zero");
        require(amount > 0, "RelaxCoin: purchase amount zero");
        _spendAllowance(from, msg.sender, amount);
        super._update(from, to, amount);
        return true;
    }

    function systemTransfer(address to, uint256 amount) external onlyPurchaseContract returns (bool) {
        require(to != address(0), "RelaxCoin: transfer address zero");
        require(amount > 0, "RelaxCoin: transfer amount zero");
        super._update(_msgSender(), to, amount);
        return true;
    }

    function burnOnPurchase(uint256 amount) external onlyPurchaseContract returns (uint256 burned) {
        require(amount > 0, "RelaxCoin: purchase amount zero");
        burned = _burnPurchaseAmount(msg.sender, amount);
    }

    function burnOnPurchaseFrom(address account, uint256 amount) external onlyPurchaseContract returns (uint256 burned) {
        require(account != address(0), "RelaxCoin: account zero");
        require(amount > 0, "RelaxCoin: purchase amount zero");
        burned = _burnPurchaseAmount(account, amount);
    }

    function spendBonus(address merchant, uint256 amount) external returns (bool) {
        require(merchant != address(0), "RelaxCoin: merchant zero");
        require(bonusMerchant[merchant], "RelaxCoin: merchant not authorized");
        require(amount > 0 && bonusBalance[msg.sender] >= amount, "RelaxCoin: insufficient bonus");

        bonusBalance[msg.sender] -= amount;
        _update(address(this), merchant, amount);
        emit BonusSpent(msg.sender, merchant, amount);
        return true;
    }

    function _processPurchase(address payer, address seller, uint256 amount) internal {
        uint256 burned = _burnPurchaseAmount(payer, amount);
        uint256 bonus = (amount * PURCHASE_BONUS_BP) / DIVISOR;
        uint256 sellerAmount = amount - burned - bonus;

        bonusBalance[payer] += bonus;
        super._update(payer, address(this), bonus);
        super._update(payer, seller, sellerAmount);
        emit PurchaseProcessed(payer, seller, amount, burned, bonus, sellerAmount);
    }

    function _burnPurchaseAmount(address payer, uint256 amount) internal returns (uint256 burned) {
        burned = (amount * PURCHASE_BURN_BP) / DIVISOR;
        _burn(payer, burned);
    }

    function requestWithdrawal(address destination, uint256 amount) external whenNotPaused returns (uint256 withdrawalId) {
        require(destination != address(0), "RelaxCoin: destination zero");
        require(amount > 0, "RelaxCoin: withdrawal amount zero");

        if (_isWithdrawalSource(msg.sender)) {
            _enforceWithdrawalLimit(msg.sender, amount);
        }
        _update(msg.sender, address(this), amount);
        withdrawalId = ++nextWithdrawalId;
        withdrawals[withdrawalId] = Withdrawal({
            account: msg.sender,
            destination: destination,
            amount: amount,
            availableAt: block.timestamp + WITHDRAWAL_WINDOW,
            cancelled: false,
            executed: false
        });
        emit WithdrawalRequested(withdrawalId, msg.sender, destination, amount, block.timestamp + WITHDRAWAL_WINDOW);
    }

    function cancelWithdrawal(uint256 withdrawalId) external {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];
        require(withdrawal.account == msg.sender, "RelaxCoin: not withdrawal owner");
        require(!withdrawal.cancelled && !withdrawal.executed, "RelaxCoin: withdrawal closed");
        require(block.timestamp < withdrawal.availableAt, "RelaxCoin: withdrawal ready");

        withdrawal.cancelled = true;
        _update(address(this), msg.sender, withdrawal.amount);
        emit WithdrawalCancelled(withdrawalId);
    }

    function executeWithdrawal(uint256 withdrawalId) external whenNotPaused {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];
        require(!withdrawal.cancelled && !withdrawal.executed, "RelaxCoin: withdrawal closed");
        require(block.timestamp >= withdrawal.availableAt, "RelaxCoin: withdrawal delayed");

        withdrawal.executed = true;
        _update(address(this), withdrawal.destination, withdrawal.amount);
        emit WithdrawalExecuted(withdrawalId);
    }

    function _enforceWithdrawalLimit(address sender, uint256 amount) internal {
        if (block.timestamp >= withdrawalWindowStart[sender] + WITHDRAWAL_WINDOW) {
            withdrawalWindowStart[sender] = block.timestamp;
            withdrawalWindowStartBalance[sender] = balanceOf(sender);
            withdrawalWindowSpent[sender] = 0;
        }

        uint256 maxWithdraw = (withdrawalWindowStartBalance[sender] * WITHDRAWAL_LIMIT_BP) / DIVISOR;
        require(withdrawalWindowSpent[sender] + amount <= maxWithdraw, "RelaxCoin: withdrawal limit exceeded");
        withdrawalWindowSpent[sender] += amount;
    }

    modifier onlyMiningPool() {
        require(msg.sender == miningPool, "RelaxCoin: caller is not mining pool");
        _;
    }

    function mintForMining(address to, uint256 amount) external onlyMiningPool {
        require(mintingEnabled, "RelaxCoin: minting disabled");
        require(totalSupply() + amount <= MAX_TOTAL_SUPPLY, "RelaxCoin: max supply exceeded");
        _mint(to, amount);
    }

    function _checkAndApplyHalving() internal {
        if (burnPercent > 0 && block.timestamp >= lastHalvingTime + halvingIntervalSeconds) {
            burnPercent = burnPercent / 2;
            lastHalvingTime = block.timestamp;
        }
    }

    function _currentIndustryTaxPercent(address account) internal view returns (uint256) {
        uint256 defaultTax = industryTaxPercent;
        if (stakingContract != address(0)) {
            uint256 customTax = IR2RStaking(stakingContract).industryTaxPercentFor(account);
            if (customTax > 0 && customTax <= defaultTax) {
                return customTax;
            }
        }
        return defaultTax;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0) || from == address(this) || to == address(this)) {
            super._update(from, to, amount);
            return;
        }

        _checkAndApplyHalving();
        address creatorWallet = creatorWalletOf[to];
        if (creatorWallet == address(0)) creatorWallet = to;

        uint256 ownerReward = (amount * OWNER_REWARD_BP) / DIVISOR;
        uint256 businessReward = (amount * BUSINESS_REWARD_BP) / DIVISOR;
        uint256 creatorReward = (amount * CREATOR_REWARD_BP) / DIVISOR;
        uint256 reserveFund = (amount * RESERVE_FUND_BP) / DIVISOR;
        uint256 consumerReward = amount - ownerReward - businessReward - creatorReward - reserveFund;

        super._update(from, ownerRewardWallet, ownerReward);
        super._update(from, businessRewardWallet, businessReward);
        super._update(from, creatorWallet, creatorReward);
        super._update(from, reserveFundWallet, reserveFund);
        super._update(from, to, consumerReward);
    }
}
