// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol" ;
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script{

    uint8 public constant DECIMALS=8;
    int256 public constant ETH_USD_PRICE=2000e8;
    int256 public constant BTC_USD_PRICE=1000e8;
    uint256 public constant DEFAULT_ANVIL_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig{
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth; //ETH Token Address is noting but deployed weth contract address(avalible in Etherscacn)
        address wbtc; //BTC Token Address is noting but deployed weth contract address (avalible in Etherscacn)
        uint256 deployerKey;
    }

    NetworkConfig public activeNetwrokConfig;

    constructor(){
        if(block.chainid==11155111){
            activeNetwrokConfig=getSepoliaEthConfig();
        }else{
            activeNetwrokConfig=getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            wethUsdPriceFeed:0x694AA1769357215DE4FAC081bf1f309aDC325306,// ETH/USD
            wbtcUsdPriceFeed:0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth:0xdd13E55209Fd76AfE204dBda4007C227904f0a81, // patrick created and he deployed address of weth token
            wbtc:0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey:vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        if(activeNetwrokConfig.wethUsdPriceFeed !=address(0)){
            return activeNetwrokConfig;
        }

        MockV3Aggregator ethUsdPriceFeed=new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        MockV3Aggregator btcUsdPriceFeed=new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
        ERC20Mock wethMock=new ERC20Mock();
        ERC20Mock wbtcMock=new ERC20Mock();

        return NetworkConfig({
            wethUsdPriceFeed:address(ethUsdPriceFeed),// ETH/USD
            wbtcUsdPriceFeed:address(btcUsdPriceFeed),
            weth:address(wethMock), // patrick created and he deployed address of weth token
            wbtc:address(wbtcMock),
            deployerKey:DEFAULT_ANVIL_KEY // run te anvil will get private key copy first one and use it here.
        });
    }
}