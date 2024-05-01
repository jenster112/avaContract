// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/ITranche.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/IVeTranche.sol";

contract VeTranche is ERC721Upgradeable, ReentrancyGuardUpgradeable, IVeTranche {

    using MathUpgradeable for uint256;
    using Counters for Counters.Counter;

    uint256 private constant _PRECISION = 1e6;

    Counters.Counter public tokenIds;
    ITranche public tranche;
    IVaultManager public vaultManager;

    uint public multiplierCoeff;
    uint public multiplierDenom;
    uint public rewardsDistributedPerSharePerLockPoint;
    uint public totalLockPoints;

    mapping(uint256 => uint256) public rewardsByTokenId;
    mapping(uint256 => uint256) public tokensByTokenId;
    mapping(uint256 => uint256) public lockTimeByTokenId;
    mapping(uint256 => uint256) public lockStartTimeByTokenId;
    mapping(uint256 => uint256) public lockMultiplierByTokenId;
    mapping(uint256 => uint256) public lastSharePoint;

    modifier onlyGov() {
        require(msg.sender == vaultManager.gov(), "GOV_ONLY");
        _;
    }
    modifier onlyManager() {
        require(msg.sender == address(vaultManager), "MANAGER_ONLY");
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /**
     * @notice Initializes the VeTranche contract.
     * @param _tranche The address of the Tranche contract.
     * @param _vaultManager The address of the VaultManager contract.
     */
    function initialize(address _tranche, address _vaultManager) external initializer {
        tranche = ITranche(_tranche);
        vaultManager = IVaultManager(_vaultManager);
        multiplierCoeff = 1815e5;
        multiplierDenom = 1960230 * _PRECISION;

        __ERC721_init_unchained(
            string(abi.encodePacked("Locked ", tranche.name())),
            string(abi.encodePacked("ve-", tranche.symbol()))
        );
        __ReentrancyGuard_init_unchained();
    }

    /**
     * @notice Sets the VaultManager.
     * @param _vaultManager The new VaultManager address.
     */
    function setVaultManager(address _vaultManager) external onlyGov {
        require(_vaultManager != address(0), "ADDRESS_INVALID");
        vaultManager = IVaultManager(_vaultManager);
    }

    /**
     * @notice Sets the multiplier denominator.
     * @param _multiplierDenom The new multiplier denominator value.
     */
    function setMultiplierDenom(uint256 _multiplierDenom) external onlyGov {
        require(_multiplierDenom > 0, "NUMBER_INVALID");
        multiplierDenom = _multiplierDenom;
        emit NumberUpdated("Multiplier Denominator", _multiplierDenom);
    }

    /**
     * @notice Sets the multiplier coefficient.
     * @param _multiplierCoeff The new multiplier coefficient value.
     */
    function setMultiplierCoeff(uint256 _multiplierCoeff) external onlyGov {
        require(_multiplierCoeff > 0, "NUMBER_INVALID");
        multiplierCoeff = _multiplierCoeff;
        emit NumberUpdated("Multiplier Coefficient", _multiplierCoeff);
    }

    /**
     * @notice Distributes the reward to a specific tokenId.
     * @param reward The amount of reward to distribute.
     * @param tokenId The ID of the token to receive the reward.
     */
    function distributeReward(uint256 reward, uint256 tokenId) external onlyManager {
        rewardsByTokenId[tokenId] += reward;
    }

    /**
     * @notice Distributes the reward among the participants.
     * @param rewards The amount of reward to distribute.
     */
    function distributeRewards(
        uint256 rewards
    ) external override onlyManager returns (uint256) {
        return _distributeRewards(rewards);
    }

    function getTotalLockPoints() public view override returns (uint256) {
        return totalLockPoints/_PRECISION;
    }

    /**
     * @notice Locks a specified amount of shares until a specified end time.
     * @param shares The number of shares to lock.
     * @param duration The time until which the shares will be locked.
     * @return The tokenId for the locked shares.
     */
    function lock(uint256 shares, uint duration) public nonReentrant returns (uint256) {
        require(duration <= getMaxLockTime(), "OVER_MAX_LOCK_TIME");
        require(duration >= getMinLockTime(), "LOCK_TIME_TOO_SMALL");

        require(shares > 0, "LOCK_AMOUNT_IS_ZERO");
        require(tranche.balanceOf(msg.sender) >= shares, "INSUFFICIENT_TRANCHE_TOKENS");

        uint256 nextTokenId = tokenIds.current();
        tranche.transferFrom(msg.sender, address(this), shares);
        _mint(msg.sender, nextTokenId);

        tokensByTokenId[nextTokenId] = shares;
        lockTimeByTokenId[nextTokenId] = block.timestamp + duration;
        lockStartTimeByTokenId[nextTokenId] = block.timestamp;
        rewardsByTokenId[nextTokenId] = 0;
        lockMultiplierByTokenId[nextTokenId] = getLockPoints(duration);
        lastSharePoint[nextTokenId] = rewardsDistributedPerSharePerLockPoint;
        totalLockPoints += shares * lockMultiplierByTokenId[nextTokenId];

        tokenIds.increment();
        emit Locked(nextTokenId, msg.sender, shares, duration, lockMultiplierByTokenId[nextTokenId]);

        return nextTokenId;
    }

    /**
     * @notice Unlocks a specific tokenId.
     * @param tokenId The ID of the token to unlock.
     */
    function unlock(uint256 tokenId) public nonReentrant {
        require(tokensByTokenId[tokenId] > 0, "NOTHING_TO_UNLOCK");
        require(msg.sender == ownerOf(tokenId), "NOT_OWNER");
        uint256 fee = checkUnlockFee(tokenId);

        _claimRewards(tokenId);
        _burn(tokenId);

        tranche.transfer(msg.sender, tokensByTokenId[tokenId] - fee);
        tranche.transfer(address(vaultManager), fee);

        emit Unlocked(tokenId, msg.sender, tokensByTokenId[tokenId], fee);
        totalLockPoints -= tokensByTokenId[tokenId]* lockMultiplierByTokenId[tokenId];

        delete tokensByTokenId[tokenId];
        delete rewardsByTokenId[tokenId];
        delete lockTimeByTokenId[tokenId];
        delete lockStartTimeByTokenId[tokenId];
        delete lockMultiplierByTokenId[tokenId];
        delete lastSharePoint[tokenId];
    }

    /**
     * @notice Force unlocks a token if its lock time has passed.
     * @notice To be called by Keepers
     * @param _tokenId The ID of the token to unlock.
     */
    function forceUnlock(uint256 _tokenId) public nonReentrant{
        require(lockTimeByTokenId[_tokenId] < block.timestamp, "TOO_EARLY");
        require(tokensByTokenId[_tokenId] > 0, "NOTHING_TO_UNLOCK");

        _claimRewards(_tokenId);
        tranche.transfer(_ownerOf(_tokenId), tokensByTokenId[_tokenId] );

        _burn(_tokenId);

        emit Unlocked(_tokenId, _ownerOf(_tokenId), tokensByTokenId[_tokenId], 0);
        totalLockPoints -= tokensByTokenId[_tokenId]* lockMultiplierByTokenId[_tokenId];

        delete tokensByTokenId[_tokenId];
        delete rewardsByTokenId[_tokenId];
        delete lockTimeByTokenId[_tokenId];
        delete lockStartTimeByTokenId[_tokenId];
        delete lockMultiplierByTokenId[_tokenId];
        delete lastSharePoint[_tokenId];
    }

    /**
     * @notice Claims rewards accumulated by tokenId.
     * @param tokenId The ID of the token to claim rewards for.
     */
    function claimRewards(uint256 tokenId) public nonReentrant {
        require(msg.sender == _ownerOf(tokenId));
        _claimRewards(tokenId);
    }

    /** 
     * @notice Calculate the early withdrawal fee for a given asset amount
     * @param assets The amount of assets to be withdrawn
     * @return The calculated early withdrawal fee
     */
    function getEarlyWithdrawFee(uint256 assets) public view returns (uint256) {
        return tranche.feesOn() ? assets.mulDiv(vaultManager.earlyWithdrawFee(), 1e5, MathUpgradeable.Rounding.Up) : 0;
    }

    /** 
     * @notice Get the maximum lock time allowed for locking tranche tokens
     * @return The maximum lock time in seconds
     */
    function getMaxLockTime() public view returns (uint256) {
        return vaultManager.maxLockTime();
    }

    /** 
     * @notice Get the minimum lock time required for locking tranche tokens
     * @return The minimum lock time in seconds
     */
    function getMinLockTime() public view returns (uint256) {
        return vaultManager.minLockTime();
    }

    /** 
     * @notice Calculate the unlock fee for a given token ID based on remaining lockTime
     * @param tokenId The ID of the token to check the unlock fee for
     * @return The calculated unlock fee
     */
    function checkUnlockFee(uint256 tokenId) public view returns (uint256) {
        if (lockTimeByTokenId[tokenId] > block.timestamp) {
            uint256 fee = getEarlyWithdrawFee(tokensByTokenId[tokenId]);

            if (fee > 0) {
                uint256 timeLeft = lockTimeByTokenId[tokenId] - block.timestamp;
                uint256 totalTime = lockTimeByTokenId[tokenId] - lockStartTimeByTokenId[tokenId];
                fee = fee.mulDiv(timeLeft, totalTime, MathUpgradeable.Rounding.Up);
            }
            return fee;
        }
        return 0;
    }

    /** 
     * @notice Calculate lock points based on time locked
     * @param timeLocked The amount of time the tranche tokens are locked for
     * @return The calculated lock points
     */
    function getLockPoints(uint256 timeLocked) public view override returns (uint256) {
        uint256 lockedDays = timeLocked > getMinLockTime() ? (timeLocked - getMinLockTime()) / 86400 : 0;
        uint256 minPoints = 2e5;
        uint256 points = _PRECISION + minPoints + (((lockedDays ** 2) * multiplierCoeff * _PRECISION) / multiplierDenom);
        return points;
    }

    /** 
     * @dev Internal function to distribute rewards among participants
     * @param rewards The amount of rewards to distribute
     * @return The updated total lock points
     */
    function _distributeRewards(uint256 rewards) internal returns (uint256) {

        rewardsDistributedPerSharePerLockPoint += (rewards * (_PRECISION **3)) / getTotalLockPoints();
        emit RewardsDistributed(rewards, getTotalLockPoints());

        return getTotalLockPoints();
    }

    /** 
     * @dev Internal function to claim pending rewards for a specific token ID
     * @param tokenId The ID of the token for which to claim rewards
     */
    function _claimRewards(uint256 tokenId) internal {
        _updateReward(tokenId);
        if (rewardsByTokenId[tokenId] > 0) {
            SafeERC20.safeTransfer(IERC20(tranche.asset()), _ownerOf(tokenId), rewardsByTokenId[tokenId]);
            emit RewardClaimed(tokenId, _ownerOf(tokenId), rewardsByTokenId[tokenId]);
            rewardsByTokenId[tokenId] = 0;
        }   
    }

    /** 
     * @dev Internal function to update the reward of a token ID. Updated while claiming reward.
     * @param _id The ID of the token for which to update the reward
     */
    function _updateReward(uint256 _id) internal {
        if(lastSharePoint[_id] == rewardsDistributedPerSharePerLockPoint ) return;

        uint256 pendingReward = ((rewardsDistributedPerSharePerLockPoint - lastSharePoint[_id]) *
                                tokensByTokenId[_id] * 
                                lockMultiplierByTokenId[_id]) /
                                (_PRECISION **4);
        rewardsByTokenId[_id] += pendingReward;
        lastSharePoint[_id] =  rewardsDistributedPerSharePerLockPoint;
    }
}
