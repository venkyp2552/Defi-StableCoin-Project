// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
/**
 * @title OracleLib
 * @author Venkaiah P
 * @notice This library used to check the chainlink oracle price Feed data
 * If the price is stale(unchange), the function should not call (revert) and render the DSCEnginee reusable-this is by design
 * We want DSCEnginee to freeze if the prics becomes unchanged.
 * So if the chainlink network explodesand you have a lot of money locked in protocal...its bad.
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
library OracleLib {
    error OracleLib__SatlePrice();

    uint256 private constant TIMEOUT=3 hours; //3 hours we are keep tracking if pricefeed not undpapted more than 3hrs the we cna revert
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns(
        uint80 ,
        int256 ,
        uint256 ,
        uint256 ,
        uint80
    )
    {
        (uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound)=priceFeed.latestRoundData();

        uint256 secondsSince=block.timestamp-updatedAt;
        if(secondsSince > TIMEOUT){
            revert OracleLib__SatlePrice();
        }
        return ( roundId,
        answer,
        startedAt,
        updatedAt,
        answeredInRound);
    }
}