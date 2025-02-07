  import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
  AggregatorV3Interface internal eth_usd_PriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

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

    function get_price_feed() public view returns (int256) {
        (, int256 eth_usd,,,) = eth_usd_PriceFeed.latestRoundData();

        return eth_usd / 1e18;
    }