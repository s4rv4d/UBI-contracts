pragma solidity ^0.8.20;

import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

/// @dev A dummy implementation of ISwapRouter for testing purposes.
/// For our tests, the swap function simply returns the input amount.
contract DummySwapRouter is ISwapRouter {
    ISwapRouter.ExactInputParams public lastParams;
    uint256 public amountOutToReturn;

    /// @notice Implements a dummy 1:1 swap for exactInputSingle.
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // For testing, we simply return the input amount as output.
        return amountOutToReturn;
    }

    /// @notice Implements a dummy 1:1 swap for exactInput.
    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        lastParams = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: params.recipient,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum
        });

        // For testing, we simply return the input amount as output.
        return amountOutToReturn;
    }

    /// @notice Implements a dummy 1:1 swap for exactOutputSingle.
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        // For testing, we assume input equals output.
        return params.amountOut;
    }

    /// @notice Implements a dummy 1:1 swap for exactOutput.
    function exactOutput(ExactOutputParams calldata params) external payable override returns (uint256 amountIn) {
        // For testing, we assume input equals output.
        return params.amountOut;
    }

    /// @notice Dummy implementation for the swap callback required by IUniswapV3SwapCallback.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        // In a dummy implementation, we don't need to perform any logic.
    }
}