// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Stablecoin} from "./stablecoin.sol";

import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract XP_Engine  {
  AggregatorV3Interface internal eth_usd_PriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306 );



constructor(address[] memory CollateralAddress , address[] memory price_feed_address , address xp_address ) {
  if( CollateralAddress.length != price_feed_address.length ){
    revert XP_not_equal_ratio();
  }
  else{
    for(uint i=0 ; i< CollateralAddress.length ; i++){
     xp_allowed_token[CollateralAddress[i]]= price_feed_address[i];

    }
    xp_token = xp_address;
  }
  
  
}



  function get_price_feed()public view returns(int256) {
    (, int256 eth_usd, , , ) = eth_usd_PriceFeed.latestRoundData();

    return eth_usd/1e18;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////                  state variable                           
////////////////////////////////////////////////////////////////////////////////////////////////////////

 Stablecoin private immutable stablecoin ;
 address private immutable xp_token ;



  // Colletral   deposited by user  mapping 
  mapping(address => mapping (address colletralAddress => uint amount)) private xp_colletralDeposite ;

  // Collatreal address which allowed 
  mapping(address colletralAddress =>address price_feed_address) private xp_allowed_token ;

  mapping (address => uint) private x_XPMinted ;
 

  ////////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////                  ERRORS                            
////////////////////////////////////////////////////////////////////////////////////////////////////////
        error  XP_amount_zero();
        error XP_not_equal_ratio();

  ////////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////                  Modifier                           
////////////////////////////////////////////////////////////////////////////////////////////////////////

  modifier  moreThenZero(uint _amount) {
    if(_amount == 0 ){
      revert XP_amount_zero() ;
    }
    _;    
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////                   Events                            
////////////////////////////////////////////////////////////////////////////////////////////////////////


  ////////////////////////////////////////////////////////////////////////////////////////////////////////
 ////////////////////                  Function                            
////////////////////////////////////////////////////////////////////////////////////////////////////////

  function deposit_colletral_mintXP() external {}

  function redeem_colletral_for_XP()external {}

  function mint_XP(uint _amount)external moreThenZero(_amount) returns(bool ){
  
      x_XPMinted[msg.sender] += _amount ;

     bool status =  stablecoin.mint(msg.sender , _amount );
     return status ;
  
   
  }

  function burn_XP()external{}

  function liquidate()external{}

}
