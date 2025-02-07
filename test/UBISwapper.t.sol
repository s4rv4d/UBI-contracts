// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {UBISwapper} from "../src/UBISwapper.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

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
    function exactInput(ExactInputParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {

        lastParams = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: params.recipient,
            deadline: params.deadline,
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
    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        // For testing, we assume input equals output.
        return params.amountOut;
    }
    
    /// @notice Dummy implementation for the swap callback required by IUniswapV3SwapCallback.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // In a dummy implementation, we don't need to perform any logic.
    }
}

/// @dev A minimal mock for WETH9. It allows deposits (minting WETH) and withdrawals.
contract MockWETH9 is WETH {

}

/// @dev A simple ERC20 token that supports minting.
/// Inherits from solmate’s ERC20.
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev The Foundry test contract for UBISwapper.
contract UBISwapperTest is Test {
    UBISwapper public ubiswapper;
    DummySwapRouter public dummySwapRouter;
    MockWETH9 public mockWETH9;
    MockERC20 public mockERC20;

    // Define some test addresses.
    address public owner = address(1);
    address public beneficiary = address(2);
    // For the initializer we need to pass a token address.
    address public tokenBeneficiary = address(3);

    function setUp() public {
        // Use a different account for deployment and initialization.
        vm.startPrank(owner);

        // Deploy dummy external contracts.
        dummySwapRouter = new DummySwapRouter();
        mockWETH9 = new MockWETH9();

        // Deploy UBISwapper with the dummy swap router and WETH9.
        ubiswapper = new UBISwapper(dummySwapRouter, payable(mockWETH9));

        // Deploy a mock ERC20 token.
        mockERC20 = new MockERC20("Mock Token", "MTK");

        // Call the initializer. UBISwapper.InitParams expects:
        //  - owner (must match msg.sender during the call),
        //  - paused flag,
        //  - beneficiary address,
        //  - tokenToBeneficiary address.
        UBISwapper.InitParams memory params = UBISwapper.InitParams({
            owner: owner,
            paused: false,
            beneficiary: beneficiary,
            tokenToBeneficiary: address(mockERC20)
        });
        ubiswapper.initializer(params);

        // (Optionally) call setTokenToSwap to set the token used for swapping.
        // In our contract, this stores the token address for later use.
        ubiswapper.setTokenToSwap(address(mockERC20));
        vm.stopPrank();
    }

    /// @dev Test depositing ERC20 tokens into UBISwapper.
    function testERC20Deposit() public {
        uint256 mintAmount = 1000 * 1e18;

        // Mint tokens to the owner.
        mockERC20.mint(owner, mintAmount);

        // Transfer the minted tokens to UBISwapper.
        vm.startPrank(owner);
        // Using solmate's ERC20 transfer method.
        mockERC20.transfer(address(ubiswapper), mintAmount);
        vm.stopPrank();

        // Verify UBISwapper’s ERC20 balance.
        uint256 contractTokenBalance = mockERC20.balanceOf(address(ubiswapper));
        assertEq(contractTokenBalance, mintAmount, "Incorrect ERC20 balance in UBISwapper");
    }

    function testDepositAndSwapERC20() public {
        // Mint tokens to the caller.
        MockERC20 mockFromERC20 = new MockERC20("Mock2 Token", "MTK2");
        
        uint256 tokenAmount = 1000 * 1e18;
        mockFromERC20.mint(owner, tokenAmount);

        uint256 amountIn = 100 * 1e18;
        uint256 deadline = block.timestamp + 100;
        uint256 amountOutMinimum = 0;
        address recipient = address(5);

        vm.startPrank(owner);
        // // Build a swap path where the first token is the testToken.
        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(address(mockFromERC20), uint24(3000), address(mockWETH9) , uint24(3000), address(mockERC20)),
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        UBISwapper.SwapCallbackData memory swapCallbackData = UBISwapper.SwapCallbackData({
            exactInputParams: exactInputParams,
            recipient: recipient,
            isERC20: true,
            amountIn: amountIn
        });
        bytes memory data = abi.encode(swapCallbackData);

        // Approve UBISwapper to pull the tokens.
        mockFromERC20.approve(address(ubiswapper), amountIn);

        // Call deposit with zero ETH.
        ubiswapper.donate(data);

        // Verify that tokens were transferred from the caller to the UBISwapper contract.
        uint256 contractBalance = mockFromERC20.balanceOf(address(ubiswapper));
        assertEq(contractBalance, amountIn);

        // Verify that UBISwapper set the allowance for the swap router.
        uint256 allowance = mockFromERC20.allowance(address(ubiswapper), address(dummySwapRouter));
        assertEq(allowance, amountIn);
        vm.stopPrank();

        // Verify that the swap router was called with the correct parameters.
        (
            bytes memory recordedPath,
            address recordedRecipient,
            uint256 recordedDeadline,
            uint256 recordedAmountIn,
        ) = dummySwapRouter.lastParams();

        assertEq(recordedAmountIn, amountIn);
        assertEq(recordedRecipient, recipient);
        assertEq(recordedDeadline, deadline);

        // // Check that the start token in the path is the testToken.
        address tokenFromPath;
        assembly {
            tokenFromPath := mload(add(recordedPath, 0x14))
        }
        assertEq(tokenFromPath, address(mockFromERC20));
    }

    function testDepositAndSwapETH() public {
        uint256 amountIn = 1 ether;
        uint256 deadline = block.timestamp + 100;
        uint256 amountOutMinimum = 0;
        address recipient = address(5);

        vm.startPrank(owner);
        vm.deal(owner, 10 ether);
        // // Build a swap path where the first token is the testToken.
        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(address(mockWETH9) , uint24(3000), address(mockERC20)),
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        UBISwapper.SwapCallbackData memory swapCallbackData = UBISwapper.SwapCallbackData({
            exactInputParams: exactInputParams,
            recipient: recipient,
            isERC20: false,
            amountIn: amountIn
        });
        bytes memory data = abi.encode(swapCallbackData);

        ubiswapper.donate{value: amountIn}(data);

        // Verify that tokens were transferred from the caller to the UBISwapper contract.
        uint256 contractBalance = mockWETH9.balanceOf(address(ubiswapper));
        assertEq(contractBalance, amountIn);

        // Verify that UBISwapper set the allowance for the swap router.
        uint256 allowance = mockWETH9.allowance(address(ubiswapper), address(dummySwapRouter));
        assertEq(allowance, amountIn);
        vm.stopPrank();

        // Verify that the swap router was called with the correct parameters.
        (
            bytes memory recordedPath,
            address recordedRecipient,
            uint256 recordedDeadline,
            uint256 recordedAmountIn,
        ) = dummySwapRouter.lastParams();

        assertEq(recordedAmountIn, amountIn);
        assertEq(recordedRecipient, recipient);
        assertEq(recordedDeadline, deadline);

        // // Check that the start token in the path is the testToken.
        address tokenFromPath;
        assembly {
            tokenFromPath := mload(add(recordedPath, 0x14))
        }
        assertEq(tokenFromPath, address(mockWETH9));
    }

}