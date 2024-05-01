import json

# Define file path
file_path = f"../../../broadcast/deployBase.s.sol/8453/run-latest.json"

# Read JSON file
try:
    with open(file_path, 'r') as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"Unable to find file: {file_path}")
    exit(1)

# Initialize contract map
contract_map = {}
trancheCounter  = 0
veTrancheCounter = 0

# Iterate over transactions
for tx in data['transactions']:
    if "CREATE" in tx['transactionType']:
        contract_name = tx['contractName']
        contract_address = tx['contractAddress']

        if contract_name == "TransparentUpgradeableProxy":
            contract_map[prev_contract_name] = contract_address
        else:
            if contract_name == "Tranche":
                if trancheCounter == 0:
                    prev_contract_name = "JuniorTranche"
                    trancheCounter = 1
                    continue
                elif trancheCounter == 1:
                    prev_contract_name = "SeniorTranche"
                    trancheCounter = 2
                    continue
            if contract_name == "VeTranche":
                if veTrancheCounter == 0:
                    prev_contract_name = "JuniorVeTranche"
                    veTrancheCounter = 1
                    continue
                elif veTrancheCounter == 1:
                    prev_contract_name = "SeniorVeTranche"
                    veTrancheCounter = 2
                    continue
            contract_map[contract_name] = contract_address
            prev_contract_name = contract_name

# Create contractAddresses.json
output_data = {
    **contract_map,
    "Network": "Base Sepolia"
}

with open("contractAddressesBase.json", 'w') as f:
    json.dump(output_data, f, indent=4)

print("contractAddressesBase.json created successfully")
