// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ValidatorClaimResolver.sol";

contract VCRFactory {
    event deployedResolver(address indexed resolverAddress, 
                           address indexed resolverOwner);

    function deployResolver(uint256 _threshold, address _claimTarget) public {
        validatorClaimResolver resolver = new validatorClaimResolver(_threshold, _claimTarget);
        resolver.transferOwnership(msg.sender);
        emit deployedResolver(address(resolver), msg.sender);
    }
}