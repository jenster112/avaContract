#!/bin/sh

# Get chainId
read -p "Enter chainId (default: 80001): " chainId
chainId=${chainId:-80001}

# Define file path
file="../../broadcast/deployOP.s.sol/$chainId/run-latest.json"

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
rm -f ./addresses.json

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
        #Create addresses.jsonfile
        if ! [ -f "addresses.json" ];
        then 
            echo "{" >> addresses.json
        fi
        echo "\"$contractNames\":\"$contractAddresses\"," >> addresses.json
        echo "addresses.jsoncreated successfully"
    fi
    if [ $num -eq $((array_length-1)) ]; then
        echo "\"ApiVersion\": \"0.0.7\"," >> addresses.json
        echo "\"Network\": \"mumbai\"" >> addresses.json
        echo "}" >> addresses.json
    fi
done
