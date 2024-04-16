#pragma version ^0.3.10
#pragma optimize codesize
#pragma evm-version shanghai

"""
@title More Monna LP provision token factory
@author danil-sergeev, Monna.io
@license Copyright (c) Monna, 2024 - all rights reserved
"""

from vyper.interfaces import ERC20Detailed

#  <-- Interfaces -->


# blue print implementations
pool_implementation: public(address)
math_implementation: public(address)

# asset adddress -> pools for provision
pool_data: public(HashMap[address, address])
pool_count: public(uint256)


# fee receiver for all pools
fee_receiver: public(address)

# proxy admin
admin: public(address)
future_admin: public(address)

@external
def __init__(
    _fee_receiver: address,
    _owner: address
):
    assert _fee_receiver != empty(address)
    assert _owner != empty(address)

    self.fee_receiver = _fee_receiver
    self.admin = _owner


# <-- Pool Deployers -->
@external
def deploy_pool(
    _name: String[32],
    _symbol: String[10],
    _underlying_asset: address
) -> address:
    assert self.pool_implementation != empty(address)
    assert self.math_implementation != empty(address)
    assert _underlying_asset != empty(address)

    decimals: uint8 = ERC20Detailed(_underlying_asset).decimals()

    new_pool: address = create_from_blueprint(
        self.pool_implementation,
        _name,
        _symbol,
        decimals,
        _underlying_asset,
        self.math_implementation,
        code_offset=3
    )

    length: uint256 = self.pool_count
    self.pool_data[_underlying_asset] = new_pool
    self.pool_count = length + 1
    return new_pool

# <-- Admin Functionality -->
@external
def set_pool_implementation(
    _implementation: address 
):
    assert msg.sender == self.admin
    assert _implementation != empty(address)
    self.pool_implementation = _implementation

@external
def set_math_implementation(
    _implementation: address
):
    assert msg.sender == self.admin
    assert _implementation != empty(address)
    self.math_implementation = _implementation

@external
def set_fee_receiver(_fee_receiver: address):
    """
    @notice Set fee receiver for all pools
    @param _fee_receiver Address that fees are sent to
    """
    assert msg.sender == self.admin  # dev: admin only
    self.fee_receiver = _fee_receiver

@external
def commit_transfer_ownership(_addr: address):
    """
    @notice Transfer ownership of this contract to `addr`
    @param _addr Address of the new owner
    """
    assert msg.sender == self.admin  # dev: admin only
    self.future_admin = _addr


@external
def accept_transfer_ownership():
    """
    @notice Accept a pending ownership transfer
    @dev Only callable by the new owner
    """
    _admin: address = self.future_admin
    assert msg.sender == _admin  # dev: future admin only

    self.admin = _admin
    self.future_admin = empty(address)
