#pragma version 0.3.10
#pragma optimize codesize
#pragma evm-version shanghai
"""
@title monna math helpers implementation
@author danil-sergeev, Monna.io
@license Copyright (c) Monna, 2024 - all rights reserved
"""

percentage_factor: constant(uint256) = 10 ** 4
half_percent: constant(uint256) = (10 ** 4) / 2

@external
@pure
def percent_multiply(_value: uint256, _percentage: uint256) -> uint256:
    if _value == 0:
        return 0
    
    if _percentage == 0:
        return 0
    
    return (_value * _percentage + half_percent) / percentage_factor



@external
@pure
def percent_divide(_value: uint256, _percentage: uint256) -> uint256:
    assert _percentage != 0
    scope_half_percentage: uint256 = _percentage / 2

    return (_value * percentage_factor + scope_half_percentage) / _percentage


@external
@view
def get_percentage_factor() -> uint256:
    return percentage_factor
