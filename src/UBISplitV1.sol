// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {PausableImpl} from "splits-utils/src/PausableImpl.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";

import {IPassportBuilderScore} from "./interfaces/IPassportBuilderScore.sol";

/// @title UBISplitV1
/// @author s4rv4d
/// @notice Split implemenation contract
contract UBISplitV1 is UUPSUpgradeable, PausableImpl {
    /* -------------------------------------------------------------------------- */
    /*                                   Libraries                                */
    /* -------------------------------------------------------------------------- */
    using SafeTransferLib for address;
    using TokenUtils for address;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev withdrawal failed
    error FailedToWithdraw();

    /// @dev not enough balance
    error LessBUILDBalance();

    /// @dev doesnt meet score requirements
    error NotValidScore(address _recipient);

    /// @dev already claimed
    error ClaimedFullAllocation();

    /// @dev claimed early
    error ClaimedEarly();

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev amount withdrawn by builder
    event AllocationWithdraw(address _recipient, uint256 _amount);

    /// @dev updated claim amount
    event UpdatedClaimAmount(uint256 _newClaimAmount);

    /// @dev updated score threshold
    event UpdatedScorethreshold(uint256 _newScorethreshold);

    /// @dev updated claim amount
    event UpdatedClaimCount(uint256 _newClaimCount);

    /// @dev updated claim amount
    event UpdatedClaimInterval(uint256 _newClaimInterval);

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev BUILD contract
    ERC20 public $BUILD;

    /// @dev the contract to query builder score
    IPassportBuilderScore public scoreContract;

    /// @dev score threshold
    uint256 public scoreThreshold;

    /// @dev amount a user can claim
    uint256 public claimAmount;

    /// @dev amount of times user can claim
    uint256 public claimCount;

    /// @dev time between each claim
    uint256 public claimInterval;

    /// @dev mapping for how much user has withdrawn
    mapping(address => uint256) public userWithdrawn;

    /// @dev mapping to see if user has claimed his share
    mapping(address => uint256) public userDoneClaimCount;

    /// @dev mapping to see next date to claim
    mapping(address => uint256) public dateToClaimNext;

    /* -------------------------------------------------------------------------- */
    /*                           CONSTRUCTOR/ INIT                                */
    /* -------------------------------------------------------------------------- */
    constructor() {
        _disableInitializers();
    }

    /// @dev initializes UBISplit via proxy
    /// @param _buildToken address of BUILD token deposited
    /// @param _passportAddress address of passport registry to get address scores
    /// @param _scoreThreshold the score threshold to let eligible users claim
    /// @param _claimAmount the static claimable amount
    /// @param _claimCount the number of time a users can claim (ex: 10)
    /// @param _claimInterval time between each claim (ex: 10)
    function initialize(address _buildToken, address _passportAddress, uint256 _scoreThreshold, uint256 _claimAmount, uint256 _claimCount, uint256 _claimInterval)
        public
        initializer
    {

        __initPausable({owner_: msg.sender, paused_: false});
        __UUPSUpgradeable_init();

        $BUILD = ERC20(_buildToken);
        scoreContract = IPassportBuilderScore(_passportAddress);
        scoreThreshold = _scoreThreshold;
        claimAmount = _claimAmount;
        claimCount = _claimCount;
        claimInterval = _claimInterval;
    }

    /* -------------------------------------------------------------------------- */
    /*                          PUBLIC/EXTERNAL FUNCTIONS                         */
    /* -------------------------------------------------------------------------- */

    /// functions - view

    /// @dev get user claimed value
    /// @param _recipient user for who allocation is being calculated for
    function getClaimedAmount(address _recipient) public view returns (uint256) {
        return userWithdrawn[_recipient];
    }

    /// @dev get user next claim date
    /// @param _recipient user for who next date is being calculated for
    function getNextClaimDate(address _recipient) public view returns (uint256) {
        return dateToClaimNext[_recipient];
    }

    /// @dev get claim amount
    function getClaimAmount() public view returns (uint256) {
        return claimAmount;
    }

    /// @dev get score threshold
    function getScoreThreshold() public view returns (uint256) {
        return scoreThreshold;
    }

    /// @dev get claim count
    function getClaimCount() public view returns (uint256) {
        return claimCount;
    }

    /// @dev get claim interval
    function getClaimInterval() public view returns (uint256) {
        return claimInterval;
    }

    /// @dev check if user is eligible for claim
    /// @param _recipient user 
    function isValidUser(address _recipient) public view returns (bool) {
        uint256 userScore = scoreContract.getScoreByAddress(_recipient);
        return userScore >= scoreThreshold;
    }

    /// @dev get user allocation
    /// @param _recipient user 
    function getUserAllocation(address _recipient) public view returns (uint256) {

        if (!isValidUser(_recipient)) {
            return 0;
        }

        if (userDoneClaimCount[_recipient] >= claimCount) {
            return 0;
        }

        return claimAmount;
    }

    /// functions - external
    /// @dev function to withdraw/claim user allocation
    function withdrawAllocation() external {
        address recipient = msg.sender;
        uint256 userAllocation = claimAmount;

        /// checks
        if (!isValidUser(recipient)) {
            revert NotValidScore(recipient);
        }

        if (userDoneClaimCount[recipient] >= claimCount) {
            revert ClaimedFullAllocation();
        }

        if (block.timestamp < dateToClaimNext[recipient]) {
            revert ClaimedEarly();
        }

        if (userAllocation > $BUILD.balanceOf(address(this))) {
            revert LessBUILDBalance();
        }

        /// effects
        dateToClaimNext[recipient] = block.timestamp + (claimInterval * 1 days);
        userDoneClaimCount[recipient] += 1;
        userWithdrawn[recipient] += userAllocation;

        /// interaction
        bool status = $BUILD.transfer(recipient, userAllocation * $BUILD.decimals);
        if (!status) {
            revert FailedToWithdraw();
        }

        emit AllocationWithdraw(recipient, userAllocation);
    }

    /* -------------------------------------------------------------------------- */
    /*                             onlyOwner FUNCTIONS                            */
    /* -------------------------------------------------------------------------- */
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /// @dev update claim amount
    /// @param _newClaimAmount updated claim amount
    function setClaimAmount(uint256 _newClaimAmount) external onlyOwner {
        claimAmount = _newClaimAmount;
        emit UpdatedClaimAmount(_newClaimAmount);
    }

    /// @dev update score threshold
    /// @param _newScorethreshold updated score threshold
    function setScorethreshold(uint256 _newScorethreshold) external onlyOwner {
        scoreThreshold = _newScorethreshold;
        emit UpdatedScorethreshold(_newScorethreshold);
    }

    /// @dev update claim count
    /// @param _newClaimCount updated claim count
    function setClaimCount(uint256 _newClaimCount) external onlyOwner {
        claimCount = _newClaimCount;
        emit UpdatedClaimCount(_newClaimCount);
    }

    /// @dev update claim interval
    /// @param _newClaimInterval updated claim interval
    function setClaimInterval(uint256 _newClaimInterval) external onlyOwner {
        claimInterval = _newClaimInterval;
        emit UpdatedClaimInterval(_newClaimInterval);
    }
}
