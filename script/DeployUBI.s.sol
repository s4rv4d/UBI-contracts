// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console2, console,  stdJson} from "forge-std/Script.sol";
import {UBISplitV1} from "../src/UBISplitV1.sol";
import {UBISwapper} from "../src/UBISwapper.sol";
import {UBISplitProxy} from "../src/UBISplitProxy.sol";
import {UBIRegistry} from "../src/UBIRegistry.sol";
import {IPassportBuilderScore} from "../src/interfaces/IPassportBuilderScore.sol";
import {IUBIRegistry} from "../src/interfaces/IUBIRegistry.sol";
import {DummySwapRouter} from "../test/utils/DummySwapRouter.sol";

contract DeployUBI is Script {

    using stdJson for string;

    address swapRouter;
    address weth9;
    address buildToken;
    address scoreContract;
    address owner;

    UBISwapper public ubiswapper;
    UBISplitProxy public splitProxy;
    UBISplitV1 public splitImplementation;
    IPassportBuilderScore public sContract;
    UBIRegistry public registry;

    function setUp() public {
        string memory json = readInput("inputs");

        swapRouter = json.readAddress(".swapRouter");
        weth9 = json.readAddress(".weth9");
        buildToken = json.readAddress(".buildToken");
        scoreContract = json.readAddress(".scoreContract");
        owner = json.readAddress(".owner");

        console.log("swap router: ", swapRouter);
        console.log("weth9: ", weth9);
        console.log("buildToken: ", buildToken);
        console.log("score contract: ", scoreContract);
        console.log("owner: ", owner);
    }

    function run() public {
        uint256 privKey = vm.envUint("PRIV_KEY");
        string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
        vm.createSelectFork(BASE_RPC_URL);
        vm.startBroadcast(privKey);

        // deploy split and proxy
        sContract = IPassportBuilderScore(scoreContract);

        registry = new UBIRegistry(address(scoreContract), 60);

        splitImplementation = new UBISplitV1();

        bytes memory data = abi.encodeWithSignature("initialize(address,address,uint256,uint256,uint256)", address(buildToken), address(registry), 100, 10, 7);
        splitProxy = new UBISplitProxy(address(splitImplementation), data);

        // deploy swapper
        UBISwapper.InitParams memory params = UBISwapper.InitParams({
            owner: owner,
            paused: false,
            beneficiary: address(splitProxy),
            tokenToBeneficiary: address(buildToken)
        });

        ubiswapper = new UBISwapper(DummySwapRouter(swapRouter), payable(weth9), params);

        console2.log("sContract: ", address(sContract));
        console2.log("splitImplementation: ", address(splitImplementation));
        console2.log("splitProxy: ", address(splitProxy));
        console2.log("ubiswapper: ", address(ubiswapper));
        console2.log("ubiregistry: ", address(registry));

        vm.stopBroadcast();
    }

    function readInput(string memory input) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(input, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }
}