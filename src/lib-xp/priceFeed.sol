// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract price_feeder {

   

    function get_price_feed(address chainlink_address) public view returns (int256) {
        
         AggregatorV3Interface  eth_usd_PriceFeed = AggregatorV3Interface(chainlink_address);

        (, int256 eth_usd,,,) = eth_usd_PriceFeed.latestRoundData();

        return eth_usd / 1e18;
    }
}
