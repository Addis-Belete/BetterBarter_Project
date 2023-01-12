// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IUniswap.sol";

contract Exchange {
    ISwapRouter internal router;
    IQuoter internal qouter;

    constructor(address _routerAddress, address _qouterAddress) {
        router = ISwapRouter(_routerAddress);
        qouter = IQuoter(_qouterAddress);
    }

    uint24 public constant _poolFee = 3000;

    function swap(address _recipient, address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _deadline)
        internal
        returns (uint256)
    {
        //TransferHelper.safeApprove(tokenIn, address(router), _amountIn);
        IERC20(_tokenIn).approve(address(router), _amountIn);
        uint256 amountOutMin = getAmountAmountOutMinimum(_tokenIn, _tokenOut, _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _poolFee,
            recipient: _recipient,
            deadline: _deadline,
            amountIn: _amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = router.exactInputSingle(params);
        return amountOut;
    }

    function getAmountAmountOutMinimum(address _tokenIn, address _tokenOut, uint256 _amountIn)
        private
        returns (uint256)
    {
        uint256 amountOut = qouter.quoteExactInputSingle(_tokenIn, _tokenOut, _poolFee, _amountIn, 0);
        return amountOut;
    }
}
