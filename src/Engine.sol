// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Stablecoin} from "./stablecoin.sol";

import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract XP_Engine  is Stablecoin {
  AggregatorV3Interface internal eth_usd_PriceFeed;
  AggregatorV3Interface internal inr_usd_PriceFeed;

  /**
 * Network: Sepolia
 * Data Feed: ETH/USD
 * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
 * 
 */

constructor() {
  eth_usd_PriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306 );
  
}

// state varible is here  



// here is mapping 


// error is here 


// event  is  here 





/**
 * get_price_feed   return ETH->USD price 
 *   
 */

  function get_price_feed()public view returns(int256) {
    (, int256 eth_usd, , , ) = eth_usd_PriceFeed.latestRoundData();

    return eth_usd ;
  }

  function deposit_colletral_mintXP() external {}

  function redeem_colletral_for_XP()external {}

  function mint_XP(uint _amount)external view onlyOwner returns(bool ){
    if(_amount <=0){
      revert XPINR_amount_zero();
    }
    Stablecoin.mint(msg.sender , _amount);
  }

  function burn_XP()external{}

  function liquidate()external{}

}
