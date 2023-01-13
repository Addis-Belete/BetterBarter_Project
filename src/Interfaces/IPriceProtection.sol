// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceProtection {
    struct CollateralInfo {
        int256 priceInUSD;
        uint256 stakingPeriod;
        uint256 amount;
        uint256 initailTime;
        bool isLocked;
        uint256 callOptionId;
    }

    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod, uint256 callOptionId)
        external
        returns (bool, uint256, uint256);

    function unLockCollateral(address userAddress, uint256 collateralId) external returns (uint256);
    function getCollateralInfo(address userAddress, uint256 collateralId)
        external
        view
        returns (CollateralInfo memory);
}

interface ILPWallet {
    function transferLoan(uint256 ethPrice) external returns (uint256);
}
