$resourceGroup = "aks-win-gmsa"

az deployment group delete --resource-group $resourceGroup --name aks-win-gmsa-deployment --no-wait

# wait for connection to be ready
Start-Sleep -Seconds 5

az group delete --resource-group $resourceGroup --yes --no-wait