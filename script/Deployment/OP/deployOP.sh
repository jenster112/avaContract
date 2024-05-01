#!/bin/sh

# Deploy forge
# Check if the test variable is passed as an argument
if [ "$1" = "test" ]; then
  test=true
else
  test=false
fi

# Run the test only if the test variable is set to true
if [ "$test" = true ]; then

    # Check if forge is installed
    if ! [ -x "$(command -v forge)" ]; then
        echo "forge is not installed. please install it first"
        echo "Exiting script..."
           exit 1
    else 
        echo "forge is present."
    fi
    # run forge command for test-cases only
    echo "executing forge Deploy command"
    echo "script ./scripts/Deployment/deployOP.s.sol --rpc-URL $OPTIMISM_GOERLI_RPC_URL --broadcast -vvvv"
    forge script ./scripts/Deployment/deployOP.s.sol:DeployScript --rpc-url $OPTIMISM_GOERLI_RPC_URL --broadcast -vvvv
    
    # Check the exit status of the command
    if [ $? -ne 0 ]; then
    echo "An error occurred while running the command. Exiting...."
    exit 1
    fi
fi

# Check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
    read -p "jq is not installed, do you want to install it? (y/n): " choice
    if [ "$choice" == "y" ]; then
        sudo apt-get install -y jq
    else
        echo "Exiting script..."
        exit 1
    fi
fi

# Check if bc is installed
if ! [ -x "$(command -v bc)" ]; then
  read -p "jq is not installed, do you want to install it? (y/n): " install_bc
  if [ "$install_bc" = "y" ]; then
    # Install bc, assuming a Debian-based system
    sudo apt-get install bc
  else
    echo "Exiting script."
    exit 1
  fi
fi

# Get chainId
read -p "Enter chainId (default: 420): " chainId
chainId=${chainId:-420}

# Define file path
file="./broadcast/DeployWithOracle.s.sol/$chainId/run-latest.json"

# Check if file exists
if [ ! -f "$file" ]; then
    echo "Unable to find file: $file"
    echo "pwd: $(pwd)"
    exit 1
fi


# Fetch the first element in the array
array_length=$(jq '.transactions | length' $file)
echo "Length of the 'transactions' array is: $array_length"
echo "Removing Contract Address .json" 
rm -f ./contractAddresses.json 

# Iterate over the "transactions" array
for i in $(seq 0 $((array_length-1))); do
    # Get the "transactionType" value of the current index
    num=`expr $i`
    transactionType=$(cat $file | jq -r '.transactions['$num'].transactionType')
    echo "transaction type is $transactionType"

    if echo "$transactionType" | grep -q "CREATE"; then
        contractNames=$(cat $file | jq -r '.transactions['$num'].contractName')
        contractAddresses=$(cat $file | jq -r '.transactions['$num'].contractAddress')
        echo "contract name is $contractNames and address is $contractAddresses"
        # fetching the Block Number from the receipt
        blockNumberHex=$(cat $file | jq -r '.receipts[0].blockNumber')
        echo "blockNumber in hex is: $blockNumberHex"
        
        blockNumberDecimal=$(echo $(($blockNumberHex)))
        echo "Block Number in decimal: $blockNumberDecimal"
        #Create contractAddresses.json file
        if ! [ -f "contractAddresses.json" ];
        then 
            echo "{" >> contractAddresses.json
        fi
        #echo "checking array length ${array_length}"
        echo "\"$contractNames\":\"$contractAddresses\"," >> contractAddresses.json
        echo "\"${contractNames}StartBlock\":\"$blockNumberDecimal\"," >> contractAddresses.json
        echo "contractAddresses.json created successfully"
    fi
    if [ $num -eq $((array_length-1)) ]; then
        echo "\"ApiVersion\": \"0.0.7\"," >> contractAddresses.json
        echo "\"Network\": \"mumbai\"" >> contractAddresses.json
        echo "}" >> contractAddresses.json 
    fi
done