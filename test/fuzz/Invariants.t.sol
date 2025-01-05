// SPDX-License-Identifier: MIT

// What are our invariants here?
// 1. Total supply of DSC should be less than the total value of collateral
// 2. Getter View functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

///home/venky2552/Defi-StableCoin-Project/lib/forge-std/src/StdInvariant.sol
import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;
    Handler handler;

    // Set up the environment
    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,,weth, wbtc,) = config.activeNetwrokConfig();
        // Set the target contract for invariant testing
        // targetContract(address(dsce));

        //Now we areg oinf to target Handller contract to hndale the thungs in smooth way
        handler=new Handler(dsce,dsc);
        targetContract(address(handler));
        //Hey Don't call reedemCollateral, unless there is a collateral call trigger.(Like wise will implement the Handlers)
    }

    // Invariant to check that the protocol has more collateral value than the total DSC supply
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBthDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBthDeposited);
        console.log("Total Supply wethValue :",wethValue);
        console.log("Total Supply wbtcValue :",wbtcValue); 
        console.log("Total Supply totalSupply :",totalSupply); 
        console.log("Total Supply timesMintIsCalled :",handler.timesMintIsCalled());
        // Ensure that the total value of collateral is greater than or equal to the total DSC supply
        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view{
        dsce.getLiquidationBonus();
        dsce.getPrecision();
    }
}
