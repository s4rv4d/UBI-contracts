pragma solidity ^0.8.20;

import {WETH} from "solmate/tokens/WETH.sol";

/// @dev A minimal mock for WETH9. It allows deposits (minting WETH) and withdrawals.
contract MockWETH9 is WETH {}