// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IUniswap.sol";
import "forge-std/console2.sol";

contract Exchange {
    ISwapRouter internal router;
    IQuoter internal qouter;

    constructor(address _routerAddress, address _qouterAddress) {
        router = ISwapRouter(_routerAddress);
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
     * @param _deadline The time where the swap is expires
     * @return The call returns the number of output token
     */
    function swap(
        uint8 _type,
        address _recipient,
        address _tokenIn,
        address _tokenOut,
        uint256 _amount,
        uint256 _deadline
    ) public payable returns (uint256) {
        require(_type == 0 || _type == 1, "only 1 or 0");
        uint256 amount;
        if (_type == 0) {
            uint256 amountOutMin = getAmountOutMinimum(_tokenIn, _tokenOut, _amount);
            console2.log(amountOutMin, "Minimum amount Out");
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _poolFee,
                recipient: _recipient,
                deadline: _deadline,
                amountIn: _amount,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
            if (msg.value == 0) {
                IERC20(underlying).transferFrom(msg.sender, address(this), _amount);
                IERC20(_tokenIn).approve(address(router), _amount);
                console2.log(IERC20(_tokenIn).allowance(msg.sender, address(router)), "Router allowance");
                amount = router.exactInputSingle(params);
            } else {
                amount = router.exactInputSingle{value: _amount}(params);
            }
        } else {
            uint256 amountInMin = getAmountInMinimum(_tokenIn, _tokenOut, _amount);
            ISwapRouter.ExactOutputSingleParams memory _params = ISwapRouter.ExactOutputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _poolFee,
                recipient: _recipient,
                deadline: _deadline,
                amountOut: _amount,
                amountInMaximum: amountInMin,
                sqrtPriceLimitX96: 0
            });
            if (msg.value == 0) {
                IERC20(underlying).transferFrom(msg.sender, address(this), amountInMin);
                IERC20(_tokenIn).approve(address(router), amountInMin);
                console2.log(IERC20(_tokenIn).allowance(msg.sender, address(router)), "Router allowance");
                amount = router.exactOutputSingle(_params);
            } else {
                amount = router.exactOutputSingle{value: _amount}(_params);
            }
        }
        return amount;
    }

    /**
     * @notice Used to get the number of maximum tokens out for a given number of token in.
     * @param _tokenIn The address of input token
     * @param _tokenOut The address of 0utput token
     * @param _amountIn The number of token in
     */
    function getAmountOutMinimum(address _tokenIn, address _tokenOut, uint256 _amountIn) private returns (uint256) {
        return qouter.quoteExactInputSingle(_tokenIn, _tokenOut, _poolFee, _amountIn, 0);
    }

    /**
     * @notice Used to get the number of minimum tokens in for a given number of token out.
     * @param _tokenIn The address of input token
     * @param _tokenOut The address of 0utput token
     * @param _amountOut The number of token out
     */
    function getAmountInMinimum(address _tokenIn, address _tokenOut, uint256 _amountOut) public returns (uint256) {
        return qouter.quoteExactOutputSingle(_tokenIn, _tokenOut, _poolFee, _amountOut, 0);
    }
}
