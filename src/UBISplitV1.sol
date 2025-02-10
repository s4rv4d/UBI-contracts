// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";


contract UBISplitV1 is UUPSUpgradeable, Initializable {

    /// libraries
    using SafeTransferLib for address;
    using TokenUtils for address;

    /// errors

    /// structs

    /// events

    /// storage
    ERC20 public $BUILD;
    address public scoreContract;
    address public swapperContract;

    uint256 public vestingDuration;

    mapping(address => uint256) public userVesting;
    mapping (address=>uint256) public userWithdrawn;

    /// constructor and init
    constructor() {
        _disableInitializers();
    }

    function initialize(address _buildToken, address _passportAddress, address _swapperContract, uint256 _vestingTime) public initializer() {
        $BUILD = ERC20(_buildToken);
        scoreContract = _passportAddress;
        swapperContract = _swapperContract;
        vestingDuration = _vestingTime;
    }

    /// functions - view
    function vestedAmount() public view returns (uint256) {}

    /// functions - external
    function withdrawAllocation() external {}

    /// functions - auth
    function _authorizeUpgrade(address _newImplementation) internal override {}
}