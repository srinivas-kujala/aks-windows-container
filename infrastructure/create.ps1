$resourceGroup = "aks-win-gmsa"
$location = "East US"

az group create --name $resourceGroup --location $location

# wait for connection to be ready
Start-Sleep -Seconds 5

az deployment group create --resource-group $resourceGroup `
    --name aks-win-gmsa-deployment `
    --template-file .\main.bicep `
    --parameters .\main.bicepparam