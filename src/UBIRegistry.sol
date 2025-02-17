// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

/// libs
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// interfaces
import {IPassportBuilderScore} from "./interfaces/IPassportBuilderScore.sol";

/// @title UBIRegistry
/// @author s4rv4d
/// @notice UBI registry contract
contract UBIRegistry is Ownable {
    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev user registered
    event UserRegistered(address indexed _user, bool _status);

    /// @dev full allocation claimed
    event UpdatedAllocationStatus(address indexed _user, bool _status);

    /// @dev updated score threshold
    event UpdatedScorethreshold(uint256 _newScorethreshold);

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev the contract to query builder score
    IPassportBuilderScore public scoreContract;

    /// @dev score threshold
    uint256 public scoreThreshold;

    /// @dev is eligibility mapping
    mapping(address => bool) public isEligible;

    /// @dev has claimed full allocation mapping
    mapping(address => bool) public hasClaimedFullAlloc;

    /* -------------------------------------------------------------------------- */
    /*                           CONSTRUCTOR / INIT                               */
    /* -------------------------------------------------------------------------- */
    constructor(address _scoreContract, uint256 _scoreThreshold) Ownable(msg.sender) {
        scoreContract = IPassportBuilderScore(_scoreContract);
        scoreThreshold = _scoreThreshold;
    }

    /* -------------------------------------------------------------------------- */
    /*                          PUBLIC/EXTERNAL FUNCTIONS                         */
    /* -------------------------------------------------------------------------- */

    /// functions - view

    /// @dev check is recipient is eligible to claim according to logic
    /// @param _recipient user 
    /// @return eligibilitiy status of user
    function isUserEligible(address _recipient) public view returns (bool) {
        uint256 userScore = scoreContract.getScoreByAddress(_recipient);
        return isEligible[_recipient] && userScore >= scoreThreshold;
    }

    /// @dev check if user has claimed full allocation
    /// @param _recipient user
    /// @return claimed status of user
    function hasUserClaimed(address _recipient) public view returns (bool) {
        return hasClaimedFullAlloc[_recipient];
    }

    /// @dev get score threshold
    /// @return score threshold
    function getScoreThreshold() public view returns (uint256) {
        return scoreThreshold;
    }

    /// functions - external

    /// @dev updated full allocation claimed status
    /// @param _user status of user being updated
    /// @param _status boolean value indicating is user has claimed completley
    function updateUserClaimed(address _user, bool _status) external {
        hasClaimedFullAlloc[_user] = _status;

        emit UpdatedAllocationStatus(_user, _status);
    }
    
    /* -------------------------------------------------------------------------- */
    /*                             onlyOwner FUNCTIONS                            */
    /* -------------------------------------------------------------------------- */

    /// @dev add an eligible user with status
    /// @param _user user being added to the registry
    /// @param _status status of eligibility of the user
    function addEligibleUser(address _user, bool _status) external onlyOwner {
        isEligible[_user] = _status;

        emit UserRegistered(_user, _status);
    }

    /// @dev update score threshold
    /// @param _newScorethreshold updated score threshold
    function setScorethreshold(uint256 _newScorethreshold) external onlyOwner {
        scoreThreshold = _newScorethreshold;
        emit UpdatedScorethreshold(_newScorethreshold);
    }
}