// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title this is Stablecoin Engine  , its manages all functionality .
 * @author ryzen_xp
 * @notice
 */
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Stablecoin} from "./stablecoin.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract XP_Engine {
    constructor(address[] memory CollateralAddress, address[] memory price_feed_address, address xp_address) {
        if (CollateralAddress.length != price_feed_address.length) {
            revert XP_not_equal_ratio();
        } else {
            for (uint256 i = 0; i < CollateralAddress.length; i++) {
                mp_price_feed[CollateralAddress[i]] = price_feed_address[i];
            }
            i_XP = Stablecoin(xp_address);
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  state variable              //////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

    //  Stablecoin private immutable stablecoin ;
    Stablecoin private immutable i_XP;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    // Colletral   deposited by user  mapping
    mapping(address user => mapping(address colletralAddress => uint256 amount)) private mp_colletralDeposite;

    // Collatreal address which allowed
    mapping(address colletralAddress => address price_feed_address) private mp_price_feed;

    // User minted XP token mapping( user => amount_of_XPTokens ) : :
    mapping(address => uint256) private xp_minted;

    //  allowed collatreal address  fot this stable coin
    address[] private allowedCollaterals;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    error XP_amount_zero();
    error XP_not_equal_ratio();
    error XP_notAllowed_Token();
    error XP_transection_Failed();
    error XP_ZeroAddress();
    error XP__HealthFactorNotImproved();
    error XP_healthFactorGood();

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  Modifier
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

    modifier moreThenZero(uint256 _amount) {
        if (_amount == 0) {
            revert XP_amount_zero();
        }
        _;
    }

    modifier isAllowed_Token(address collatreal_address) {
        if (mp_price_feed[collatreal_address] == address(0)) {
            revert XP_notAllowed_Token();
        }
        _;
    }

    modifier isZeroAddress(address user) {
        if (user == address(0)) {
            revert XP_ZeroAddress();
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                   Events
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    event XP_deposited_collatreal(address user, address collatreal_address, uint256 _amount);
    event XP_Collatreal_Redeemed(address from, address to, address collatreal_address, uint256 amount);
    event XP_token_burned(address behalf, address to, uint256 amount);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        address indexed collatreal,
        uint256 debtCovered,
        uint256 collateralSeized
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  Function
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

    // this deposit_colletral_mintXp is used to collect assest which user want to deposite in contract
    function deposit_colletral_mintXP(address collatreal_address, uint256 amount, uint256 amountofXP_mint) external {
        deposite_collatreal(collatreal_address, amount);
        mint_XP(amountofXP_mint);
    }

    // Redeem colletral  for exchange of XP Token  that  minted for  the user 
    function redeem_colletral_for_XP(address collatreal_address, uint256 _amount_Collatreal, uint256 total_XP_burn)
        external
        moreThenZero(_amount_Collatreal)
        isAllowed_Token(collatreal_address)
    {
        burn_xp(msg.sender, msg.sender, total_XP_burn);
        _redeemCollateral(collatreal_address, _amount_Collatreal, msg.sender, msg.sender);
        // revertIfHealthFactorIsBroken(msg.sender);
    }

    // this mint_XP is use to mint the ERC20 token(XP Token )
    function mint_XP(uint256 _amount) private moreThenZero(_amount) returns (bool) {
        xp_minted[msg.sender] += _amount;
        bool status = i_XP.mint(msg.sender, _amount);
        return status;
    }

    // this burn_XP is use to burn minted token ERC20 from blockchain
    function burn_xp(address onBehalfof, address _to, uint256 _amount) private moreThenZero(_amount) {
        xp_minted[onBehalfof] -= _amount;
       
        bool success = i_XP.transferFrom(onBehalfof, address(this), _amount);
        if (!success) {
            revert XP_transection_Failed();
        }

        i_XP.burn(_amount);
         emit XP_token_burned(onBehalfof, _to, _amount);
    }

    // liquidation function is here  this

    function liquidate(address collatreal, address user, uint256 debt_to_cover)
        external
        isAllowed_Token(collatreal)
        moreThenZero(debt_to_cover)
    {
        uint256 startinguserHealthFactor = healthFactor(user);       
        if( startinguserHealthFactor < MIN_HEALTH_FACTOR){
            revert XP_healthFactorGood();
        }

        uint256 debt_in_usd = get_price_collatreal(collatreal) * debt_to_cover;

        uint256 bonusCollateral = (debt_in_usd * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        _redeemCollateral(collatreal, debt_in_usd + bonusCollateral, user, msg.sender);
        burn_xp(user, msg.sender, debt_to_cover);

        uint256 endingUserHealthFactor = healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startinguserHealthFactor) {
            revert XP__HealthFactorNotImproved();
        }

        // Emit an event for liquidation
        emit Liquidation(user, msg.sender, collatreal, debt_to_cover, debt_in_usd + bonusCollateral);
    }

    //  deposite_collatreal takes addres of asset and amount  to deposite  in this contract
    function deposite_collatreal(address collatreal_address, uint256 _amount)
        private
        moreThenZero(_amount)
        isAllowed_Token(collatreal_address)
        returns (bool)
    {
        mp_colletralDeposite[msg.sender][collatreal_address] += _amount;

        emit XP_deposited_collatreal(msg.sender, collatreal_address, _amount);

        bool success = IERC20(collatreal_address).transferFrom(address(msg.sender), address(this), _amount);

        return success;
    }

    function healthFactor(address user) private view returns (uint256) {
        uint256 totalCollateralValue = getTotalCollateralValue(user);
        uint256 totalDebt = xp_minted[user];

        if (totalDebt == 0) {
            return type(uint256).max; // No debt means an infinite health factor
        }

        uint256 collateralRatio = (totalCollateralValue * PRECISION) / totalDebt;

        return collateralRatio;
    }

    function getTotalCollateralValue(address user) public view returns (uint256 totalValue) {
        // Iterate through all collateral assets deposited by the user
        for (uint256 i = 0; i < allowedCollaterals.length; i++) {
            address collateral = allowedCollaterals[i];
            uint256 amount = mp_colletralDeposite[user][collateral];

            if (amount > 0) {
                uint256 price = get_price_collatreal(collateral);
                totalValue += (uint256(price) * amount) / PRECISION;
            }
        }
    }

    //  Redeem colletral
    function _redeemCollateral(address collatreal_address, uint256 _amount, address _from, address _to)
        private
        isAllowed_Token(collatreal_address)
    {
        mp_colletralDeposite[_from][collatreal_address] -= _amount;

        emit XP_Collatreal_Redeemed(_from, _to, collatreal_address, _amount);

        bool success = IERC20(collatreal_address).transfer(_to, _amount);

        if (success) {
            revert XP_transection_Failed();
        }
    }

    // Price feeder its return price of any colletreal by giving there collatreal_address

    function get_price_collatreal(address collatreal_address)
        public
        view
        isAllowed_Token(collatreal_address)
        returns (uint256)
    {
        address price_feeder_address = mp_price_feed[collatreal_address];

        AggregatorV3Interface price_feeder = AggregatorV3Interface(price_feeder_address);

        (, int256 price,,,) = price_feeder.latestRoundData();

        return uint256(price) / PRECISION;
    }


        function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
   
        return  allowedCollaterals;
    }

    function getDsc() external view returns (address) {
        return address(i_XP);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return mp_price_feed[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return healthFactor(user);
    }
}
