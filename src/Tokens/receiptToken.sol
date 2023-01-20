// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ReceiptToken is ERC20 {
    address internal poolAddress;
    address internal admin;
    string private _name;

    /**
     * @notice Emmitted after changeName function executed successfully
     * @param _newName The new changed name
     * @param _by The account address of the user who changed the name
     */
    event NameChanged(string _newName, address _by);
    /**
     * @notice Emmitted after setPoolAddress function executed successfully
     * @param _poolAddress The address of the pool
     */
    event PoolAddressUpdated(address _poolAddress);

    /**
     * @dev Only admin can call functions marked by this modifier.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    /**
     * @dev Only pool can call functions marked by this modifier.
     */
    modifier onlyPool() {
        require(msg.sender == poolAddress, "Only Pool");
        _;
    }

    /**
     * @notice a constructor used to initailize the necessary variables in the contract
     * @param _tokenName The name of the token
     * @param _symbol  The symbol of the token
     */
    constructor(string memory _tokenName, string memory _symbol) ERC20(_tokenName, _symbol) {
        admin = msg.sender;
        _name = _tokenName;
    }

    /**
     * @notice Used to get the name of the token
     * @return The name of the token
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    /**
     * @notice Changes the name of the token
     * @dev only called by the admin
     * @param _tokenName The new name of the token
     */

    function changeName(string memory _tokenName) external onlyAdmin {
        _name = _tokenName;
        emit NameChanged(_tokenName, msg.sender);
    }

    /**
     * @notice Mints specified amount of tokens
     * @dev only called from the Pool contract
     * @param _userAddress The address of the user
     * @param _mintAmount The amount of token to mint
     */
    function mint(address _userAddress, uint256 _mintAmount) external onlyPool {
        _mint(_userAddress, _mintAmount);
    }

    /**
     * @notice Burns specified amount of tokens
     * @dev only called from the pool contract
     * @param _userAddress The address of the user
     * @param _burnAmount The amount of token to be burned
     */
    function burn(address _userAddress, uint256 _burnAmount) external onlyPool {
        _burn(_userAddress, _burnAmount);
    }

    /**
     * @notice Sets the pool address
     * @dev only called by the admin
     * @param _poolAddress The address of the pool contract
     */
    function setPoolAddress(address _poolAddress) external onlyAdmin {
        require(_poolAddress != address(0), "Invalid address");
        poolAddress = _poolAddress;
        emit PoolAddressUpdated(poolAddress);
    }
}
