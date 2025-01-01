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
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    address public USER=makeAddr('user');
    uint256 public constant AMOUNT_COLLATERAL=10 ether;
    uint256 public constant STARTING_ERC20_BALANCE=100 ether;
    function setUp() external {
        deployer= new DeployDSC();
        (dsc,dsce,config)=deployer.run();
        (wethUsdPriceFeed,wbtcUsdPriceFeed,weth,wbtc,)=config.activeNetwrokConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }
    //////////////////////////
    /// Constructor Test /////
    //////////////////////////
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function testRevertIfTokenLengthDoesntMatchPriceFeedLength() public {
        priceFeedAddress.push(wethUsdPriceFeed);
        // priceFeedAddress.push(wbtcUsdPriceFeed);
        tokenAddress.push(wbtc);
        tokenAddress.push(weth);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressesMustBeInSameLength.selector);
        new DSCEngine(tokenAddress,priceFeedAddress,address(dsc));
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
    
    // function testGetTokenAmountFromUsd() public view {
    //     uint256 usdAmount=100 ether;
    //     //$2000 / ETH , $100 
    //     //1000/2000=0.05;
    //    uint256 expectedWeth=0.05 ether;
    //    uint256 actualWeth=dsce.getTokenAmountFromUsd(weth,usdAmount);
    //    assertEq(expectedWeth,actualWeth);

    // }

    ///////////////////////////////
    /// DepositeCollateral Test ///
    ///////////////////////////////

    function testRevertIfCollateralZero() public {
       vm.startPrank(USER);
       ERC20Mock(weth).approve(address(dsce),AMOUNT_COLLATERAL);
       vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositeCollateral(weth,0);
        vm.stopPrank();
    }

    function testRevertsWithUnApprovedCollateral() public{
        ERC20Mock ranToken=new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositeCollateral(address(ranToken),AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce),AMOUNT_COLLATERAL);
        dsce.depositeCollateral(weth,AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    // function testCanDepositeCollateralAndGetAccountInfo() public depositedCollateral{
    //     (uint256 totalDSCMinted,uint256 collateralValueInUsd)=dsce.getAccountInformation(USER);
    //     uint256 expectedTotalDSCMinted=0;
    //     uint256
    // }



}