#pragma version ^0.3.10
#pragma optimize codesize
#pragma evm-version shanghai

"""
@title Monna address provider
@author danil-sergeev, Monna.io
@license Copyright (c) Monna, 2024 - all rights reserved
"""

owner: public(address)
_addresses: HashMap[Bytes[32], address]

POOL_FACTORY: constant(Bytes[32]) = b"POOL_FACTORY"
PRICE_ORACLE: constant(Bytes[32]) = b"PRICE_ORACLE"

@external
def __init__():
    self.owner = msg.sender


@external
def set_address(id: Bytes[32], new_address: address):
    assert msg.sender == self.owner
    self._addresses[id] = new_address

@internal
@view
def _get_address_by_id(id: Bytes[32]) -> address:
    assert self._addresses[id] != empty(address)
    return self._addresses[id]

@external
@view
def get_pool_factory() -> address:
    return self._get_address_by_id(POOL_FACTORY)


@external
@view
def get_price_oracle() -> address:
    return self._get_address_by_id(PRICE_ORACLE)
