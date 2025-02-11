// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {MockERC20} from "./utils/MockERC20.sol";
import {MockWETH9} from "./utils/MockWETH9.sol";

import {UBISwapper} from "../src/UBISwapper.sol";
import {UBISplitV1} from "../src/UBISplitV1.sol";
import {UBISplitProxy} from "../src/UBISplitProxy.sol";
import {IPassportBuilderScore} from "../src/interfaces/IPassportBuilderScore.sol";

contract UBISplitV1Test is Test {

    UBISplitProxy public splitProxy;
    UBISplitV1 public splitImplementation;
    IPassportBuilderScore public scoreContract;

    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    address SARVAD_ADDR = vm.envAddress("SARVAD_ADDR");
    MockERC20 TEST_BUILD_TOKEN = MockERC20(vm.envAddress("TEST_BUILD_TOKEN"));

    uint256 basefork;

    error NoAllocation(address _builder);

    function setUp() public {
        basefork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(basefork);

        scoreContract = IPassportBuilderScore(vm.envAddress("SCORE_CONTRACT"));

        splitImplementation = new UBISplitV1();
        bytes memory data = abi.encodeWithSignature("initialize(address,address,address,uint256)", address(TEST_BUILD_TOKEN), address(scoreContract), address(0),10 weeks);

        splitProxy = new UBISplitProxy(address(splitImplementation), data);

        vm.startPrank(SARVAD_ADDR);
        TEST_BUILD_TOKEN.transfer(address(splitProxy), 100 ether);
        vm.stopPrank();
    }

    function testScoreVerfication() public view {
        console.log("score is ", scoreContract.getScoreByAddress(SARVAD_ADDR));
        console.log("ERC20 bal is ", TEST_BUILD_TOKEN.balanceOf(SARVAD_ADDR));
        console.log("ERC20 bal of contract is ", TEST_BUILD_TOKEN.balanceOf(address(splitProxy)));
    }

    function testSplitWithdrawSuccess() public {
        vm.startPrank(SARVAD_ADDR);
        vm.warp(block.timestamp + 1 days);
        UBISplitV1(address(splitProxy)).withdrawAllocation();
        console.log("ERC20 bal is ", TEST_BUILD_TOKEN.balanceOf(SARVAD_ADDR));
        console.log("ERC20 bal of contract is ", TEST_BUILD_TOKEN.balanceOf(address(splitProxy)));
        vm.stopPrank();
    }

    function testSplitWithdrawFailure() public {
        vm.expectRevert(abi.encodeWithSelector(NoAllocation.selector, address(1)));
        vm.startPrank(address(1));
        vm.warp(block.timestamp + 1 days);
        UBISplitV1(address(splitProxy)).withdrawAllocation();
        console.log("ERC20 bal is ", TEST_BUILD_TOKEN.balanceOf(address(1)));
        vm.stopPrank();
    }
}