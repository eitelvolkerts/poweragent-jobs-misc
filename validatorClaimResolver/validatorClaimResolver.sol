// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IGVC {
    function withdrawableAmount(address) external view returns (uint256);  
    function claimWithdrawal(address _address) external;
}

contract validatorClaimResolver is Ownable{

    uint256 public threshold;
    IGVC public claimTarget;

    event changedThreshold(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    constructor (uint256 _threshold, address _claimTarget) {
        threshold = _threshold;
        claimTarget = IGVC(_claimTarget);
    }

    function changeThreshold(uint256 _newThreshold) public onlyOwner {
        emit changedThreshold(threshold, _newThreshold);
        threshold = _newThreshold;
    }

    function resolve() public view returns (bool flag, bytes memory cdata) {
        if (claimTarget.withdrawableAmount(this.owner()) >= threshold){
            flag = true;
            cdata = abi.encodeWithSelector(claimTarget.claimWithdrawal.selector, this.owner());
        }
        else{
            flag = false;
        }
    }

}