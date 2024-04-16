#pragma version 0.3.10
#pragma optimize codesize
#pragma evm-version shanghai
"""
@title Monna Pool Contract
@author danil-sergeev, Monna.io
@license Copyright (c) Monna, 2024 - all rights reserved
"""

from vyper.interfaces import ERC20
from vyper.interfaces import ERC20Detailed
from vyper.interfaces import ERC4626
from interest_rate_model import InterestRateModel
from math import Math

implements: ERC20


# ------------------------------- Interfaces ---------------------------------
interface Factory:
    def fee_receiver() -> address: view
    def admin() -> address: view

interface ERC1271:
    def isValidSignature(_hash: bytes32, _signature: Bytes[65]) -> bytes32: view


# ------------------------------- Events ---------------------------------
event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

event AddLiquidity:
    provisioner: indexed(address)
    amount: uint256

event RemoveLiquidity:
    provisioner: indexed(address)
    amount: uint256

# --------------------------- ERC20 Specific Vars ----------------------------
name: public(immutable(String[64]))
symbol: public(immutable(String[32]))
decimals: public(immutable(uint8))
version: public(constant(String[8])) = "v7.0.0"

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
total_supply: uint256
nonces: public(HashMap[address, uint256])

# keccak256("isValidSignature(bytes32,bytes)")[:4] << 224
ERC1271_MAGIC_VAL: constant(bytes32) = 0x1626ba7e00000000000000000000000000000000000000000000000000000000
EIP712_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")
EIP2612_TYPEHASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")

VERSION_HASH: constant(bytes32) = keccak256(version)
NAME_HASH: immutable(bytes32)
CACHED_CHAIN_ID: immutable(uint256)
salt: public(immutable(bytes32))
CACHED_DOMAIN_SEPARATOR: immutable(bytes32)

# ------------------------------- Pool Variables ---------------
factory: immutable(Factory)
underlying_asset: public(immutable(ERC20))
math_implementation: Math
interest_rate_model: public(InterestRateModel)

timestamp_last_update: uint256

WAD: constant(uint256) = 10 ** 18
RAY: constant(uint256) = 10 ** 27
YEAR_AS_SECONDS: constant(uint256) = 31536000


@external
def __init__(
    _name: String[32],
    _symbol: String[10],
    _decimals: uint8,
    _underlying_asset: address,
    _math_implementation: address,
    _interest_rate_model: address
):
    """
    @notice Initialize Monna pool contract
    """
    assert _underlying_asset != empty(address)
    assert _math_implementation != empty(address)
    assert _interest_rate_model != empty(address)

    self.math_implementation = Math(_math_implementation)
    underlying_asset = ERC20(_underlying_asset)
    factory = Factory(msg.sender)

    name = _name
    symbol = _symbol
    decimals = _decimals
    # ----------------- EIP712 related params -----------------
    NAME_HASH = keccak256(name)
    salt = block.prevhash
    CACHED_CHAIN_ID = chain.id
    CACHED_DOMAIN_SEPARATOR = keccak256(
        _abi_encode(
            EIP712_TYPEHASH,
            NAME_HASH,
            VERSION_HASH,
            chain.id,
            self,
            salt,
        )
    )


    self.timestamp_last_update = block.timestamp
    self._update_interest_rate_model(_interest_rate_model)

    log Transfer(empty(address), msg.sender, 0)

# ---------------------------- ERC20 Utils -----------------------------------
@view
@internal
def _domain_separator() -> bytes32:
    if chain.id != CACHED_CHAIN_ID:
        return keccak256(
            _abi_encode(
                EIP712_TYPEHASH,
                NAME_HASH,
                VERSION_HASH,
                chain.id,
                self,
                salt,
            )
        )
    return CACHED_DOMAIN_SEPARATOR

@internal
def _transfer(_from: address, _to: address, _value: uint256):
    # # NOTE: vyper does not allow underflows
    # #       so the following subtraction would revert on insufficient balance
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value

    log Transfer(_from, _to, _value)

@internal
def _burnFrom(_from: address, _burn_amount: uint256):
    self.total_supply -= _burn_amount
    self.balanceOf[_from] -= _burn_amount
    log Transfer(_from, empty(address), _burn_amount)


@external
@nonreentrant('lock')
def add_liquidity(add_amount: uint256):
    assert add_amount > 0
    balance_before: uint256 = underlying_asset.balanceOf(self)

    underlying_asset.transferFrom(
        msg.sender,
        self,
        add_amount
    )

    mint_amount: uint256 = underlying_asset.balanceOf(self) - balance_before
    self.total_supply += mint_amount
    self.balanceOf[msg.sender] += mint_amount
    log Transfer(empty(address), msg.sender, mint_amount)
    log AddLiquidity(msg.sender, add_amount)

    # TODO: update borrow rates when credit layer is implemented
    

@external
@nonreentrant('lock')
def remove_liquidity(remove_amount: uint256) -> uint256:
    assert remove_amount > 0

    underlying_asset_amount: uint256 = self.get_pool_token_exchange_rate() * remove_amount
    underlying_asset.transfer(
        msg.sender,
        remove_amount
    )

    self._burnFrom(msg.sender, underlying_asset_amount)
    # TODO: update borrow rates when credit layer is implemented

    log RemoveLiquidity(msg.sender, remove_amount)
    return underlying_asset_amount



@external
@view
def get_pool_liquidity() -> uint256:
    return underlying_asset.balanceOf(self)


@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    self._transfer(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @dev Transfer tokens from one address to another.
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    self._transfer(_from, _to, _value)

    _allowance: uint256 = self.allowance[_from][msg.sender]
    if _allowance != max_value(uint256):
        _new_allowance: uint256 = _allowance - _value
        self.allowance[_from][msg.sender] = _new_allowance
        log Approval(_from, msg.sender, _new_allowance)

    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @notice Approve the passed address to transfer the specified amount of
            tokens on behalf of msg.sender
    @dev Beware that changing an allowance via this method brings the risk that
         someone may use both the old and new allowance by unfortunate transaction
         ordering: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will transfer the funds
    @param _value The amount of tokens that may be transferred
    @return bool success
    """
    self.allowance[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)
    return True


@external
def increaseAllowance(_spender: address, _value: uint256) -> bool:
    """
    @notice Increase the allowance of the passed address to spend the total amount of tokens
        on behalf of `msg.sender`. This method mitigates the risk that someone may use both
        the old and the new allowance by unfortunate transaction ordering.
        See https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds
    @param _value The amount of tokens to increase the allowance by
    @return True
    """
    assert _spender != empty(address)
    allowance: uint256 = self.allowance[msg.sender][_spender] + _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True

@external
def decreaseAllowance(_spender: address, _value: uint256) -> bool:
    """
    @notice Decrease the allowance of the passed address to spend the total amount of tokens
        on behalf of `msg.sender`. This method mitigates the risk that someone may use both
        the old and the new allowance by unfortunate transaction ordering.
        See https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds
    @param _value The amount of tokens to decrease the allowance by
    @return True
    """
    assert _spender != empty(address)
    allowance: uint256 = self.allowance[msg.sender][_spender]
    if _value > allowance:
        allowance = 0
    else:
        allowance -= _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True



@view
@external
def totalSupply() -> uint256:
    """
    @notice The total supply of pool LP tokens
    @return self.total_supply, 18 decimals.
    """
    return self.total_supply


@internal
def _update_interest_rate_model(
    _interest_rate_model: address
):
    self.interest_rate_model = InterestRateModel(_interest_rate_model)

@internal
def _get_linear_accumulated(
    cumulative: uint256,
    borrow_rate: uint256,
    time_diff: uint256
) -> uint256:
    return RAY + (borrow_rate * time_diff) / YEAR_AS_SECONDS


@internal
@view
def get_pool_token_exchange_rate() -> uint256:
    return 1

@internal
def calculate_linear_index(
    cumulative: uint256,
    borrow_rate: uint256,
    time_diff: uint256
) -> uint256:
    linear_accum: uint256 = self._get_linear_accumulated(
        cumulative,
        borrow_rate,
        time_diff
    )

    return (cumulative * linear_accum) / RAY