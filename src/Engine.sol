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
     address[] allowedCollaterals ;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    error XP_amount_zero();
    error XP_not_equal_ratio();
    error XP_notAllowed_Token();
    error XP_transection_Failed();
    error XP_ZeroAddress();

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

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////                  Function
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

    // this deposit_colletral_mintXp is used to collect assest which user want to deposite in contract
    function deposit_colletral_mintXP(address collatreal_address, uint256 _amount, uint256 amountToXP_mint) external {
        deposite_collatreal(collatreal_address, _amount);
        mint_XP(amountToXP_mint);
    }

    // Redeem colletral  for some thing
    function redeem_colletral_for_XP(address collatreal_address, uint256 _amount_Collatreal, uint256 total_XP_burn)
        external
        moreThenZero(_amount_Collatreal)
        isAllowed_Token(collatreal_address)
    {
        burn_xp(total_XP_burn, msg.sender, msg.sender);
        _redeemCollateral(collatreal_address, _amount_Collatreal, msg.sender, msg.sender);
        // revertIfHealthFactorIsBroken(msg.sender);
    }

    // this mint_XP is use to mint the ERC20 token
    function mint_XP(uint256 _amount) private moreThenZero(_amount) returns (bool) {
        xp_minted[msg.sender] += _amount;

        bool status = i_XP.mint(msg.sender, _amount);
        return status;
    }

    // this burn_XP is use to burn minted token ERC20 from blockchain
    function burn_xp(address behalf, address _to, uint256 _amount) private moreThenZero(_amount) {
        xp_minted[behalf] -= _amount;
        emit XP_token_burned(behalf, _to, _amount);

        bool success = i_XP.transferFrom(_to, address(this), _amount);
        if (!success) {
            revert XP_transection_Failed();
        }

        i_XP.burn(_amount);
    }

    // liquidation function is here  this

    // function liquidate(address collatreal, address user, uint256 debt_to_cover)
    //     external
    //     isAllowed_Token(collatreal)
    //     moreThenZero(debt_to_cover)
    // {
    //     uint debt_USD  =

    // }

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

    function healthFactor(address user) public view returns (uint256) {
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
            int256 price = get_price_collatreal(collateral);
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
        returns (int256)
    {
        address price_feeder_address = mp_price_feed[collatreal_address];

        AggregatorV3Interface price_feeder = AggregatorV3Interface(price_feeder_address);

        (, int256 price,,,) = price_feeder.latestRoundData();

         return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }
}
