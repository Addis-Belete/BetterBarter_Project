// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IUniswap.sol";
import "forge-std/console2.sol";

contract Exchange {
    IQuoter internal qouter;
    ISwapRouterV2 internal routerV2;
    address internal WETH;

    constructor(address _routerAddress, address _qouterAddress) {
        routerV2 = ISwapRouterV2(_routerAddress);
        qouter = IQuoter(_qouterAddress);
    }

    uint24 internal _poolFee = 3000;
    address internal wETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // WETH Address on polygon network
    address internal underlying = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; //USDC address on polygon network

    /**
     * @notice Used to swap one tokens to anather tokens.
     * @param _type 0 for exact input and 1 for exact output
     * @param _recipient The address of swapped token receiver
     * @param _tokenIn The address of input token
     * @param _tokenOut The address of 0utput token
     * @param _amount The number of token in for type 0 or the number of token out for type 1
     * @return The call returns the number of output token
     */
    function swap(uint8 _type, address _recipient, address _tokenIn, address _tokenOut, uint256 _amount)
        public
        payable
        returns (uint256)
    {
        require(_type == 0 || _type == 1, "only 1 or 0");
        uint256 amount;
        if (_type == 0) {
            uint256[] memory amountOutMin = getAmountOutMinimum(_tokenIn, _tokenOut, _amount);
            console2.log(amountOutMin[1], "Minimum amount Out");
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
            IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amount);
            IERC20(_tokenIn).approve(address(routerV2), _amount);
            routerV2.swapExactTokensForTokens(_amount, amountOutMin[1], path, _recipient, block.timestamp);
        } else {
            uint256[] memory amountInMax = getAmountInMaximum(_tokenIn, _tokenOut, _amount);
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
            IERC20(_tokenIn).transferFrom(msg.sender, address(this), amountInMax[0]);
            IERC20(_tokenIn).approve(address(routerV2), amountInMax[0]);
            routerV2.swapTokensForExactTokens(_amount, amountInMax[0], path, _recipient, block.timestamp);
        }
        return amount;
    }

    /**
     * @notice Used to swap Ether to another token
     * 	@param _type 0 to swap from ETH to exact token and 1 from Exact token to Eth
     * @param _recipient The address of swapped token receiver
     * @param _tokenIn The address WETH
     * @param _tokenOut The address of Output token
     * @param _amount The number of token in for type 0 or the number of token out for type 1
     * @return The call returns the number of output token
     */
    function swapETH(uint8 _type, address _recipient, address _tokenIn, address _tokenOut, uint256 _amount)
        public
        payable
        returns (uint256)
    {
        require(_type == 0 || _type == 1, "only 1 or 0");
        if (_type == 0) {
            uint256[] memory amountOutMin = getAmountInMaximum(_tokenIn, _tokenOut, _amount);
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
            uint256[] memory val =
                routerV2.swapETHForExactTokens{value: msg.value}(amountOutMin[1], path, _recipient, block.timestamp);
            return val[0];
        } else {
            uint256[] memory amountOutMin = getAmountOutMinimum(_tokenIn, _tokenOut, _amount);
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
            IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amount);
            IERC20(_tokenIn).approve(address(routerV2), _amount);
            uint256[] memory val =
                routerV2.swapExactTokensForETH(_amount, amountOutMin[0], path, _recipient, block.timestamp);
            return val[1];
        }
    }
    /**
     * @notice Used to get the number of maximum tokens out for a given number of token in.
     * @param _tokenIn The address of input token
     * @param _tokenOut The address of 0utput token
     * @param _amountIn The number of token in
     */

    function getAmountOutMinimum(address _tokenIn, address _tokenOut, uint256 _amountIn)
        public
        view
        returns (uint256[] memory amounts)
    {
        //  return qouter.quoteExactInputSingle(_tokenIn, _tokenOut, _poolFee, _amountIn, 0);
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        amounts = routerV2.getAmountsOut(_amountIn, path);
    }

    /**
     * @notice Used to get the number of minimum tokens in for a given number of token out.
     * @param _tokenIn The address of input token
     * @param _tokenOut The address of 0utput token
     * @param _amountOut The number of token out
     */
    function getAmountInMaximum(address _tokenIn, address _tokenOut, uint256 _amountOut)
        public
        view
        returns (uint256[] memory amounts)
    {
        //  return qouter.quoteExactOutputSingle(_tokenIn, _tokenOut, _poolFee, _amountOut, 0);
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        amounts = routerV2.getAmountsIn(_amountOut, path);
    }
}
