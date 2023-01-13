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

    uint24 internal _poolFee = 3000;
    address internal wETH;
    address internal underlying;

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
            IERC20(_tokenIn).approve(address(router), _amount);
            uint256 amountOutMin = getAmountOutMinimum(_tokenIn, _tokenOut, _amount);

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
            if (_tokenIn == underlying) {
                IERC20(_tokenIn).approve(address(router), _amount);
                amount = router.exactInputSingle(params);
            } else {
                amount = router.exactInputSingle{value: _amount}(params);
            }
        } else {
            uint256 amountInMin = getAmountInMinimum(_tokenIn, _tokenOut, _amount);
            IERC20(_tokenIn).approve(address(router), _amount);
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

            (bool success,) = address(router).call{value: _amount}(
                abi.encodeWithSignature("exactOutputSingle(ExactOutputSingleParams)", _params)
            );
            require(success, "Failed");
            amount = amountInMin;
        }
        return amount;
    }

    function getAmountOutMinimum(address _tokenIn, address _tokenOut, uint256 _amountIn) private returns (uint256) {
        return qouter.quoteExactInputSingle(_tokenIn, _tokenOut, _poolFee, _amountIn, 0);
    }

    function getAmountInMinimum(address _tokenIn, address _tokenOut, uint256 _amountOut) private returns (uint256) {
        return qouter.quoteExactOutputSingle(_tokenIn, _tokenOut, _poolFee, _amountOut, 0);
    }
}
