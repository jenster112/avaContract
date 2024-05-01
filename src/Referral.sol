// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/IReferral.sol";

/** @title Referral contract */
contract Referral is IReferral {

    uint256 private constant _BASIS_POINTS = 10000;
    uint private constant _DEFAULT_TIER_ID = 1;
    
    address public gov;
    address public requestedGov;

    mapping(address => uint256) public override referrerTiers;
    mapping(uint256 => Tier) public tiers;
    mapping(address => bool) public isHandler;
    mapping(bytes32 => address) public override codeOwners;
    mapping(bytes32 => address) public pendingCodeOwners;
    mapping(address => bytes32) public codes;
    mapping(address => bytes32) public override traderReferralCodes;

    modifier onlyHandler() {
        require(isHandler[msg.sender], "ReferralStorage: forbidden");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    constructor() {
        gov = msg.sender;
    }

    /**
     * @notice Requests the governance address.
     * @dev Only callable by the current governance.
     * @param _gov The new governance address.
     */
    function requestGov(address _gov) external onlyGov {
        require(_gov != address(0));
        requestedGov = _gov;
    }

    /** 
     * @notice Sets the governance address
     * @param _gov The new governance address
     */
    function setGov(address _gov) external onlyGov {
        require(_gov != address(0));
        require(_gov == requestedGov);
        gov = _gov;
        emit SetGov(_gov);
    }

    /** 
     * @notice Sets the handler for the referral system
     * @param _handler The address of the handler
     * @param _isActive Boolean to indicate if handler is active
     */
    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
        emit SetHandler(_handler, _isActive);
    }
    /** 
     * @notice Sets the tier for referral program
     * @param _tierId The ID of the tier
     * @param _feeDiscountPct The discount percent
     * @param _refRebatePct The rebate percent for referrer
     */
    function setTier(uint256 _tierId, uint256 _feeDiscountPct, uint256 _refRebatePct) external override onlyGov {
        require(_feeDiscountPct <= _BASIS_POINTS, "ReferralStorage: invalid totalRebate");
        require(_refRebatePct <= _BASIS_POINTS, "ReferralStorage: invalid discountShare");

        Tier memory tier = tiers[_tierId];
        tier.feeDiscountPct = _feeDiscountPct;
        tier.refRebatePct = _refRebatePct;
        tiers[_tierId] = tier;

        emit SetTier(_tierId, _feeDiscountPct, _refRebatePct);
    }

    /** 
     * @notice Sets the tier for a referrer
     * @param _referrer The address of the referrer
     * @param _tierId The ID of the tier to set
     */
    function setReferrerTier(address _referrer, uint256 _tierId) external override onlyGov {
        referrerTiers[_referrer] = _tierId;
        emit SetReferrerTier(_referrer, _tierId);
    }

    /** 
     * @notice Sets the trader's referral code
     * @param _account The address of the trader
     * @param _code The referral code
     */
    function setTraderReferralCode(address _account, bytes32 _code) external override onlyHandler {
        _setTraderReferralCode(_account, _code);
    }

    /** 
     * @notice Sets the trader's referral code. Callable by user. 
     * @param _code The referral code
     */
    function setTraderReferralCodeByUser(bytes32 _code) external {
        _setTraderReferralCode(msg.sender, _code);
    }

    /** 
     * @notice Register a referral code for the sender. To be called by referrer
     * @param _code The referral code to register
     */
    function registerCode(bytes32 _code) external {
        require(_code != bytes32(0), "ReferralStorage: invalid _code");
        require(codeOwners[_code] == address(0), "ReferralStorage: code already exists");
        require(codes[msg.sender] == bytes32(0),"ReferralStorage: referrer already registered");

        codeOwners[_code] = msg.sender;
        codes[msg.sender] =  _code;
        referrerTiers[msg.sender] = _DEFAULT_TIER_ID;

        emit RegisterCode(msg.sender, _code);
    }

    /** 
     * @notice initiated Code ownership transfer
     * @param _code Code to be transferred
     * @param _newAccount The new owner address
     * 
     */
    function setPendingCodeOwnershipTransfer(bytes32 _code, address _newAccount) external {
        require(_code != bytes32(0), "ReferralStorage: invalid _code");

        address account = codeOwners[_code];
        require(msg.sender == account, "ReferralStorage: forbidden");

        pendingCodeOwners[_code] = _newAccount;
        emit SetPendingCodeOwner(msg.sender, _newAccount, _code);
    }

    /** 
     * @notice Acceptabnce Code ownership transfer
     * @param _code Code which was transferred
     */
    function acceptCodeOwnership(bytes32 _code) external {
        
        address oldOwner = codeOwners[_code];
        require(pendingCodeOwners[_code] == msg.sender, "ReferralStorage: forbidden");

        delete codeOwners[codes[msg.sender]];
        delete pendingCodeOwners[codes[msg.sender]];
        
        codeOwners[_code] = msg.sender;
        codes[msg.sender] = _code;
        referrerTiers[msg.sender] = referrerTiers[oldOwner];
        emit SetCodeOwner(oldOwner, msg.sender, _code);

        delete codes[oldOwner];
        delete pendingCodeOwners[_code];
        delete referrerTiers[oldOwner];
    }

    /** 
     * @notice Sets the code owner by governance
     * @param _code The referral code
     * @param _newAccount The new owner address
     */
    function govSetCodeOwner(bytes32 _code, address _newAccount) external override onlyGov {
        require(_code != bytes32(0), "ReferralStorage: invalid _code");

        address account = codeOwners[_code];
        delete codes[account];
        delete codeOwners[codes[_newAccount]];

        codeOwners[_code] = _newAccount;
        codes[_newAccount] = _code;
        referrerTiers[_newAccount] = referrerTiers[account];

        delete referrerTiers[account];
        emit GovSetCodeOwner(_code, _newAccount);
    }

    /** 
     * @notice Returns the trader discount and referrer information
     * @param _account The address of the trader
     * @param _fee The fee amount
     * @return traderFeesPostDiscount Trader fee post discount
     * @return referrer The address of the referrer
     * @return rebateShare The share of rebate for referrer
     */
    function traderReferralDiscount(
        address _account,
        uint _fee
    ) external view override returns (uint traderFeesPostDiscount, address referrer, uint rebateShare) {
        (, referrer) = getTraderReferralInfo(_account);
        uint _tierId = referrerTiers[referrer];
        traderFeesPostDiscount = _fee - (_fee * tiers[_tierId].feeDiscountPct) / _BASIS_POINTS;
        rebateShare = (traderFeesPostDiscount * tiers[_tierId].refRebatePct) / _BASIS_POINTS;
    }
    
    /** 
     * @notice Gets the code and referrer for a trader account
     * @param _account The address of the trader
     * @return code The referral code
     * @return referrer The referrer address
     */
    function getTraderReferralInfo(address _account) public view override returns (bytes32, address) {
        bytes32 code = traderReferralCodes[_account];
        address referrer;
        if (code != bytes32(0)) {
            referrer = codeOwners[code];
        }
        return (code, referrer);
    }

    // Internal function for setting trader referral code
    function _setTraderReferralCode(address _account, bytes32 _code) private {
        traderReferralCodes[_account] = _code;
        emit SetTraderReferralCode(_account, _code);
    }

}
