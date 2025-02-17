// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

interface IUBIRegistry {

    /// @notice check is recipient is eligible to claim according to logic
    /// @param _recipient user
    /// @return eligibilitiy status of user
    function isUserEligible(address _recipient) external view returns (bool);

    /// @notice check if user has claimed full allocation
    /// @param _recipient user
    /// @return claimed status of user
    function hasUserClaimed(address _recipient) external view returns (bool);

    
    /// @notice updated full allocation claimed status
    /// @param _user status of user being updated
    /// @param _status boolean value indicating is user has claimed completley
    function updateUserClaimed(address _user, bool _status) external;
}