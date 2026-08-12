// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface ICurvePool {
    function A() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function fee() external view returns (uint256);
    function redemption_price_snap() external view returns (address);
}

interface IRedemptionPriceSnap {
    function snappedRedemptionPrice() external view returns (uint256);
}

interface ICurveMetaRegistry {
    function get_coins(address pool) external view returns (address[8] memory);
    function get_n_coins(address pool) external view returns (uint256);
    function get_balances(address pool) external view returns (uint256[8] memory);
    function is_registered(address pool) external view returns (bool);
    function get_base_pool(address pool) external view returns (address);
    function is_meta(address pool) external view returns (bool);
    function get_lp_token(address pool) external view returns (address);
}

interface IERC20 {
    function decimals() external view returns (uint8);
}

struct CurvePoolState {
    bool is_registered;
    bool is_meta;
    address base_pool;
    address base_pool_lp_token;
    uint256 base_pool_total_supply;
    uint256 meta_pool_redemption_price;
    uint256 meta_pool_n_coins;
    uint256 base_pool_n_coins;
    address[8] meta_pool_coin_addresses;
    address[8] base_pool_coin_addresses;
    uint256[8] meta_pool_balances;
    uint256[8] base_pool_balances;
    uint8[8] meta_pool_coin_decimals;
    uint8[8] base_pool_coin_decimals;
    uint256 meta_pool_A;
    uint256 base_pool_A;
    uint256 meta_pool_fee;
    uint256 base_pool_fee;
}

contract Curve {
    // function used for stableswap pool state retrieval.
    function stableswapPoolState(address metaRegistry, address pool) external view returns (CurvePoolState memory) {
        CurvePoolState memory state;

        ICurveMetaRegistry registry = ICurveMetaRegistry(metaRegistry);
        ICurvePool metaPool = ICurvePool(pool);

        state.is_registered = registry.is_registered(pool);
        if (!state.is_registered) {
            // if the pool is not registered, we cannot fetch much more information about it, so we return early
            return state;
        }
        state.is_meta = registry.is_meta(pool);
        if (state.is_meta) {
            // if the pool is a meta pool, we fetch information about the base pool as well
            state.base_pool = registry.get_base_pool(pool);

            ICurvePool basePool = ICurvePool(state.base_pool);

            state.base_pool_lp_token = registry.get_lp_token(state.base_pool);
            state.base_pool_total_supply = ICurvePool(state.base_pool_lp_token).totalSupply();

            state.base_pool_n_coins = registry.get_n_coins(state.base_pool);
            state.base_pool_coin_addresses = registry.get_coins(state.base_pool);
            state.base_pool_balances = registry.get_balances(state.base_pool);
            state.base_pool_coin_decimals = getDecimals(state.base_pool_coin_addresses);
            state.base_pool_A = basePool.A();
            state.base_pool_fee = basePool.fee();
        }
        // redemption price is only available for some pools, so we wrap it in a try/catch to avoid reverting if it's not available
        try metaPool.redemption_price_snap() returns (address redemptionPriceSnap) {
            state.meta_pool_redemption_price = IRedemptionPriceSnap(redemptionPriceSnap).snappedRedemptionPrice();
        } catch {
            state.meta_pool_redemption_price = 0;
        }
        state.meta_pool_n_coins = registry.get_n_coins(pool);
        state.meta_pool_coin_addresses = registry.get_coins(pool);
        state.meta_pool_balances = registry.get_balances(pool);
        state.meta_pool_coin_decimals = getDecimals(state.meta_pool_coin_addresses);
        state.meta_pool_A = metaPool.A();
        state.meta_pool_fee = metaPool.fee();

        return state;
    }

    function getDecimals(address[8] memory tokens) internal view returns (uint8[8] memory decimals) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0)) {
                try IERC20(tokens[i]).decimals() returns (uint8 tokenDecimals) {
                    decimals[i] = tokenDecimals;
                } catch {
                    decimals[i] = 0;
                }
            }
        }
        return decimals;
    }
}