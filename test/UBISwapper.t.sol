// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UBISwapper} from "../src/UBISwapper.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {IWETH9} from "splits-utils/src/interfaces/external/IWETH9.sol";

/// @dev A dummy implementation of ISwapRouter for testing purposes.
/// For our tests, the swap function simply returns the input amount.
contract DummySwapRouter is ISwapRouter {
    function swap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address recipient,
        bytes calldata data
    ) external payable override returns (uint256 outputAmount) {
        // Simply return the input amount; no actual swap logic.
        return inputAmount;
    }
}

/// @dev A minimal mock for WETH9. It allows deposits (minting WETH) and withdrawals.
contract MockWETH9 is IWETH9 {
    mapping(address => uint256) public override balanceOf;

    function deposit() external payable override {
        balanceOf[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 amount) external override {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    // Also accept ETH via the receive function.
    receive() external payable {
        deposit();
    }
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
        ubiswapper = new UBISwapper(dummySwapRouter, mockWETH9);

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

    /// @dev Test depositing ETH into UBISwapper.
    function testEthDeposit() public {
        uint256 depositAmount = 1 ether;

        // Send ETH directly to UBISwapper. This will trigger the receive() function.
        (bool success, ) = address(ubiswapper).call{value: depositAmount}("");
        require(success, "ETH deposit failed");

        // Verify that UBISwapper now holds the deposited ETH.
        assertEq(address(ubiswapper).balance, depositAmount, "Incorrect ETH balance in UBISwapper");
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

}