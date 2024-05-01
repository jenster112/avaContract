import json

# Read chainId
chainId = input("Enter chainId (default: 80001): ")
if not chainId:
    chainId = "80001"

# Define file path
file_path = f"../../broadcast/deployOP.s.sol/{chainId}/run-latest.json"

# Read JSON file
try:
    with open(file_path, 'r') as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"Unable to find file: {file_path}")
    exit(1)

# Initialize contract map
contract_map = {}

# Iterate over transactions
for tx in data['transactions']:
    if "CREATE" in tx['transactionType']:
        contract_name = tx['contractName']
        contract_address = tx['contractAddress']

        if contract_name == "TransparentUpgradeableProxy":
            contract_map[prev_contract_name] = contract_address
        else:
            contract_map[contract_name] = contract_address
            prev_contract_name = contract_name

# Create contractAddresses.json
output_data = {
    **contract_map,
    "Network": "OP Goerli"
}

with open("contractAddresses.json", 'w') as f:
    json.dump(output_data, f, indent=4)

print("contractAddresses.json created successfully")
