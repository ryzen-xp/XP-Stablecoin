// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract XP_Engine  is Ownable(msg.sender){
  AggregatorV3Interface internal eth_usd_PriceFeed;
  AggregatorV3Interface internal inr_usd_PriceFeed;

  /**
 * Network: Sepolia
 * Data Feed: ETH/USD
 * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
 * 
 * Network : mainnet(ETH)
 * Data Feed : USD / INR 
 * Address : 0x605D5c2fBCeDb217D7987FC0951B5753069bC360
 */
constructor() {
  eth_usd_PriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306 );
  inr_usd_PriceFeed = AggregatorV3Interface(0x605D5c2fBCeDb217D7987FC0951B5753069bC360);

}

/**
 *get_price_feed()==>  return a int256  value 
 */



  function get_price_feed()public view returns(int256) {
    (, int256 eth_usd, , , ) = eth_usd_PriceFeed.latestRoundData();
    (, int256 inr_usd, , , ) = inr_usd_PriceFeed.latestRoundData();

       // Convert INR/USD to USD/INR
        int256 usdInrPrice = 1e18 / inr_usd;

        // ETH/INR = ETH/USD * USD/INR
        int256 ethInrPrice = (eth_usd * usdInrPrice) / 1e8;

        return ethInrPrice;

  }
  function deposit_colletral_mintXP() external {}

  function redeem_colletral_for_XP()external {}

  function burn_XP()external{}

  function liquidate()external{}

}
