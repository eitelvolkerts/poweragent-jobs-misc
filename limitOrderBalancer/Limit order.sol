pragma solidity ^0.8.0;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface QueryEndpoint {
    function querySwap(
        IVault.SingleSwap memory singleSwap,
        IVault.FundManagement memory funds) external
    returns (uint256);
}

contract limitOrder is Ownable{
    IVault.SwapKind public swapKind; //0 is exact given in, 1 is guess yourself
    bytes32 public poolId;
    IAsset public assetIn;
    IAsset public assetOut;
    uint256 public amount;
    address public vaultAddress;
    address public sender;
    address payable recipient;
    bool public fromInternalBalace;
    bool public toInternalBalance;
    uint256 private priceThreshold;
    uint256 private toleranceInBps;
    QueryEndpoint public constant QUERYENDPOINT = QueryEndpoint(0x0F3e0c4218b7b0108a3643cFe9D3ec0d4F57c54e);

    IVault private vault;


    constructor(uint8 _swapKind, 
                bytes32 _poolId, 
                address _assetIn, 
                address _assetOut,
                uint256 _amount,
                address _vaultAddress,
                bool _fromInternalBalance,
                bool _toInternalBalance,
                uint256 _priceThreshold,
                uint256 _toleranceInBps){
        swapKind = IVault.SwapKind(_swapKind);
        poolId = _poolId;
        assetIn = IAsset(_assetIn);
        assetOut = IAsset(_assetOut);
        amount = _amount;  
        vaultAddress = _vaultAddress;
        vault = IVault(vaultAddress);
        priceThreshold = _priceThreshold;
        toleranceInBps = _toleranceInBps;
        fromInternalBalace = _fromInternalBalance;
        toInternalBalance = _toInternalBalance;
    }

    function setSenderRecipient(address _sender, address payable _recipient) public onlyOwner {
        sender = _sender;
        recipient = _recipient;
    }

    function _getCallData(uint256 pricePerEthUnit) private view returns (bytes memory callData) {
        return abi.encodeWithSelector(vault.swap.selector, IVault.SingleSwap(
            poolId, 
            swapKind,
            assetIn,
            assetOut,
            amount,
            bytes("0x")
        ), IVault.FundManagement(sender, fromInternalBalace, recipient, toInternalBalance),
        985*pricePerEthUnit*amount/1000/1e18, block.timestamp+5 minutes);
    }

    function _checkExecutability(uint256 queriedPrice) view private returns (bool flag){
        if (swapKind == IVault.SwapKind(0)){
            //exact in, computed out => selling, assume lower price bound
            return queriedPrice > priceThreshold*(100000 - toleranceInBps)/100000;
        }
        else {
            //exact out, computed in => buying, assume upper price bound
            return queriedPrice < priceThreshold*(100000 + toleranceInBps)/100000;
        }
    }

    function checkAndReturnCalldata() public returns (bool flag, bytes memory cdata){
        (bool ok, bytes memory result) = address(QUERYENDPOINT).call(
            abi.encodeWithSelector(QUERYENDPOINT.querySwap.selector, 
            IVault.SingleSwap(
            poolId, 
            swapKind,
            assetIn,
            assetOut,
            1 ether,
            bytes("0x")
        ), IVault.FundManagement(sender, fromInternalBalace, recipient, toInternalBalance))
        );
        assert(ok);
        uint256 queriedPrice = abi.decode(result, (uint256));
        cdata = _getCallData(queriedPrice);
        flag = _checkExecutability(queriedPrice);
    }
}