# pragma version 0.3.10
# pragma optimize codesize
# pragma evm-version shanghai
"""
@title Monna Interest Rate Model
@author danil-sergeev, Monna.io
@license Copyright (c) Monna, 2024 - all rights reserved
"""
from math import Math

WAD: constant(uint256) = 10 ** 18
RAY: constant(uint256) = 10 ** 27

math_implementation: Math
optimal_utilization_rate: public(immutable(uint256))
base_borrow_rate: public(immutable(uint256))
rate_slope_1: public(immutable(uint256))
rate_slope_2: public(immutable(uint256))

excess_utilization_rate: public(immutable(uint256))

@external
def __init__(
    _math_implementation: address,
    _optimal_utilization_rate: uint256,
    _base_borrow_rate: uint256,
    _rate_slope_1: uint256,
    _rate_slope_2: uint256
):
    assert _math_implementation != empty(address)

    self.math_implementation = Math(_math_implementation)

    optimal_utilization_rate = self.math_implementation.percent_multiply(WAD, _optimal_utilization_rate)
    excess_utilization_rate = WAD - optimal_utilization_rate

    base_borrow_rate = self.math_implementation.percent_multiply(RAY, _base_borrow_rate)
    rate_slope_1 = self.math_implementation.percent_multiply(RAY, _rate_slope_1)
    rate_slope_2  = self.math_implementation.percent_multiply(RAY, _rate_slope_2)

@external
@view
def calculate_borrow_rate(_available_pool_liquidity: uint256, _expected_pool_liquidity: uint256) -> uint256:
    if _expected_pool_liquidity == 0:
        return base_borrow_rate
    
    if _expected_pool_liquidity < _available_pool_liquidity:
        return base_borrow_rate

    

    utilization_wad: uint256 = self._calculate_utilization_wad(_available_pool_liquidity, _expected_pool_liquidity)

    if utilization_wad < optimal_utilization_rate:
        return base_borrow_rate + ((rate_slope_1 * utilization_wad) / optimal_utilization_rate)
    


    return base_borrow_rate + rate_slope_1 + (rate_slope_2 * (utilization_wad - optimal_utilization_rate)) / excess_utilization_rate

@external
@view
def get_model_parameters() -> (uint256, uint256, uint256, uint256):
    return (
        self.math_implementation.percent_divide(optimal_utilization_rate, WAD),
        base_borrow_rate,
        rate_slope_1,
        rate_slope_2 
    )

@internal
@view
def _calculate_utilization_wad(_available_pool_liquidity: uint256, _expected_pool_liquidity: uint256) -> uint256:
    liquditiy_diff_wad: uint256 = (_expected_pool_liquidity - _available_pool_liquidity) * WAD

    return liquditiy_diff_wad / _expected_pool_liquidity

    
