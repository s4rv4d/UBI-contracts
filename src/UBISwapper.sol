// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {PausableImpl} from "splits-utils/src/PausableImpl.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";
import {WalletImpl} from "splits-utils/src/WalletImpl.sol";

contract UBISwapper is WalletImpl, PausableImpl {
    /// libraries
    using SafeTransferLib for address;
    using TokenUtils for address;

    /// errors

    /// structs
    struct InitParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
    }

    struct SwapCallbackData {
        ISwapRouter.ExactInputParams exactInputParams;
        address recipient;
        bool isERC20;
        uint256 amountIn;
    }

    /// events
    event DepositedERC20(address indexed sender_, uint256 amount_);
    event DepositedETH(address indexed sender_, uint256 amount_);
    event SetBeneficiary(address indexed beneficiary_);
    event SetTokenToSwap(address tokenAddr_);

    /// storage
    ISwapRouter public immutable swapRouter;
    WETH public immutable weth9;
    address internal $beneficiary;
    ERC20 internal $tokenToSwap;

    /// constructor and initializer
    constructor(ISwapRouter swapRouter_, address payable weth9_) {
        swapRouter = swapRouter_;
        weth9 = WETH(weth9_);
    }

    function initializer(InitParams calldata params_) external {
        // only swapperFactory may call `initializer`
        if (msg.sender != params_.owner) revert Unauthorized();

        // don't need to init wallet separately
        __initPausable({owner_: params_.owner, paused_: params_.paused});

        $beneficiary = params_.beneficiary;
        $tokenToSwap = ERC20(params_.tokenToBeneficiary);
    }

    /// functions - onlyOwner
    function setBeneficiary(address beneficiary_) external onlyOwner {
        $beneficiary = beneficiary_;
        emit SetBeneficiary(beneficiary_);
    }

    function setTokenToSwap(address token_) external onlyOwner {
        $tokenToSwap = ERC20(token_);
        emit SetTokenToSwap(token_);
    }

    // functions - external
    function donate(bytes calldata data_) external payable {
        SwapCallbackData memory swapCallbackData = abi.decode(data_, (SwapCallbackData));

        ISwapRouter.ExactInputParams memory eip = swapCallbackData.exactInputParams;
        address token = _getStartTokenFromPath(eip.path);

        if (msg.value != 0 && !swapCallbackData.isERC20) {
            // If ETH is sent, wrap it to WETH9 before proceeding.
            weth9.deposit{value: msg.value}();
        }

        if (swapCallbackData.isERC20) {
            ERC20(token).transferFrom(msg.sender, address(this), swapCallbackData.amountIn);
        }

        token.safeApprove(address(swapRouter), eip.amountIn);
        swapRouter.exactInput(eip);
    }

    /// functions - helpers
    function _getStartTokenFromPath(bytes memory path) internal pure returns (address token) {
        assembly {
            token := mload(add(path, 0x14))
        }
    }
}
