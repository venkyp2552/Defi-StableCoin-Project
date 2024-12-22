// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol" ;
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script{
        address[] public tokenAddress;
        address[] public priceFeedAddress;

    function run() external returns(DecentralizedStableCoin,DSCEngine,HelperConfig){
        HelperConfig config=new HelperConfig();
        (address wethUsdPriceFeed,address wbtcUsdPriceFeed,address weth,address wbtc,uint256 deployerKey)=config.activeNetwrokConfig();
        tokenAddress=[weth,wbtc];
        priceFeedAddress=[wethUsdPriceFeed,wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc=new DecentralizedStableCoin();
        //Here we should pass tokenAddress and price Feed Address and dsc Address, dsc addresss will get from the above line.
        // to get token and oriceFeed address we are going to implement HelerConfig
        DSCEngine dscEngine=new DSCEngine(tokenAddress,priceFeedAddress,address(dsc)); 
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc,dscEngine,config);
    }

}