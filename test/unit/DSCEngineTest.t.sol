// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineeTest is Test{
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    DeployDSC deployer;
    HelperConfig config;
    address wethUsdPriceFeed;
    address weth;
    address wbtc;
    address public USER=makeAddr('user');
    uint256 public constant AMOUNT_COLLATERAL=10 ether;
    uint256 public constant STARTING_ERC20_BALANCE=10 ether;
    function setUp() external {
        deployer= new DeployDSC();
        (dsc,dsce,config)=deployer.run();
        (wethUsdPriceFeed,,weth,wbtc,)=config.activeNetwrokConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }

    //////////////////////////
    /// Price Test Section ///
    //////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount=15e18;
        //15e18*500ETH(we can use nay value here to multiply)=30,000e18;
        uint256 expectdAmount=30000e18;
        uint256 actualUsd=dsce.getUsdValue(weth,ethAmount);
        console.log(actualUsd,expectdAmount);
        assertEq(expectdAmount,actualUsd);
    }

    ///////////////////////////////
    /// DepositeCollateral Test ///
    ///////////////////////////////

    function testRevertIfCollateralZer() public {
       vm.startPrank(USER);
       ERC20Mock(weth).approve(address(dsce),AMOUNT_COLLATERAL);
       vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositeCollateral(weth,0);
        vm.stopPrank();
    }

}