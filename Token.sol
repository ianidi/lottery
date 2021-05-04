// contracts/ERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.5.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Token is ERC20, ERC20Detailed, ERC20Burnable, Ownable {

    uint public initialSupply  = 100000000000; 

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Detailed(name_, symbol_, decimals_) public {
        _mint(msg.sender, initialSupply);
    }
}
