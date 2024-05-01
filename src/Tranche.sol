// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./interfaces/ITradingStorage.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Tranche is ERC4626Upgradeable {
    using MathUpgradeable for uint256;

    uint private constant _PRECISION = 1e10;

    IVaultManager public vaultManager;
    address public veTranche;
    uint256 public totalReserved;
    uint256 public withdrawThreshold;
    uint256 public totalPrincipalDeposited;
    uint256 public depositCap;
    bool public feesOn;

    mapping(address => uint256) public principalSharesDeposited;
    mapping(address => uint256) public principalAssetsDeposited;

    event FeesStatusUpdated(bool feesOn);
    event VeTrancheUpdated(address indexed veTranche);
    event VaultManagerUpdated(address indexed vaultManager);
    event WithdrawThresholdUpdated(uint256 newThreshold);
    event BalanceReserved(uint256 amount);
    event BalanceReleased(uint256 amount);
    event ReserveCapUpdated(uint256 newCap);
    event TokenTransferred(address indexed from, address indexed to, uint256 shares, uint256 assets);

    modifier onlyManager() {
        require(msg.sender == address(vaultManager), "MANAGER_ONLY");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == vaultManager.gov(), "GOV_ONLY");
        _;
    }

    modifier onlyVe() {
        require(msg.sender == veTranche, "veTRANCHE_ONLY");
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /**
     * @notice Initializes the proxy
     * @param __asset The address of the asset (token) the contract will manage
     * @param _vaultManager The address of the vault manager contract
     * @param trancheName The name of the tranche for easy identification
     */
    function initialize(address __asset, address _vaultManager, string memory trancheName, string memory tranchSymbol) external initializer {
        vaultManager = IVaultManager(_vaultManager);
        withdrawThreshold = 90 * _PRECISION;
        depositCap = 500000e6; //Will be less on mainnet

        __ERC4626_init_unchained(IERC20Upgradeable(__asset));
        __ERC20_init_unchained(
            string(abi.encodePacked(trancheName, abi.encodePacked(" Tranche ", ERC20(__asset).name()))),
            string(abi.encodePacked(tranchSymbol, ERC20(__asset).symbol()))
        );
    }

    /**
     * @notice Toggles the fee status
     * @param _feesOn The boolean indicating whether to turn fees on or off
     */
    function setFeesOn(bool _feesOn) external onlyGov {
        feesOn = _feesOn;
        emit FeesStatusUpdated(_feesOn);
    }

    /**
     * @notice Updates the deposit cap of the tranche
     * @param _newCap The new deposit cap amount
     */
    function setCap(uint _newCap) external onlyGov {
        depositCap = _newCap;
        emit ReserveCapUpdated(_newCap);
    }

    /**
     * @notice Sets the address of the VeTranche
     * @param _veTranche The address of the VeTranche contract
     */
    function setVeTranche(address _veTranche) external onlyGov {
        require(_veTranche != address(0), "ADDRESS_INVALID");
        veTranche = _veTranche;
        emit VeTrancheUpdated(_veTranche);
    }

    /**
     * @notice Updates the address of the vault manager
     * @param _vaultManager The new vault manager's address
     */
    function setVaultManager(address _vaultManager) external onlyGov {
        require(_vaultManager != address(0), "ADDRESS_INVALID");
        vaultManager = IVaultManager(_vaultManager);
        emit VaultManagerUpdated(_vaultManager);
    }

    /**
     * @notice Sets the withdraw threshold for the contract
     * @param _withdrawThreshold The new withdraw threshold value
     */
    function setWithdrawThreshold(uint256 _withdrawThreshold) external onlyGov {
        require(_withdrawThreshold < 100 * _PRECISION, "THRESHOLD_EXCEEDS_MAX");
        withdrawThreshold = _withdrawThreshold;
        emit WithdrawThresholdUpdated(_withdrawThreshold);
    }

    /**
     * @notice Reserves a certain amount of assets for trading by the vault manager.
     * @param amount The amount of assets to reserve.
     */
    function reserveBalance(uint256 amount) external onlyManager {
        _reserveBalance(amount);
    }

    /**
     * @notice Releases a certain amount of reserved assets back to the vault.
     * @param amount The amount of assets to release.
     */
    function releaseBalance(uint256 amount) external onlyManager {
        _releaseBalance(amount);
    }

    /**
     * @notice Allows the vault manager to withdraw a specific amount of assets.
     * @param amount The amount of assets to withdraw.
     */
    function withdrawAsVaultManager(uint256 amount) external onlyManager {
        SafeERC20.safeTransfer(ERC20(asset()), address(vaultManager), amount);
    }

    /**
     * @notice Calculates the utilization ratio of the vault up to 10 decimal points.
     * @return The utilization ratio in percentage (multiplied by 10^10 for decimals).
     */
    function utilizationRatio() public view returns (uint256) {
        return ((totalReserved * _PRECISION * 100) / super.totalAssets());
    }

    /**
     * @notice Checks if the vault has sufficient liquidity after reserving a given amount.
     * @param _reserveAmount The amount to check for.
     * @return True if sufficient liquidity exists, otherwise false.
     */
    function hasLiquidity(uint256 _reserveAmount) public view returns (bool) {
        return super.totalAssets() > (_reserveAmount + totalReserved);
    }

    /**
     * @notice Previews the amount to deposit after accounting for fees.
     * @param assets The amount to deposit.
     * @return The net depositable amount.
     */
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return super.previewDeposit(assets - getDepositFeesTotal(assets));
    }

    /** @dev See {IERC4626-previewMint}. */
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewMint(shares);
        return assets + getDepositFeesRaw(assets);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return super.previewWithdraw(assets + getWithdrawalFeesRaw(assets));
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - getWithdrawalFeesTotal(assets);
    }

    /**
     * @notice Calculates the raw deposit fees for a given amount of assets.
     * @param assets The amount of assets.
     * @return The raw deposit fee.
     */
    function getDepositFeesRaw(uint256 assets) public view returns (uint256) {
        if (!feesOn) return 0;
        return _feeOnRaw(assets, balancingFee(assets, true));
    }

    /** 
     * @notice Calculate the total deposit fees for a given amount of assets.
     * @param assets The amount of assets being deposited.
     * @return The total deposit fees.
     */
    function getDepositFeesTotal(uint256 assets) public view returns (uint256) {
        if (!feesOn) return 0;
        return _feeOnTotal(assets, balancingFee(assets, true));
    }

    /** 
     * @notice Calculate the raw withdrawal fees for a given amount of assets.
     * @param assets The amount of assets being withdrawn.
     * @return The raw withdrawal fees.
     */
    function getWithdrawalFeesRaw(uint256 assets) public view returns (uint256) {
        if (!feesOn) return 0;
        return _feeOnRaw(assets, balancingFee(assets, false)) + _feeOnRaw(assets, collateralHealthFee());
    }

    function getWithdrawalFeesTotal(uint256 assets) public view returns (uint256) {
        if (!feesOn) return 0;
        return _feeOnTotal(assets, balancingFee(assets, false)) + _feeOnTotal(assets, collateralHealthFee());
    }
    /** 
     * @notice Retrieve the balancing fee based  Vault status
     * @param isDeposit Indicates if the action is a deposit (true) or withdrawal (false).
     * @return The balancing fee.
     */
    function balancingFee(uint256 assets, bool isDeposit) public view returns (uint256) {
        return vaultManager.getBalancingFee(address(this), isDeposit, assets);
    }

    /** 
     * @notice Retrieve the collateral health fee based on protocol Pnl Status
     * @return The collateral health fee.
     */
    function collateralHealthFee() public view returns (uint256) {
        return vaultManager.getCollateralFee();
    }

    /** 
     * @notice Reserve a specific amount of balance.
     * @param amount The amount to reserve.
     */
    function _reserveBalance(uint256 amount) internal {
        require(super.totalAssets() >= amount + totalReserved, "RESERVE_AMOUNT_EXCEEDS_AVAILABLE");
        totalReserved += amount;
        emit BalanceReserved(amount);
    }

    /** 
     * @notice Release a specific amount of reserved balance.
     * @param amount The amount to release from the reserve.
     */
    function _releaseBalance(uint256 amount) internal {
        require(totalReserved >= amount, "RELEASE_AMOUNT_EXCEEDS_AVAILABLE");
        totalReserved -= amount;
        emit BalanceReleased(amount);
    }

    /** 
     * @notice Internal function to handle deposit actions.
     * @param caller The address initiating the deposit.
     * @param receiver The address receiving the assets.
     * @param assets The amount of assets being deposited after fees.
     * @param shares The number of shares for the deposit.
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        require(totalAssets() + assets < depositCap, "DEPOSIT_CAP_BREACHED");

        uint256 fee = getDepositFeesTotal(assets);
        super._deposit(caller, receiver, assets, shares);

        if (fee > 0) {
            SafeERC20.safeTransfer(ERC20(asset()), address(vaultManager), fee);
            vaultManager.allocateRewards(fee, false);
        }
    }

    /** 
     * @notice Internal function to handle withdrawal actions.
     * @param caller The address initiating the withdrawal.
     * @param receiver The address receiving the assets.
     * @param owner The owner of the assets.
     * @param assets The amount of assets being withdrawn before fees
     * @param shares The number of shares for the withdrawal.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {

        uint256 fee = getWithdrawalFeesRaw(assets);
        super._withdraw(caller, receiver, owner, assets, shares);

        if (fee > 0) {
            SafeERC20.safeTransfer(ERC20(asset()), address(vaultManager), fee);
            vaultManager.allocateRewards(fee, false);
        }
        require(utilizationRatio() < withdrawThreshold, "UTILIZATION_RATIO_MAX");
    }

    /** 
     * @notice Internal function to augment transfer actions.
     * @param from The address initiating the transfer.
     * @param to The address receiving the shares.
     * @param amount The owner of the shares.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        emit TokenTransferred(from, to, amount, convertToAssets(amount));
        super._transfer(from, to, amount);
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        int maxAssets = int(super.totalAssets()) - int((totalReserved * _PRECISION * 100)/withdrawThreshold) ;
        maxAssets =  maxAssets < 0 ? int(0) : maxAssets;
        uint redeemAssets = convertToAssets(balanceOf(owner));
        if(redeemAssets < uint(maxAssets)) return balanceOf(owner);
        return convertToShares(uint(maxAssets));
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        int maxAssets = int(super.totalAssets()) - int((totalReserved * _PRECISION * 100)/withdrawThreshold) ;
        maxAssets =  maxAssets < 0 ? int(0) : maxAssets;
        uint withdrawAssets = _convertToAssets(balanceOf(owner), MathUpgradeable.Rounding.Down);
        if(withdrawAssets < uint(maxAssets)) return withdrawAssets;
        return uint(maxAssets);
    }
    /** 
     * @notice Calculate the raw fee amount. Is Higher than feeTotal
     * @param assets The amount of assets.
     * @param feeBasePoint The fee rate in basis points.
     * @return The raw fee amount.
     */
    function _feeOnRaw(uint256 assets, uint256 feeBasePoint) private pure returns (uint256) {
        return assets.mulDiv(feeBasePoint, 1e5, MathUpgradeable.Rounding.Up);
    }

    /** 
     * @notice Calculate the total fee amount. Is lower than Raw fees
     * @param assets The amount of assets.
     * @param feeBasePoint The fee rate in basis points.
     * @return The total fee amount.
     */
    function _feeOnTotal(uint256 assets, uint256 feeBasePoint) private pure returns (uint256) {
        return assets.mulDiv(feeBasePoint, feeBasePoint + 1e5, MathUpgradeable.Rounding.Up);
    }

}
