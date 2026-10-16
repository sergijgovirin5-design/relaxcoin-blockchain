// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IR2RBonusCoin {
    function balanceOf(address account) external view returns (uint256);
    function purchaseTransfer(address from, address to, uint256 amount) external returns (bool);
    function systemTransfer(address to, uint256 amount) external returns (bool);
}

interface IR2RStakeView {
    function staked(address account) external view returns (uint256);
}

interface IR2RTokenFactoryRewards {
    function quoteCreatorBonus(address token, address creator, uint256 platformFeeAmount) external view returns (uint256);
    function payCreatorBonus(address token, address creator, uint256 platformFeeAmount) external returns (uint256);
}

contract R2RCreatedToken is ERC20 {
    uint256 public constant RECIPIENT_BPS = 7000;
    uint256 public constant CREATOR_BPS = 2100;
    uint256 public constant BPS = 10000;

    address public immutable creator;
    address public immutable feeRecipient;
    IR2RTokenFactoryRewards public immutable factory;

    event PaymentProcessed(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 recipientAmount,
        uint256 creatorAmount,
        uint256 platformAmount,
        uint256 r2rBonus
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 creatorSupply,
        uint256 feeSupply,
        address creator_,
        address feeRecipient_,
        address factory_
    ) ERC20(name_, symbol_) {
        require(creator_ != address(0), "R2RToken: creator zero");
        require(feeRecipient_ != address(0), "R2RToken: fee recipient zero");
        require(factory_ != address(0), "R2RToken: factory zero");
        creator = creator_;
        feeRecipient = feeRecipient_;
        factory = IR2RTokenFactoryRewards(factory_);
        _mint(creator_, creatorSupply);
        _mint(feeRecipient_, feeSupply);
    }

    function pay(address recipient, uint256 amount) external returns (bool) {
        require(amount > 0, "R2RToken: amount zero");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function previewTransfer(uint256 amount)
        external
        view
        returns (uint256 recipientAmount, uint256 creatorAmount, uint256 platformAmount, uint256 r2rBonus)
    {
        recipientAmount = Math.mulDiv(amount, RECIPIENT_BPS, BPS);
        creatorAmount = Math.mulDiv(amount, CREATOR_BPS, BPS);
        platformAmount = amount - recipientAmount - creatorAmount;
        r2rBonus = factory.quoteCreatorBonus(address(this), creator, platformAmount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        uint256 recipientAmount = Math.mulDiv(amount, RECIPIENT_BPS, BPS);
        uint256 creatorAmount = Math.mulDiv(amount, CREATOR_BPS, BPS);
        uint256 platformAmount = amount - recipientAmount - creatorAmount;

        super._update(from, to, recipientAmount);
        if (creatorAmount > 0) super._update(from, creator, creatorAmount);
        if (platformAmount > 0) super._update(from, feeRecipient, platformAmount);

        uint256 r2rBonus;
        if (platformAmount > 0) {
            r2rBonus = factory.payCreatorBonus(address(this), creator, platformAmount);
        }
        emit PaymentProcessed(from, to, amount, recipientAmount, creatorAmount, platformAmount, r2rBonus);
    }
}

contract R2RTokenFactory is Ownable, ReentrancyGuard {
    uint256 public constant COMMISSION_BPS = 3000;
    uint256 public constant BPS = 10000;
    uint256 private constant TOKEN_UNIT = 1e18;

    address public feeRecipient;
    IR2RBonusCoin public immutable r2rToken;
    IR2RStakeView public immutable stakingContract;
    mapping(address => bool) public isCreatedToken;
    mapping(address => uint256) public tokenR2RRateE18;
    mapping(address => address) public latestTokenByCreator;

    event TokenCreated(address indexed creator, address indexed token, string name, string symbol, uint256 supply, uint256 commission);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event TokenR2RRateUpdated(address indexed token, uint256 previousRateE18, uint256 newRateE18);
    event BonusPoolFunded(address indexed funder, uint256 amount, uint256 newBalance);
    event BonusPoolWithdrawn(address indexed recipient, uint256 amount, uint256 newBalance);
    event CreatorBonusPaid(address indexed token, address indexed creator, uint256 platformFeeAmount, uint256 r2rAmount, uint256 rateBps);

    constructor(address initialOwner, address initialFeeRecipient, address r2rToken_, address stakingContract_)
        Ownable(initialOwner)
    {
        require(initialFeeRecipient != address(0), "R2RFactory: recipient zero");
        require(r2rToken_ != address(0), "R2RFactory: R2R token zero");
        require(stakingContract_ != address(0), "R2RFactory: staking zero");
        feeRecipient = initialFeeRecipient;
        r2rToken = IR2RBonusCoin(r2rToken_);
        stakingContract = IR2RStakeView(stakingContract_);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "R2RFactory: recipient zero");
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setTokenR2RRate(address token, uint256 rateE18) external onlyOwner {
        require(isCreatedToken[token], "R2RFactory: unknown token");
        require(rateE18 > 0, "R2RFactory: rate zero");
        uint256 previousRate = tokenR2RRateE18[token];
        tokenR2RRateE18[token] = rateE18;
        emit TokenR2RRateUpdated(token, previousRate, rateE18);
    }

    function fundBonusPool(uint256 amount) external nonReentrant {
        require(amount > 0, "R2RFactory: amount zero");
        require(r2rToken.purchaseTransfer(msg.sender, address(this), amount), "R2RFactory: funding failed");
        emit BonusPoolFunded(msg.sender, amount, bonusPoolBalance());
    }

    function withdrawBonusPool(address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(recipient != address(0), "R2RFactory: recipient zero");
        require(amount > 0, "R2RFactory: amount zero");
        require(r2rToken.systemTransfer(recipient, amount), "R2RFactory: withdrawal failed");
        emit BonusPoolWithdrawn(recipient, amount, bonusPoolBalance());
    }

    function bonusPoolBalance() public view returns (uint256) {
        return r2rToken.balanceOf(address(this));
    }

    function creatorBonusBpsFor(address creator) public view returns (uint256) {
        uint256 stakeAmount = stakingContract.staked(creator);
        if (stakeAmount >= 5000 * TOKEN_UNIT) return 1400;
        if (stakeAmount >= 1000 * TOKEN_UNIT) return 1100;
        if (stakeAmount >= 500 * TOKEN_UNIT) return 800;
        if (stakeAmount >= 100 * TOKEN_UNIT) return 500;
        return 300;
    }

    function quoteCreatorBonus(address token, address creator, uint256 platformFeeAmount) public view returns (uint256) {
        uint256 rate = tokenR2RRateE18[token];
        if (!isCreatedToken[token] || rate == 0 || platformFeeAmount == 0) return 0;
        uint256 r2rValue = Math.mulDiv(platformFeeAmount, rate, TOKEN_UNIT);
        return Math.mulDiv(r2rValue, creatorBonusBpsFor(creator), BPS);
    }

    function payCreatorBonus(address token, address creator, uint256 platformFeeAmount)
        external
        nonReentrant
        returns (uint256 bonusAmount)
    {
        require(isCreatedToken[token], "R2RFactory: unknown token");
        require(msg.sender == token, "R2RFactory: caller is not token");
        require(tokenR2RRateE18[token] > 0, "R2RFactory: token rate not set");

        bonusAmount = quoteCreatorBonus(token, creator, platformFeeAmount);
        if (bonusAmount == 0) return 0;
        require(bonusPoolBalance() >= bonusAmount, "R2RFactory: insufficient R2R bonus pool");
        require(r2rToken.systemTransfer(creator, bonusAmount), "R2RFactory: bonus payment failed");
        emit CreatorBonusPaid(token, creator, platformFeeAmount, bonusAmount, creatorBonusBpsFor(creator));
    }

    function createToken(string calldata name_, string calldata symbol_, uint256 supply) external returns (address tokenAddress) {
        require(bytes(name_).length > 0 && bytes(name_).length <= 64, "R2RFactory: invalid name");
        require(bytes(symbol_).length > 0 && bytes(symbol_).length <= 12, "R2RFactory: invalid symbol");
        require(supply > 0, "R2RFactory: supply zero");

        uint256 commission = (supply / BPS) * COMMISSION_BPS
            + ((supply % BPS) * COMMISSION_BPS) / BPS;
        uint256 creatorSupply = supply - commission;
        R2RCreatedToken token = new R2RCreatedToken(
            name_,
            symbol_,
            creatorSupply,
            commission,
            msg.sender,
            feeRecipient,
            address(this)
        );
        tokenAddress = address(token);
        isCreatedToken[tokenAddress] = true;
        latestTokenByCreator[msg.sender] = tokenAddress;
        emit TokenCreated(msg.sender, tokenAddress, name_, symbol_, supply, commission);
    }
}
