// SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {PausableImpl} from "splits-utils/src/PausableImpl.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/src/TokenUtils.sol";

contract UBISwapper is PausableImpl {
    /* -------------------------------------------------------------------------- */
    /*                                   Libraries                                */
    /* -------------------------------------------------------------------------- */
    using SafeTransferLib for address;
    using TokenUtils for address;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                   STRUCTS                                   */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev ETH/ERC20 deposited
    /// @param sender_ person depositing
    /// @param amount_ amount being deposited
    event Deposited(address indexed sender_, uint256 amount_);

    /// @dev setting beneficiary (ex: split contract)
    /// @param beneficiary_ address
    event SetBeneficiary(address indexed beneficiary_);

    /// @dev setting to swap from donated tokens
    /// @param tokenAddr_ address of token to swap to
    event SetTokenToSwap(address tokenAddr_);

    /* -------------------------------------------------------------------------- */
    /*                            CONSTANTS/IMMUTABLES                            */
    /* -------------------------------------------------------------------------- */

    /// @dev swap router used to swap
    ISwapRouter public immutable swapRouter;

    /// @dev reference to WETh
    WETH public immutable weth9;

    /// @dev reference to beneficiary
    address internal $beneficiary;

    /// @dev reference to token to final swap
    ERC20 internal $tokenToSwap;

    /* -------------------------------------------------------------------------- */
    /*                              CONSTRUCTOR                                   */
    /* -------------------------------------------------------------------------- */

    /// @param swapRouter_ v3 router addr 
    /// @param weth9_ weth addr
    /// @param params_ init params
    constructor(ISwapRouter swapRouter_, address payable weth9_, InitParams memory params_) {
        swapRouter = swapRouter_;
        weth9 = WETH(weth9_);

        // don't need to init wallet separately
        __initPausable({owner_: params_.owner, paused_: params_.paused});

        $beneficiary = params_.beneficiary;
        $tokenToSwap = ERC20(params_.tokenToBeneficiary);
    }

    /* -------------------------------------------------------------------------- */
    /*                          PUBLIC/EXTERNAL FUNCTIONS                         */
    /* -------------------------------------------------------------------------- */
    /// functions - onlyOwner
    
    /// @notice to be only called by owner
    /// @dev updates beneficiary
    /// @param beneficiary_ new beneficiary address
    function setBeneficiary(address beneficiary_) external onlyOwner {
        $beneficiary = beneficiary_;
        emit SetBeneficiary(beneficiary_);
    }

    /// @notice to be only called by owner
    /// @dev updates token for final swap
    /// @param token_ address of new token to update too
    function setTokenToSwap(address token_) external onlyOwner {
        $tokenToSwap = ERC20(token_);
        emit SetTokenToSwap(token_);
    }

    // functions - external

    /// @dev swap incoming ETH/ERC20 donations to $tokenToSwap
    /// @param swapCallbackData swap data
    function donate(SwapCallbackData calldata swapCallbackData) external payable pausable {

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
        uint256 amountDeposited = swapRouter.exactInput(eip);

        emit Deposited(msg.sender, amountDeposited);
    }

    /// functions - helpers

    /// @dev helper func to get first token in multi-hop path
    function _getStartTokenFromPath(bytes memory path) internal pure returns (address token) {
        assembly {
            token := mload(add(path, 0x14))
        }
    }
}
