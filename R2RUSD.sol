// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract R2RUSD is ERC20, Ownable {
    address public minter;

    event MinterUpdated(address indexed previousMinter, address indexed newMinter);

    constructor(address _minter) ERC20("RelaxCoin USD", "R2RUSD") Ownable(msg.sender) {
        require(_minter != address(0), "R2RUSD: minter zero");
        minter = _minter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "R2RUSD: caller is not minter");
        _;
    }

    function setMinter(address newMinter) external onlyOwner {
        require(newMinter != address(0), "R2RUSD: minter zero");
        emit MinterUpdated(minter, newMinter);
        minter = newMinter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
