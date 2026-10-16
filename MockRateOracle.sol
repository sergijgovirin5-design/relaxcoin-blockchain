// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockRateOracle {
    mapping(address => uint256) public rates;
    mapping(address => uint256) public timestamps;

    function setRate(address currency, uint256 rateE18) external {
        rates[currency] = rateE18;
        timestamps[currency] = block.timestamp;
    }

    function rate(address currency) external view returns (uint256 rateE18, uint256 updatedAt) {
        return (rates[currency], timestamps[currency]);
    }
}
