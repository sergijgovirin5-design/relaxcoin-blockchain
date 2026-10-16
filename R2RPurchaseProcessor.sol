// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IR2RPurchaseToken is IERC20 {
    function burnFrom(address account, uint256 value) external;
    function purchaseTransfer(address from, address to, uint256 amount) external returns (bool);
    function burnOnPurchaseFrom(address account, uint256 amount) external returns (uint256);
}

contract R2RPurchaseProcessor is Ownable, ReentrancyGuard {
    uint256 public constant DIVISOR = 10000;
    uint256 public constant PURCHASE_BURN_BP = 1500;
    uint256 public constant PURCHASE_BONUS_BP = 1000;
    uint256 public constant PURCHASE_SELLER_BP = 7500;

    IR2RPurchaseToken public immutable r2rToken;
    address public cardMerchant;
    bool public paused;
    address public timelock;

    mapping(address => uint256) public bonusBalance;
    mapping(address => bool) public purchaseCaller;

    event PurchaseProcessed(address indexed buyer, address indexed seller, uint256 amount, uint256 burned, uint256 bonus);
    event BonusAdded(address indexed user, uint256 amount);
    event BonusSpent(address indexed user, uint256 amount);
    event CardMerchantUpdated(address indexed previousMerchant, address indexed newMerchant);
    event PurchaseCallerUpdated(address indexed caller, bool enabled);

    constructor(IR2RPurchaseToken _r2rToken, address _cardMerchant) Ownable(msg.sender) {
        require(address(_r2rToken) != address(0), "R2RPurchase: token zero");
        require(_cardMerchant != address(0), "R2RPurchase: merchant zero");
        r2rToken = _r2rToken;
        cardMerchant = _cardMerchant;
    }

    modifier whenNotPaused() {
        require(!paused, "R2RPurchase: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "R2RPurchase: not admin");
        _;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "R2RPurchase: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0) && to != address(0), "R2RPurchase: invalid address");
        IERC20(token).transfer(to, amount);
    }

    function setCardMerchant(address newMerchant) external onlyOwner {
        require(newMerchant != address(0), "R2RPurchase: merchant zero");
        emit CardMerchantUpdated(cardMerchant, newMerchant);
        cardMerchant = newMerchant;
    }

    function setPurchaseCaller(address caller, bool enabled) external onlyOwner {
        require(caller != address(0), "R2RPurchase: caller zero");
        purchaseCaller[caller] = enabled;
        emit PurchaseCallerUpdated(caller, enabled);
    }

    function processPurchase(address seller, uint256 amount) external nonReentrant whenNotPaused returns (bool) {
        return _processPurchase(msg.sender, seller, amount);
    }

    function processPurchaseFor(address buyer, address seller, uint256 amount) external nonReentrant whenNotPaused returns (bool) {
        require(purchaseCaller[msg.sender], "R2RPurchase: caller not authorized");
        require(buyer != address(0), "R2RPurchase: buyer zero");
        return _processPurchase(buyer, seller, amount);
    }

    function _processPurchase(address buyer, address seller, uint256 amount) internal returns (bool) {
        require(seller != address(0), "R2RPurchase: seller zero");
        require(amount > 0, "R2RPurchase: amount zero");

        uint256 burned = (amount * PURCHASE_BURN_BP) / DIVISOR;
        uint256 bonus = (amount * PURCHASE_BONUS_BP) / DIVISOR;
        uint256 sellerAmount = amount - burned - bonus;

        r2rToken.burnOnPurchaseFrom(buyer, burned);
        require(r2rToken.purchaseTransfer(buyer, address(this), bonus), "R2RPurchase: bonus transfer failed");
        require(r2rToken.purchaseTransfer(buyer, seller, sellerAmount), "R2RPurchase: seller transfer failed");

        bonusBalance[buyer] += bonus;
        emit BonusAdded(buyer, bonus);
        emit PurchaseProcessed(buyer, seller, amount, burned, bonus);
        return true;
    }

    function spendBonus(uint256 amount) external nonReentrant whenNotPaused returns (bool) {
        require(amount > 0 && bonusBalance[msg.sender] >= amount, "R2RPurchase: insufficient bonus");
        bonusBalance[msg.sender] -= amount;
        require(r2rToken.purchaseTransfer(address(this), cardMerchant, amount), "R2RPurchase: card transfer failed");
        emit BonusSpent(msg.sender, amount);
        return true;
    }

    function refundPurchase(address buyer, uint256 amount) external nonReentrant onlyAdmin returns (bool) {
        require(buyer != address(0), "R2RPurchase: buyer zero");
        require(amount > 0, "R2RPurchase: amount zero");
        require(r2rToken.purchaseTransfer(address(this), buyer, amount), "R2RPurchase: refund failed");
        return true;
    }

    function getBonusBalance(address user) external view returns (uint256) {
        return bonusBalance[user];
    }
}
