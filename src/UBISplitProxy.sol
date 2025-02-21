// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UBISplitProxy is ERC1967Proxy {
    /// constructor
    constructor(address _implementation, bytes memory _data) payable ERC1967Proxy(_implementation, _data) {}
}
