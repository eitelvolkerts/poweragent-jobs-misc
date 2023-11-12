// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IAgent {
    struct Job {
        uint8 config;
        bytes4 selector;
        uint88 credits;
        uint16 maxBaseFeeGwei;
        uint16 rewardPct;
        uint32 fixedReward;
        uint8 calldataSource;

        // For interval jobs
        uint24 intervalSeconds;
        uint32 lastExecutionAt;
    }
    struct Resolver {
        address resolverAddress;
        bytes resolverCalldata;
    }
    struct RandaoConfig {
        // max: 2^8 - 1 = 255 blocks
        uint8 slashingEpochBlocks;
        // max: 2^24 - 1 = 16777215 seconds ~ 194 days
        uint24 period1;
        // max: 2^16 - 1 = 65535 seconds ~ 18 hours
        uint16 period2;
        // in 1 CVP. max: 16_777_215 CVP. The value here is multiplied by 1e18 in calculations.
        uint24 slashingFeeFixedCVP;
        // In BPS
        uint16 slashingFeeBps;
        // max: 2^16 - 1 = 65535, in calculations is multiplied by 0.001 ether (1 finney),
        // thus the min is 0.001 ether and max is 65.535 ether
        uint16 jobMinCreditsFinney;
        // max 2^40 ~= 1.1e12, in calculations is multiplied by 1 ether
        uint40 agentMaxCvpStake;
        // max: 2^16 - 1 = 65535, where 10_000 is 100%
        uint16 jobCompensationMultiplierBps;
        // max: 2^32 - 1 = 4_294_967_295
        uint32 stakeDivisor;
        // max: 2^8 - 1 = 255 hours, or ~10.5 days
        uint8 keeperActivationTimeoutHours;
        // max: 2^16 - 1 = 65535, in calculations is multiplied by 0.001 ether (1 finney),
        // thus the min is 0.001 ether and max is 65.535 ether
        uint16 jobFixedRewardFinney;
    }
    function jobOwnerCredits(address owner_) external view returns (uint256 credits);
    function getJob(bytes32 jobKey_) external view returns (
        address owner,
        address pendingTransfer,
        uint256 jobLevelMinKeeperCvp,
        Job memory details,
        bytes memory preDefinedCalldata,
        Resolver memory resolver
    );
    function getRdConfig() external view returns (RandaoConfig memory);

}

interface IReplenisher {
    function depositCredits(address[] calldata depositFor, uint256[] calldata depositAmt,
                                        bytes32[] calldata keysFor, uint256[] calldata depositAmtKeys) external;
}

contract replenishmentResolver is Ownable {
    struct params{
        uint256 globalSafetyFactorBps_;
        bool whitelistAdditions_;
        uint256 replenishmentTimeout_;
        uint256 replenishmentValue_;
        address agent_;
        address replenisher_;
    }
    IAgent public agent;
    IReplenisher public replenisher;
    uint256 public globalSafetyFactorBps;
    mapping(uint256=>address) public registeredOwners;
    mapping(uint256=>bytes32) public registeredKeys;
    mapping(address=>uint256) public ownerActiveAt;
    mapping(bytes32=>uint256) public keyActiveAt;
    //mapping(address=>uint256) public ownerSafetyFactorBps;
    //mapping(bytes32=>uint256) public keySafetyFactorBps;
    uint256 public totalKeys;
    uint256 public totalOwners;
    bool public whitelistAdditions;
    uint256 public replenishmentValue;
    uint256 public replenishmentTimeout;

    event parametersSet(params parameters);

    constructor(uint256 _globalSafetyFactorBps, bool _whitelistAdditions,
    uint256 _replenishmentTimeout, uint256 _replenishmentValue, address _agent,
    address _replenisher) {
        globalSafetyFactorBps = _globalSafetyFactorBps;
        whitelistAdditions = _whitelistAdditions;
        replenishmentTimeout = _replenishmentTimeout;
        replenishmentValue = _replenishmentValue;
        agent = IAgent(_agent);
        replenisher = IReplenisher(_replenisher);
        emit parametersSet(params(globalSafetyFactorBps, whitelistAdditions, replenishmentTimeout, replenishmentValue, address(agent), address(replenisher)));
    }

    function setParameters(uint256 _globalSafetyFactorBps, bool _whitelistAdditions,
    uint256 _replenishmentTimeout, uint256 _replenishmentValue, address _agent, address _replenisher) public onlyOwner {
        globalSafetyFactorBps = _globalSafetyFactorBps>0 ? _globalSafetyFactorBps: globalSafetyFactorBps;
        whitelistAdditions = _whitelistAdditions != whitelistAdditions ? _whitelistAdditions : whitelistAdditions;
        replenishmentTimeout = _replenishmentTimeout>0 ? _replenishmentTimeout : replenishmentTimeout;
        replenishmentValue = _replenishmentValue>0 ? _replenishmentValue : replenishmentValue;
        agent = _agent != address(0) ? IAgent(_agent) : agent;
        replenisher = _replenisher != address(0) ? IReplenisher(_replenisher) : replenisher;
        emit parametersSet(params(globalSafetyFactorBps, whitelistAdditions, replenishmentTimeout, replenishmentValue, address(agent), address(replenisher)));
    }

    function setKeyActivity(bytes32 _key, bool _activate) public {
        if ((msg.sender != this.owner())&&(whitelistAdditions)) {
            revert("Cannot register on your own when additions are whitelisted!");
        }
        (address requiredOwner,,,,,) = agent.getJob(_key);
        if ((msg.sender != this.owner()) && (msg.sender != address(replenisher)) && (
            msg.sender != requiredOwner)
        ){
            revert("No rights to change activity!");
        }
        if (_activate) {
            if (keyActiveAt[_key]>0){
                //such a key exists, reset activation
                keyActiveAt[_key] = block.timestamp + replenishmentTimeout;
            }
            else {
                //insert new key
                registeredKeys[totalKeys] = _key;
                keyActiveAt[_key] = block.timestamp + replenishmentTimeout;
                totalKeys += 1;
            }
        }
        else {
            if (keyActiveAt[_key]>0){
                //such a key exists, deactivate
                keyActiveAt[_key] = type(uint256).max;
            }
            else {
                //no such key, don't waste my time
                revert("Ain't no such key");
            }
        }
    }

    function setOwnerActivity(address _owner, bool _activate) public {
        if ((msg.sender != this.owner())&&(whitelistAdditions)) {
            revert("Cannot register on your own when additions are whitelisted!");
        }
        if (_activate) {
            if (ownerActiveAt[_owner]>0){
                //such an owner exists, reset activation
                ownerActiveAt[_owner] = block.timestamp + replenishmentTimeout;
            }
            else {
                //insert new owner
                registeredOwners[totalOwners] = _owner;
                ownerActiveAt[_owner] = block.timestamp + replenishmentTimeout;
                totalOwners += 1;
            }
        }
        else {
            if (ownerActiveAt[_owner]>0){
                //such an owner exists, deactivate
                ownerActiveAt[_owner] = type(uint256).max;
            }
            else {
                //no such owner, don't waste my time
                revert("Ain't no such owner");
            }
        }
    }

    function setKeysActivity(bytes32[] calldata _key, bool[] calldata _activate) public {
        for (uint256 i=0; i<_activate.length; i++){
            setKeyActivity(_key[i], _activate[i]);
        }
    }

    function setOwnersActivity(address[] calldata _owner, bool[] calldata _activate) public {
        for (uint256 i=0; i<_activate.length; i++){
            setOwnerActivity(_owner[i], _activate[i]);
        }
    }

    function resolve() public view returns (bool flag, bytes memory cdata) {
        address[] memory detectedOwners = new address[](totalOwners);
        uint256[] memory amtOwners = new uint256[](totalOwners);
        bytes32[] memory detectedKeys = new bytes32[](totalKeys);
        uint256[] memory amtKeys = new uint256[](totalKeys);
        uint16 thresh = agent.getRdConfig().jobMinCreditsFinney;
        for (uint256 i = 0; i<totalOwners; i++){
            if ((agent.jobOwnerCredits(registeredOwners[i])<thresh*(10000+globalSafetyFactorBps)/10000) && (block.timestamp>=ownerActiveAt[registeredOwners[i]])){
                detectedOwners[i] = registeredOwners[i];
                amtOwners[i] = replenishmentValue;
                flag = true;
            }
        }
        for (uint256 i = 0; i<totalKeys; i++){
            (,,,IAgent.Job memory job,,) = agent.getJob(registeredKeys[i]);
            if ((job.credits<thresh*(10000+globalSafetyFactorBps)/10000) && (block.timestamp>=keyActiveAt[registeredKeys[i]])){
                detectedKeys[i] = registeredKeys[i];
                amtKeys[i] = replenishmentValue;
                flag = true;
            }
        }
        if (flag){
            cdata = abi.encodeWithSelector(replenisher.depositCredits.selector, 
            detectedOwners, amtOwners, detectedKeys, amtKeys);
        }
    }

}