// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";

import {IPassportBuilderScore} from "./interfaces/IPassportBuilderScore.sol";

/// @title UBISplitV1
/// @author s4rv4d
/// @notice Split implemenation contract
contract UBISplitV1 is UUPSUpgradeable, OwnableUpgradeable {
    /* -------------------------------------------------------------------------- */
    /*                                   Libraries                                */
    /* -------------------------------------------------------------------------- */
    using SafeTransferLib for address;
    using TokenUtils for address;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev builder has no allocation to withdraw
    error NoAllocation(address _builder);
    
    /// @dev final calculation after withdraw is 0
    error NothingToWithdraw(address _builder);

    /// @dev withdrawal failed
    error FailedToWithdraw();

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev amount withdrawn by builder
    event AllocationWithdraw(address _recipient, uint256 _amount);

    /* -------------------------------------------------------------------------- */
    /*                            CONSTANTS/IMMUTABLES                            */
    /* -------------------------------------------------------------------------- */

    /// @dev BUILD contract
    ERC20 public constant $BUILD;

    /// @dev the contract to query builder score
    IPassportBuilderScore public constant scoreContract;

    /// @dev reference to UBISwapper contract
    address public constant swapperContract;

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev vesting duration for allocation withdrawal
    uint256 public vestingDuration;

    /// @dev user to vesting start mapping
    mapping(address => uint256) public userVesting;

    /// @dev mapping for how much user has withdrawn
    mapping(address => uint256) public userWithdrawn;

    /* -------------------------------------------------------------------------- */
    /*                           CONSTRUCTOR/ INIT                                */
    /* -------------------------------------------------------------------------- */
    constructor() {
        _disableInitializers();
    }

    /// @dev initializes UBISplit via proxy
    /// @param _buildToken address of BUILD token deposited
    /// @param _passportAddress address of passport registry to get address scores
    /// @param _swapperContract address of UBISwapper
    /// @param _vestingTime setting vesting time ex: 10 weeks
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

    /* -------------------------------------------------------------------------- */
    /*                          PUBLIC/EXTERNAL FUNCTIONS                         */
    /* -------------------------------------------------------------------------- */

    /// functions - view

    /// @dev get user allocation
    /// @param _recipient user for who allocation is being calculated for
    function getAllocation(address _recipient) public view returns (uint256) {
        /// @dev userAllocation = (userScore / totalScore) * totalRewardPool
        /// @audit the final 1000 is just to test needs to be replaced by totalScore via passport register/API
        uint256 userAllocation = (scoreContract.getScoreByAddress(recipient) * $BUILD.balanceOf(address(this))) / 1000;
        return userAllocation
    }

    /// @dev calculates how much is vested
    /// @param _allocation user allocation value
    /// @param _currentTimestamp block.timestamp
    /// @param _recipient reference to msg.sender
    function _vestedAmount(uint256 _allocation, uint256 _currentTimestamp, address _recipient)
        internal
        returns (uint256)
    {
        /// @dev setup vestedDuration per user if not done the first time
        if (userVesting[_recipient] == 0) {
            userVesting[_recipient] = _currentTimestamp;
        }

        uint256 vestedStarting = userVesting[_recipient];

        /// @dev adding 1 seconds so that elapsed is never 0 to avoid starting vesting edge case
        uint256 elapsed = (_currentTimestamp + 1 seconds) - vestedStarting;

        if (elapsed >= vestingDuration) {
            /// @dev if completed 10 weeks return what ever is remaining
            return _allocation;
        }

        /// @dev allowedWithdrawal = userAllocation * (elapsedTime / vestingDuration)
        return (_allocation * elapsed) / vestingDuration;
    }

    /// functions - external
    /// @dev function to withdraw/claim user allocation
    function withdrawAllocation() external {
        address recipient = msg.sender;
        uint256 userAllocation = getAllocation(recipient);
        require(userAllocation > 0, NoAllocation(recipient));

        uint256 allowed = _vestedAmount(userAllocation, block.timestamp, recipient);
        require(allowed > 0, NothingToWithdraw(recipient));

        /// @dev withdrawableAmount = allowedWithdrawal - withdrawn[msg.sender]
        uint256 withdrawable = allowed - userWithdrawn[recipient];
        require(withdrawable > 0, NothingToWithdraw(recipient));

        userWithdrawn[recipient] += withdrawable;
        bool status = $BUILD.transfer(recipient, withdrawable);
        require(status, FailedToWithdraw());

        emit AllocationWithdraw(recipient, withdrawable);
    }

    /* -------------------------------------------------------------------------- */
    /*                             onlyOwner FUNCTIONS                            */
    /* -------------------------------------------------------------------------- */
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
