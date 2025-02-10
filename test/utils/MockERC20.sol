pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";


/// @dev A simple ERC20 token that supports minting.
/// Inherits from solmate’s ERC20.
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
