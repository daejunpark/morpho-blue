// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../InvariantTest.sol";

contract MorphoInvariantTest is InvariantTest {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    uint256 internal immutable MAX_PRICE_VARIATION = 0.4e18;

    address internal immutable USER;

    MarketParams[] internal allMarketParams;

    constructor() {
        USER = _addrFromHashedString("User");
    }

    function setUp() public virtual override {
        _weightSelector(this.setPrice.selector, 10);
        _weightSelector(this.setFeeNoRevert.selector, 5);
        _weightSelector(this.supplyAssetsOnBehalfNoRevert.selector, 100);
        _weightSelector(this.supplySharesOnBehalfNoRevert.selector, 100);
        _weightSelector(this.withdrawAssetsOnBehalfNoRevert.selector, 50);
        _weightSelector(this.borrowAssetsOnBehalfNoRevert.selector, 75);
        _weightSelector(this.repayAssetsOnBehalfNoRevert.selector, 35);
        _weightSelector(this.repaySharesOnBehalfNoRevert.selector, 35);
        _weightSelector(this.supplyCollateralOnBehalfNoRevert.selector, 100);
        _weightSelector(this.withdrawCollateralOnBehalfNoRevert.selector, 50);
        _weightSelector(this.liquidateSeizedAssetsNoRevert.selector, 5);
        _weightSelector(this.liquidateRepaidSharesNoRevert.selector, 5);

        super.setUp();

        allMarketParams.push(marketParams);

        for (uint256 i = 2; i <= 6; ++i) {
            MarketParams memory _marketParams = MarketParams({
                borrowableToken: address(borrowableToken),
                collateralToken: address(collateralToken),
                oracle: address(oracle),
                irm: address(irm),
                lltv: LLTV / i
            });

            vm.startPrank(OWNER);
            morpho.enableLltv(_marketParams.lltv);
            morpho.createMarket(_marketParams);
            vm.stopPrank();

            allMarketParams.push(_marketParams);
        }
    }

    function _targetSenders() internal virtual override {
        _targetSender(USER);
    }

    modifier authorized(address onBehalf) {
        if (onBehalf != msg.sender) {
            vm.prank(onBehalf);
            morpho.setAuthorization(msg.sender, true);
        }

        _;

        vm.prank(onBehalf);
        morpho.setAuthorization(msg.sender, false);
    }

    function _randomMarket(uint256 marketSeed) internal view returns (MarketParams memory _marketParams) {
        return allMarketParams[marketSeed % allMarketParams.length];
    }

    function _supplyAssets(MarketParams memory _marketParams, uint256 assets, address onBehalf)
        internal
        logCall("supplyAssets")
    {
        borrowableToken.setBalance(msg.sender, assets);

        vm.prank(msg.sender);
        morpho.supply(_marketParams, assets, 0, onBehalf, hex"");
    }

    function _supplyShares(MarketParams memory _marketParams, uint256 shares, address onBehalf)
        internal
        logCall("supplyShares")
    {
        (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = morpho.expectedMarketBalances(_marketParams);

        borrowableToken.setBalance(msg.sender, shares.toAssetsUp(totalSupplyAssets, totalSupplyShares));

        vm.prank(msg.sender);
        morpho.supply(_marketParams, 0, shares, onBehalf, hex"");
    }

    function _withdraw(
        MarketParams memory _marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal authorized(onBehalf) logCall("withdraw") {
        vm.prank(msg.sender);
        morpho.withdraw(_marketParams, assets, shares, onBehalf, receiver);
    }

    function _borrow(
        MarketParams memory _marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal authorized(onBehalf) logCall("borrow") {
        vm.prank(msg.sender);
        morpho.borrow(_marketParams, assets, shares, onBehalf, receiver);
    }

    function _repayAssets(MarketParams memory _marketParams, uint256 assets, address onBehalf)
        internal
        logCall("repayAssets")
    {
        borrowableToken.setBalance(msg.sender, assets);

        vm.prank(msg.sender);
        morpho.repay(_marketParams, assets, 0, onBehalf, hex"");
    }

    function _repayShares(MarketParams memory _marketParams, uint256 shares, address onBehalf)
        internal
        logCall("repayShares")
    {
        (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) = morpho.expectedMarketBalances(_marketParams);

        borrowableToken.setBalance(msg.sender, shares.toAssetsUp(totalBorrowAssets, totalBorrowShares));

        vm.prank(msg.sender);
        morpho.repay(_marketParams, 0, shares, onBehalf, hex"");
    }

    function _supplyCollateral(MarketParams memory _marketParams, uint256 assets, address onBehalf)
        internal
        logCall("supplyCollateral")
    {
        collateralToken.setBalance(msg.sender, assets);

        vm.prank(msg.sender);
        morpho.supplyCollateral(_marketParams, assets, onBehalf, hex"");
    }

    function _withdrawCollateral(MarketParams memory _marketParams, uint256 assets, address onBehalf, address receiver)
        internal
        authorized(onBehalf)
        logCall("withdrawCollateral")
    {
        vm.prank(msg.sender);
        morpho.withdrawCollateral(_marketParams, assets, onBehalf, receiver);
    }

    function _liquidateSeizedAssets(MarketParams memory _marketParams, address borrower, uint256 seizedAssets)
        internal
        logCall("liquidateSeizedAssets")
    {
        uint256 collateralPrice = oracle.price();
        uint256 repaidAssets =
            seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE).wDivUp(_liquidationIncentive(_marketParams.lltv));

        borrowableToken.setBalance(msg.sender, repaidAssets);

        vm.prank(msg.sender);
        morpho.liquidate(_marketParams, borrower, seizedAssets, 0, hex"");
    }

    function _liquidateRepaidShares(MarketParams memory _marketParams, address borrower, uint256 repaidShares)
        internal
        logCall("liquidateRepaidShares")
    {
        (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) = morpho.expectedMarketBalances(_marketParams);

        borrowableToken.setBalance(msg.sender, repaidShares.toAssetsUp(totalBorrowAssets, totalBorrowShares));

        vm.prank(msg.sender);
        morpho.liquidate(_marketParams, borrower, 0, repaidShares, hex"");
    }

    /* HANDLERS */

    function setPrice(uint256 variation) external {
        variation = bound(variation, WAD - MAX_PRICE_VARIATION, WAD + MAX_PRICE_VARIATION);

        uint256 currentPrice = oracle.price();

        oracle.setPrice(currentPrice.wMulDown(variation));
    }

    function setFeeNoRevert(uint256 marketSeed, uint256 newFee) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);
        Id _id = _marketParams.id();

        newFee = bound(newFee, 0, MAX_FEE);
        if (newFee == morpho.fee(_id)) return;

        vm.prank(OWNER);
        morpho.setFee(_marketParams, newFee);
    }

    function supplyAssetsOnBehalfNoRevert(uint256 marketSeed, uint256 assets, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomCandidate(targetSenders(), onBehalfSeed);

        assets = _boundSupplyAssets(_marketParams, USER, assets);
        if (assets == 0) return;

        _supplyAssets(_marketParams, assets, onBehalf);
    }

    function supplySharesOnBehalfNoRevert(uint256 marketSeed, uint256 shares, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomCandidate(targetSenders(), onBehalfSeed);

        shares = _boundSupplyShares(_marketParams, onBehalf, shares);
        if (shares == 0) return;

        _supplyShares(_marketParams, shares, onBehalf);
    }

    function withdrawAssetsOnBehalfNoRevert(uint256 marketSeed, uint256 assets, uint256 onBehalfSeed, address receiver)
        external
    {
        receiver = _boundAddressNotZero(receiver);

        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomSupplier(targetSenders(), _marketParams, onBehalfSeed);
        if (onBehalf == address(0)) return;

        assets = _boundWithdrawAssets(_marketParams, onBehalf, assets);
        if (assets == 0) return;

        _withdraw(_marketParams, assets, 0, onBehalf, receiver);
    }

    function borrowAssetsOnBehalfNoRevert(uint256 marketSeed, uint256 assets, uint256 onBehalfSeed, address receiver)
        external
    {
        receiver = _boundAddressNotZero(receiver);

        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomHealthyCollateralSupplier(targetSenders(), _marketParams, onBehalfSeed);
        if (onBehalf == address(0)) return;

        assets = _boundBorrowAssets(_marketParams, onBehalf, assets);
        if (assets == 0) return;

        _borrow(_marketParams, assets, 0, onBehalf, receiver);
    }

    function repayAssetsOnBehalfNoRevert(uint256 marketSeed, uint256 assets, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomBorrower(targetSenders(), _marketParams, onBehalfSeed);
        if (onBehalf == address(0)) return;

        assets = _boundRepayAssets(_marketParams, onBehalf, assets);
        if (assets == 0) return;

        _repayAssets(_marketParams, assets, onBehalf);
    }

    function repaySharesOnBehalfNoRevert(uint256 marketSeed, uint256 shares, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomBorrower(targetSenders(), _marketParams, onBehalfSeed);
        if (onBehalf == address(0)) return;

        shares = _boundRepayShares(_marketParams, onBehalf, shares);
        if (shares == 0) return;

        _repayShares(_marketParams, shares, onBehalf);
    }

    function supplyCollateralOnBehalfNoRevert(uint256 marketSeed, uint256 assets, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomCandidate(targetSenders(), onBehalfSeed);

        assets = _boundSupplyCollateralAssets(_marketParams, onBehalf, assets);
        if (assets == 0) return;

        _supplyCollateral(_marketParams, assets, onBehalf);
    }

    function withdrawCollateralOnBehalfNoRevert(
        uint256 marketSeed,
        uint256 assets,
        uint256 onBehalfSeed,
        address receiver
    ) external {
        receiver = _boundAddressNotZero(receiver);

        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address onBehalf = _randomHealthyCollateralSupplier(targetSenders(), _marketParams, onBehalfSeed);
        if (onBehalf == address(0)) return;

        assets = _boundWithdrawCollateralAssets(_marketParams, onBehalf, assets);
        if (assets == 0) return;

        _withdrawCollateral(_marketParams, assets, onBehalf, receiver);
    }

    function liquidateSeizedAssetsNoRevert(uint256 marketSeed, uint256 seizedAssets, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address borrower = _randomUnhealthyBorrower(targetSenders(), _marketParams, onBehalfSeed);
        if (borrower == address(0)) return;

        seizedAssets = _boundLiquidateSeizedAssets(_marketParams, borrower, seizedAssets);
        if (seizedAssets == 0) return;

        _liquidateSeizedAssets(_marketParams, borrower, seizedAssets);
    }

    function liquidateRepaidSharesNoRevert(uint256 marketSeed, uint256 repaidShares, uint256 onBehalfSeed) external {
        MarketParams memory _marketParams = _randomMarket(marketSeed);

        address borrower = _randomUnhealthyBorrower(targetSenders(), _marketParams, onBehalfSeed);
        if (borrower == address(0)) return;

        repaidShares = _boundLiquidateRepaidShares(_marketParams, borrower, repaidShares);
        if (repaidShares == 0) return;

        _liquidateRepaidShares(_marketParams, borrower, repaidShares);
    }

    /* INVARIANTS */

    function invariantSupplyShares() public {
        address[] memory users = targetSenders();

        uint256 sumSupplyShares;
        for (uint256 i; i < users.length; ++i) {
            sumSupplyShares += morpho.supplyShares(id, users[i]);
        }

        assertEq(sumSupplyShares, morpho.totalSupplyShares(id));
    }

    function invariantBorrowShares() public {
        address[] memory users = targetSenders();

        uint256 sumBorrowShares;
        for (uint256 i; i < users.length; ++i) {
            sumBorrowShares += morpho.borrowShares(id, users[i]);
        }

        assertEq(sumBorrowShares, morpho.totalBorrowShares(id));
    }

    function invariantTotalSupplyGeTotalBorrow() public {
        assertGe(morpho.totalSupplyAssets(id), morpho.totalBorrowAssets(id));
    }

    function invariantMorphoBalance() public {
        assertGe(
            borrowableToken.balanceOf(address(morpho)), morpho.totalSupplyAssets(id) - morpho.totalBorrowAssets(id)
        );
    }

    function invariantBadDebt() public {
        address[] memory users = targetSenders();

        for (uint256 i; i < users.length; ++i) {
            address user = users[i];

            for (uint256 j; j < allMarketParams.length; ++j) {
                MarketParams memory _marketParams = allMarketParams[j];
                Id _id = _marketParams.id();

                if (morpho.collateral(_id, user) == 0) assertEq(morpho.borrowShares(_id, user), 0);
            }
        }
    }
}
