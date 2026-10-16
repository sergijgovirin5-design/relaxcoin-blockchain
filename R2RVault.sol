// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MyToken.sol";
import "./R2RUSD.sol";

contract R2RVault is Ownable {
    using SafeERC20 for IERC20;

    RelaxCoin public immutable r2rToken;
    R2RUSD public immutable stablecoin;

    uint256 public industryMarketCapUsd;
    uint256 public r2rUsdPrice;
    uint256 public totalCollateralR2R;
    uint256 public totalStableMinted;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant TARGET_RATIO = 1100;

    mapping(address => uint256) public collateralBalance;

    event CollateralDeposited(address indexed account, uint256 amountR2R);
    event CollateralWithdrawn(address indexed account, uint256 amountR2R);
    event IndustryMarketCapUpdated(uint256 previousCap, uint256 newCap);
    event R2RPriceUpdated(uint256 previousPrice, uint256 newPrice);
    event StableMinted(address indexed to, uint256 amountUsd);
    event StableBurned(address indexed from, uint256 amountUsd);

    constructor(RelaxCoin _r2rToken, R2RUSD _stablecoin, uint256 _initialR2RUsdPrice) Ownable(msg.sender) {
        require(address(_r2rToken) != address(0), "R2RVault: r2r zero");
        require(address(_stablecoin) != address(0), "R2RVault: stablecoin zero");
        require(_initialR2RUsdPrice > 0, "R2RVault: price zero");

        r2rToken = _r2rToken;
        stablecoin = _stablecoin;
        r2rUsdPrice = _initialR2RUsdPrice;
    }

    function depositR2R(uint256 amount) external {
        require(amount > 0, "R2RVault: amount zero");
        r2rToken.transferFrom(msg.sender, address(this), amount);
        totalCollateralR2R += amount;
        collateralBalance[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawR2R(uint256 amount) external {
        require(amount > 0, "R2RVault: amount zero");
        require(collateralBalance[msg.sender] >= amount, "R2RVault: insufficient collateral");
        require(totalCollateralR2R - amount >= minCollateralRequired(), "R2RVault: insufficient backed collateral");

        collateralBalance[msg.sender] -= amount;
        totalCollateralR2R -= amount;
        r2rToken.transfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function updateIndustryMarketCapUsd(uint256 newCapUsd) external onlyOwner {
        emit IndustryMarketCapUpdated(industryMarketCapUsd, newCapUsd);
        industryMarketCapUsd = newCapUsd;
    }

    function updateR2RPrice(uint256 newPriceUsd) external onlyOwner {
        require(newPriceUsd > 0, "R2RVault: price zero");
        emit R2RPriceUpdated(r2rUsdPrice, newPriceUsd);
        r2rUsdPrice = newPriceUsd;
    }

    function targetPoolUsd() public view returns (uint256) {
        return (industryMarketCapUsd * TARGET_RATIO) / BASIS_POINTS;
    }

    function collateralValueUsd() public view returns (uint256) {
        return (totalCollateralR2R * r2rUsdPrice) / 1e18;
    }

    function minCollateralRequired() public view returns (uint256) {
        return totalStableMinted == 0 ? 0 : (totalStableMinted * 1e18 + r2rUsdPrice - 1) / r2rUsdPrice;
    }

    function mintStable(address to, uint256 amountUsd) external onlyOwner {
        require(amountUsd > 0, "R2RVault: amount zero");
        require(totalStableMinted + amountUsd <= targetPoolUsd(), "R2RVault: target pool exceeded");
        require(collateralValueUsd() >= totalStableMinted + amountUsd, "R2RVault: insufficient collateral value");

        totalStableMinted += amountUsd;
        stablecoin.mint(to, amountUsd);
        emit StableMinted(to, amountUsd);
    }

    function burnStable(address from, uint256 amountUsd) external onlyOwner {
        require(amountUsd > 0, "R2RVault: amount zero");
        totalStableMinted -= amountUsd;
        stablecoin.burn(from, amountUsd);
        emit StableBurned(from, amountUsd);
    }
}
