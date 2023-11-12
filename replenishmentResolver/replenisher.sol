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
    function depositJobCredits(bytes32 jobKey_) external payable;
    function depositJobOwnerCredits(address for_) external payable;
    function withdrawJobOwnerCredits(address payable to_, uint256 amount_) external;
    function withdrawJobCredits(
        bytes32 jobKey_,
        address payable to_,
        uint256 amount_
    ) external;
}

interface IResolver {
    function setKeyActivity(bytes32 _key, bool _activate) external;
    function setOwnerActivity(address _owner, bool _activate) external;
}

contract replenisher is Ownable {

    IAgent public agent;
    IResolver public resolver;


    constructor (address _agent, address _resolver){
        agent = IAgent(_agent);
        resolver = IResolver(_resolver);
    }

    function setAgent(address _agent) public onlyOwner {
        agent = IAgent(_agent);
    }

    function setResolver(address _resolver) public onlyOwner {
        resolver = IResolver(_resolver);
    }

    function depositCredits(address[] calldata depositFor, uint256[] calldata depositAmt,
                                        bytes32[] calldata keysFor, uint256[] calldata depositAmtKeys) public{
        if (msg.sender != address(agent)){
            revert("You ain't the agent!");
        }
        for (uint256 i = 0; i<depositFor.length; i++){
            if (depositAmt[i]>0){
            agent.depositJobOwnerCredits{value:depositAmt[i]}(depositFor[i]);
            resolver.setOwnerActivity(depositFor[i], true);
        }}
        for (uint256 i = 0; i<keysFor.length; i++){
            if (depositAmtKeys[i]>0){
            agent.depositJobCredits{value:depositAmtKeys[i]}(keysFor[i]);
            resolver.setKeyActivity(keysFor[i], true);
        }}
    }
}