// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IGVC {
    function withdrawableAmount(address) external view returns (uint256);  
    function claimWithdrawal(address _address) external;
}

contract validatorClaimResolverRegistry is Ownable{

    //uint256 public threshold;
    IGVC public claimTarget;
    mapping(address=>uint256) public resolveThresholds;
    address[] public registeredValidators;
    bool public thresholdLocked;

    //event changedThreshold(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event registeredUser(address indexed newUser);
    event deregisteredUser(address indexed lostUser);
    event changedThreshold(address indexed user, uint256 indexed oldThreshold, uint256 indexed newThreshold);

    constructor (address _claimTarget) {
        //threshold = _threshold;
        claimTarget = IGVC(_claimTarget);
        thresholdLocked = 0;
    }

    function registerForResolution(uint256 _threshold) public {
        registeredValidators.push(tx.origin);
        resolveThresholds[tx.origin] = _threshold;
        emit changedThreshold(tx.origin, type(uint256).max, _threshold);
        emit registeredUser(tx.origin);
    }

    function deregister() public {
        emit changedThreshold(tx.origin, resolveThresholds[tx.origin], type(uint256).max);
        resolveThresholds[tx.origin] = type(uint256).max;
        emit deregisteredUser(tx.origin);
    }

    function changeThreshold(uint256 _threshold) public {
        resolveThresholds[tx.origin] = _threshold;
        emit changedThreshold(tx.origin, type(uint256).max, _threshold);
    }

    function changeAllThresholds(uint256 _threshold) public onlyOwner {
        for(uint256 i = 0; i<registeredValidators.length; i++){
            emit changedThreshold(registeredValidators[i], resolveThresholds[registeredValidators[i]], _threshold);
            resolveThresholds[registeredValidators[i]] = _threshold;
        }
    }

    function resolve() public view returns (bool flag, bytes memory cdata) {
        address claimer;
        address[] toPass;
        flag = false;
        for (uint256 i=0; i<registeredValidators.length; i++){
            claimer = registeredValidators[i];
            if (claimTarget.withdrawableAmount(this.owner()) >= threshold){
                flag = true;
                toPass.push(claimTarget);
            }
        }
        cdata = abi.encodeWithSelector(claimTarget.claimWithdrawals.selector, toPass);
    }

}