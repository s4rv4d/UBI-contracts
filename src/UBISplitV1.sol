// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";
import {IPassportBuilderScore} from "./interfaces/IPassportBuilderScore.sol";

contract UBISplitV1 is UUPSUpgradeable, OwnableUpgradeable {
    /// libraries
    using SafeTransferLib for address;
    using TokenUtils for address;

    /// errors

    /// structs

    /// events
    event AllocationWithdraw(address _recipient, uint256 _amount);

    /// storage
    ERC20 public $BUILD;
    IPassportBuilderScore public scoreContract;
    address public swapperContract;

    uint256 public vestingDuration;

    mapping(address => uint256) public userVesting;
    mapping(address => uint256) public userWithdrawn;

    /// constructor and init
    constructor() {
        _disableInitializers();
    }

    function initialize(address _buildToken, address _passportAddress, address _swapperContract, uint256 _vestingTime)
        public
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        $BUILD = ERC20(_buildToken);
        scoreContract = IPassportBuilderScore(_passportAddress);
        swapperContract = _swapperContract;
        vestingDuration = _vestingTime;
    }

    /// functions - view
    /// @dev calculates how much is vested
    function vestedAmount(uint256 _allocation, uint256 _currentTimestamp, address _recipient)
        public
        returns (uint256)
    {
        // setup vestedDuration per user if not done the first time
        if (userVesting[_recipient] == 0) {
            userVesting[_recipient] = _currentTimestamp;
        }

        uint256 vestedStarting = userVesting[_recipient];

        // get elapsed diff
        uint256 elapsed = (_currentTimestamp + 1 seconds) - vestedStarting;

        if (elapsed >= vestingDuration) {
            return _allocation;
        }

        return (_allocation * elapsed) / vestingDuration;
    }

    /// functions - external
    function withdrawAllocation() external {
        address recipient = msg.sender;
        /// userAllocation = (userScore / totalScore) * totalRewardPool
        uint256 userAllocation = (scoreContract.getScoreByAddress(recipient) * $BUILD.balanceOf(address(this))) / 1000;
        // @audit-info add proper error
        require(userAllocation > 0, "No user allocation");

        uint256 allowed = vestedAmount(userAllocation, block.timestamp, recipient);
        uint256 withdrawable = allowed - userWithdrawn[recipient];
        // @audit-info add proper error
        require(withdrawable > 0, "Nothing to withdraw");

        userWithdrawn[recipient] += withdrawable;
        bool status = $BUILD.transfer(recipient, withdrawable);
        // @audit-info add proper error
        require(status, "Failed to withdraw $BUILD");

        emit AllocationWithdraw(recipient, withdrawable);
    }

    /// functions - upgrade
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
