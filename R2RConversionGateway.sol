// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Oracle interface. The backend must publish a signed/authorized rate on-chain.
interface IR2RRateOracle {
    function rate(address currency) external view returns (uint256 rateE18, uint256 updatedAt);
}

contract R2RConversionGateway is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BP = 50; // 0.5%
    uint256 public constant DIVISOR = 10000;
    uint256 public constant MAX_RATE_AGE = 1 hours;

    IERC20 public immutable r2rToken;
    address public oracle;
    address public feeWallet;
    bool public paused;
    address public timelock;
    uint256 public maxSlippageBp = 1000;
    mapping(address => bool) public supportedCurrency;

    event CurrencyUpdated(address indexed currency, bool supported);
    event OracleUpdated(address indexed oracle);
    event ConversionRequested(address indexed user, address indexed currency, uint256 r2rAmount, uint256 outputAmount, uint256 fee);

    constructor(IERC20 _r2rToken, address _oracle, address _feeWallet) Ownable(msg.sender) {
        require(address(_r2rToken) != address(0), "R2RConversion: token zero");
        require(_oracle != address(0) && _feeWallet != address(0), "R2RConversion: address zero");
        r2rToken = _r2rToken;
        oracle = _oracle;
        feeWallet = _feeWallet;
    }

    modifier whenNotPaused() {
        require(!paused, "R2RConversion: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "R2RConversion: not admin");
        _;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "R2RConversion: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0) && to != address(0), "R2RConversion: invalid address");
        IERC20(token).transfer(to, amount);
    }

    function setCurrency(address currency, bool supported) external onlyOwner {
        require(currency != address(0), "R2RConversion: currency zero");
        supportedCurrency[currency] = supported;
        emit CurrencyUpdated(currency, supported);
    }

    function setOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "R2RConversion: oracle zero");
        oracle = newOracle;
        emit OracleUpdated(newOracle);
    }

    function setFeeWallet(address newFeeWallet) external onlyAdmin {
        require(newFeeWallet != address(0), "R2RConversion: fee wallet zero");
        feeWallet = newFeeWallet;
    }

    function setMaxSlippage(uint256 newSlippageBp) external onlyAdmin {
        require(newSlippageBp <= DIVISOR, "R2RConversion: slippage too high");
        maxSlippageBp = newSlippageBp;
    }

    function withdrawFees(uint256 amount) external onlyAdmin {
        r2rToken.safeTransfer(feeWallet, amount);
    }

    /// @notice Converts R2R to an ERC20 representation of a fiat currency.
    /// @dev Fiat settlement itself remains off-chain; the oracle rate is on-chain input.
    function convert(address currency, uint256 r2rAmount, uint256 minOutput) external nonReentrant whenNotPaused returns (uint256 outputAmount) {
        require(supportedCurrency[currency], "R2RConversion: currency unsupported");
        require(r2rAmount > 0, "R2RConversion: amount zero");
        (uint256 rateE18, uint256 updatedAt) = IR2RRateOracle(oracle).rate(currency);
        require(rateE18 > 0 && block.timestamp - updatedAt <= MAX_RATE_AGE, "R2RConversion: stale rate");

        uint256 fee = (r2rAmount * FEE_BP) / DIVISOR;
        uint256 netAmount = r2rAmount - fee;
        outputAmount = (netAmount * rateE18) / 1e18;
        require(outputAmount >= minOutput, "R2RConversion: slippage");

        r2rToken.safeTransferFrom(msg.sender, feeWallet, fee);
        r2rToken.safeTransferFrom(msg.sender, address(this), netAmount);
        emit ConversionRequested(msg.sender, currency, r2rAmount, outputAmount, fee);
    }
}
