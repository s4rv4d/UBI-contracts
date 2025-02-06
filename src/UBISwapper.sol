// SPDX-License-Identifier:UNIDENTIFIED
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {IWETH9} from "splits-utils/src/interfaces/external/IWETH9.sol";
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
    error Unauthorized();

    /// structs
    struct InitParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
    }

    struct SwapCallbackData {
        ISwapRouter.ExactInputParams[] exactInputParams;
        address recipient;
    }

    /// receive from weth9
    receive() external payable {}

    /// events
    event Deposited(address indexed sender_, uint245 amount_);
    event SetBeneficiary(address indexed beneficiary_);
    event SetTokenToSwap(address tokenAddr_);

    /// storage
    ISwapRouter public immutable swapRouter;
    IWETH9 public immutable weth9;
    address internal $beneficiary;
    ERC20 internal $tokenToSwap;

    /// constructor and initializer
    constructor(ISwapRouter swapRouter_, IWETH9 weth9_) {
        swapRouter = swapRouter_;
        weth9 = weth9_;
    }

    function initializer(InitParams calldata params_) external {
        // only swapperFactory may call `initializer`
        if (msg.sender != params_.owner) revert Unauthorized();

        // don't need to init wallet separately
        __initPausable({owner_: params_.owner, paused_: params_.paused});

        $beneficiary = params_.beneficiary;
        $tokenToBeneficiary = ERC20(params_.tokenToBeneficiary);
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
}