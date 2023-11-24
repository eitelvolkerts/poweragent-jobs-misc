# Limit order for the Balancer project

This constructs a limit order for Balancer (initial implementation pending upgrade). The parameters of the contract are as follows:
1. `_swapKind` - the type of the swap (0 corresponds to exact amount in, 1 - to exact amount out)
2. `_poolId` - ID of the Balancer pool
3. `_assetIn`, `_assetOut` - addresses of the assets to swap
4. `_amount` - target amount to swap
5. `_vaultAddress` - address of the Balancer vault
6. `_fromInternalBalance`, `_toInternalBalance` - whether to withdraw/deposit tokens to the internal balance of this address in the Balancer contract
7. `_priceThreshold` - the threshold of the price which triggers a swap. Lower bound of the price for exact-amount-in, upper bound for exact-amount-out
8. `_toleranceInBps` - the safety factor for the price check (in basis points)

