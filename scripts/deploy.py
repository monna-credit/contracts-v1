import os
import sys
from rich.console import Console as RichConsole
from ape import accounts, project

import boa
from boa.network import NetworkEnv
from eth_abi import encode
from eth_account import Account
from eth_typing import Address
# sphere shop enlist jaguar glance gospel donate floor clean off addict memory
# MONNAQUE 0xd47378694be4a8ac129C1326f2982CC1661754CB

logger = RichConsole(file=sys.stdout)


deployments = {
    # Sei Devnet
    "sei:devnet": {
        "math": "",
        "interest_rate_model": "",
        "pool": "",
        "pool_factory": ""
    }
}

ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

owner_account = accounts.load("MONNAQUE")
fee_receiver = accounts.load("MONNAQUE_FEES")


def get_contract_obj(contract_file):
    with open(contract_file, "r") as f:
        source = f.read()

    return boa.loads_partial(source_code=source)

def check_and_deploy(contract_obj, contract_designation, network, blueprint: bool = False, args=[]):
    deployed_contract = deployments[network][contract_designation]

    if not deployed_contract:
        logger.log(f"Deploying {contract_designation} contract ...")
        if not blueprint:
            contract = contract_obj.deploy(*args)
        else:
            contract = contract_obj.deploy_as_blueprint()
        logger.log(f"Deployed! At: {contract.address}.")
    else:
        logger.log(f"Deployed {contract_designation} contract exists. Using {deployed_contract} ...")
        contract = contract_obj.at(deployed_contract)

    return contract



def deploy(network):
    logger.log(f"Deploying pool factory on {network} ...")

    # non-blueprint contracts
    math_contract_obj = get_contract_obj("./contracts/math.vy")
    math_contract = check_and_deploy(math_contract_obj, "math", network)

    interest_rate_model_contract_obj = get_contract_obj("./contracts/interest_rate_model.vy")
    interest_rate_model_contract_args = [math_contract.address, 10000, 10000, 10000, 10000]
    interest_rate_model_contract = check_and_deploy(
        interest_rate_model_contract_obj, 
        "interest_rate_model",
        network,
        False,
        interest_rate_model_contract_args    
    )

    # blueprint contracts
    pool_contract_obj = get_contract_obj("./contracts/pool.vy")
    pool_blueprint = check_and_deploy(pool_contract_obj, "pool", network, blueprint=True)

    # factory
    pool_factory_contract_obj = get_contract_obj("./contracts/pool_factory.vy")
    pool_factory_contract_args = [
        fee_receiver.address,
        owner_account.address
    ]

    pool_factory_contract = check_and_deploy(
        pool_factory_contract_obj, 
        "pool_factory",
        network, 
        False,
        pool_factory_contract_args
    )

    pool_factory_contract.set_pool_implementation(pool_blueprint.address)
    pool_factory_contract.set_math_implementation(math_contract.address)
    logger.log(f"Pool implementation address within factory: {pool_factory_contract.pool_implementation()}")
    logger.log(f"Math implementation address within factory: {pool_factory_contract.math_implementation()}")


def main():
    sei_devnet_url = os.environ["SEI_RPC_URL"]
    boa.set_network_env(sei_devnet_url)
    boa.env.add_account(Account.from_key(os.environ["SENDER_PRIVATE_KEY"]))

    deploy("sei:devnet")


if __name__ == "__main__":
    main()