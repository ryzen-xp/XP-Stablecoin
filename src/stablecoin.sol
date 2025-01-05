// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/";

/*
*@title Stablecoin pegged with INR 
*Author: ryzen_xp (Sandeep chauhan)
*/

contract stablecoin is ERC20Burnable {
    constructor() ERC20("XPINR", "XP") {}

    error XPINR_amount_zero();
    error XPINR_balance_less();
    error XPINR_address_zero();

    function burn(uint256 _amount) public override onlyowner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert XPINR_amount_zero();
        }
        if (balance < _amount) {
            revert XPINR_balance_less();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyowner returns (bool) {
        if (_to == address(0)) {
            revert XPINR_address_zero();
        }
        if (_amount <= 0) {
            revert XPINR_amount_zero();
        }
        _mint(_to, _amount);
        return true;
    }
}
