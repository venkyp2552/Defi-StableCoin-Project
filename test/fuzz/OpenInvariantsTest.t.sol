// SPDX-License-Identifier: MIT

// // What are our invariants here?
// // 1. Total supply of DSC should be less than the total value of collateral
// // 2. Getter View functions should never revert <- evergreen invariant


// //Note this file is for understanding purpose not used in this project
pragma solidity ^0.8.18;

// ///home/venky2552/Defi-StableCoin-Project/lib/forge-std/src/StdInvariant.sol
// import {Test, console} from "lib/forge-std/src/Test.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine dsce;
//     HelperConfig config;
//     DecentralizedStableCoin dsc;
//     address weth;
//     address wbtc;

//     // Set up the environment
//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dsce, config) = deployer.run();
//         (,,weth, wbtc,) = config.activeNetwrokConfig();
//         // Set the target contract for invariant testing
//         targetContract(address(dsce)); // Ensure the contract is the DSCEngine contract
//     }

//     // Invariant to check that the protocol has more collateral value than the total DSC supply
//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = dsc.totalSupply();

//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
//         uint256 totalBthDeposited = IERC20(wbtc).balanceOf(address(dsce));

//         uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBthDeposited);
//         // Ensure that the total value of collateral is greater than or equal to the total DSC supply
//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
