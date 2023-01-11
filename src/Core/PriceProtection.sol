// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PriceProtection {
// This contract is responsible for price protection.
}

/**
 * @user posts the derivatives for call option
 * buyer can send a premium of 10% and buy with strike price until expiration date.
 * If buyer not buyed in expiration date or it is under strike price the asset sent back to the user or wothdraw any time
 */
