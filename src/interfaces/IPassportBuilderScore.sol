// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

interface IPassportBuilderScore {
    /**
     * @notice Gets the score of a given address.
     * @param wallet The address to get the score for.
     * @return The score of the given address.
     */
    function getScoreByAddress(address wallet) external view returns (uint256);
}