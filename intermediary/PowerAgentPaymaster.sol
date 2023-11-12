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
    struct RegisterJobParams {
        address jobAddress;
        bytes4 jobSelector;
        bool useJobOwnerCredits;
        bool assertResolverSelector;
        uint16 maxBaseFeeGwei;
        uint16 rewardPct;
        uint32 fixedReward;
        uint256 jobMinCvp;
        uint8 calldataSource;
        uint24 intervalSeconds;
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
    function registerJob(
        RegisterJobParams calldata params_,
        Resolver calldata resolver_,
        bytes calldata preDefinedCalldata_
    ) external payable returns (bytes32 jobKey, uint256 jobId);
    function updateJob(
        bytes32 jobKey_,
        uint16 maxBaseFeeGwei_,
        uint16 rewardPct_,
        uint32 fixedReward_,
        uint256 jobMinCvp_,
        uint24 intervalSeconds_
    ) external;
    function setJobResolver(bytes32 jobKey_, Resolver calldata resolver_) external;
    function setJobPreDefinedCalldata(bytes32 jobKey_, bytes calldata preDefinedCalldata_) external;
    function setJobConfig(
        bytes32 jobKey_,
        bool isActive_,
        bool useJobOwnerCredits_,
        bool assertResolverSelector_
    ) external;
    function initiateJobTransfer(bytes32 jobKey_, address to_) external;
    function assignKeeper(bytes32[] calldata jobKeys_) external;
    function releaseJob(bytes32 jobKey_) external; 
}

contract PAPaymaster is Ownable {

    IAgent public agent;
    mapping(bytes32=>address) public keyOwners;

    constructor(address _agent){
        agent = IAgent(_agent);
    }

    function setAgent(address _agent) public onlyOwner {
        agent = IAgent(_agent);
    }

    function depositMoreCredits(uint256 amount) public onlyOwner {
        if (amount == 0){
            amount = address(this).balance;
        }
        agent.depositJobOwnerCredits{value:amount}(address(this));
    }

    function withdrawCredits(address payable _to, uint256 _amt) public onlyOwner {
        if (_amt == 0){
            _amt = agent.jobOwnerCredits(address(this));
        }
        agent.withdrawJobOwnerCredits(_to, _amt);
    }

    function registerJob(IAgent.RegisterJobParams calldata params_,
        IAgent.Resolver calldata resolver_,
        bytes calldata preDefinedCalldata_) public {
            (bytes32 jk, ) = agent.registerJob(params_, resolver_, preDefinedCalldata_);
            keyOwners[jk] = msg.sender;
        }
    

    function updateJob(
        bytes32 jobKey_,
        uint16 maxBaseFeeGwei_,
        uint16 rewardPct_,
        uint32 fixedReward_,
        uint256 jobMinCvp_,
        uint24 intervalSeconds_
    ) public {
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.updateJob(jobKey_, maxBaseFeeGwei_, rewardPct_, fixedReward_, jobMinCvp_, intervalSeconds_);
    }

    function setJobResolver(bytes32 jobKey_, IAgent.Resolver calldata resolver_) public {
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.setJobResolver(jobKey_, resolver_);
    }

    function setJobPreDefinedCalldata(bytes32 jobKey_, bytes calldata preDefinedCalldata_) public {
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.setJobPreDefinedCalldata(jobKey_, preDefinedCalldata_);
    }

    function setJobConfig(
        bytes32 jobKey_,
        bool isActive_,
        bool useJobOwnerCredits_,
        bool assertResolverSelector_
    ) public {
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.setJobConfig(jobKey_, isActive_, useJobOwnerCredits_, assertResolverSelector_);
    }

    function initiateJobTransfer(bytes32 jobKey_, address to_) public {
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.initiateJobTransfer(jobKey_, to_);
    }

    function assignKeeper(bytes32[] calldata jobKeys_) public {
        for (uint256 i = 0; i<jobKeys_.length; i++){
            if (msg.sender != keyOwners[jobKeys_[i]]){
                revert("You've no right to modify this job");
        }
        }
        agent.assignKeeper(jobKeys_);
    }

    function releaseJob(bytes32 jobKey_) public{
        if (msg.sender != keyOwners[jobKey_]){
            revert("You've no right to modify this job");
        }
        agent.releaseJob(jobKey_);
    }

}