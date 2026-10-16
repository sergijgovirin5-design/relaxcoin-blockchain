// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title RelaxFast Token
/// @notice Fixed-supply ERC-20 with standard transfers and optional holder burns.
contract RelaxFastToken is ERC20, ERC20Burnable {
    uint256 public immutable initialSupply;

    constructor(uint256 wholeTokenSupply) ERC20("RelaxFast", "RFX") {
        require(wholeTokenSupply > 0, "RelaxFast: supply is zero");

        initialSupply = wholeTokenSupply * 10 ** decimals();
        _mint(msg.sender, initialSupply);
    }
}