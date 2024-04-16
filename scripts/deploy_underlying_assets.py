import os
import sys
from rich.console import Console as RichConsole
from eth_account import Account
import boa
from boa.network import NetworkEnv
from dotenv import load_dotenv

load_dotenv()

logger = RichConsole(file=sys.stdout)

asset_data = [
    {
        "name": "USD Coin",
        "symbol": "USDC",
        "decimals": 18
        # 0x647a310a1116b80fFaA83cBBeB2AE4B73D2308c0
    },
    {
        "name": "iSEI",
        "symbol": "iSEI",
        "decimals": 18
        # 0x3e573f1D81ed534FB9fD9DE5604E91c133D395B8
    },
    {
        "name": "Wrapped Bitcoin",
        "symbol": "WBTC",
        "decimals": 8
        # 0x00B575Ee5cfaE5af0EF1a313A733cdF5135CDDfd
    }
]


def deploy_assets():
    for asset in asset_data:
        with open("./contracts/mocks/erc20.vy") as f:
            source = f.read()
            contract_obj = boa.loads_partial(source_code=source)

            assetName = asset["name"]
            assetSymbol = asset["symbol"]
            assetDecimals = asset["decimals"]

            logger.log(f"Deployng {assetName}")
            contract_args = [assetName, assetSymbol, assetDecimals]
            contract = contract_obj.deploy(*contract_args)
            logger.log(f"Deploy token at {contract.address}")


def main():
    sei_devnet_url = os.environ.get("SEI_RPC_URL")
    logger.log(f"Using rpc URL: {sei_devnet_url}")
    boa.set_network_env(sei_devnet_url)
    boa.env.add_account(Account.from_key(os.environ.get("SENDER_PRIVATE_KEY")))
    deploy_assets()

if __name__ == "__main__":
    main()