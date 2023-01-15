// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory _tokenName, string memory _symbol) ERC20(_tokenName, _symbol) {}

    function mint(address _userAddress, uint256 _mintAmount) external {
        _mint(_userAddress, _mintAmount);
    }
}
