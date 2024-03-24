#Validation
#The gMSA on AKS  module provides a command to validate if the settings for your environment are properly configured. Validate that the gMSA credential spec works with the following command:

Start-GMSACredentialSpecValidation `
 -SpecName $params["gmsa-spec-name"] `
 -AksWindowsNodePoolsNames $params["aks-win-node-pools-names"]

# Collect gMSA logs from your Windows nodes
# The following command can be used to extract logs from the Windows hosts:

# Extracts the following logs from each Windows host:
# - kubelet logs.
# - CCG (Container Credential Guard) logs (as a .evtx file).
Copy-WindowsHostsLogs -LogsDirectory $params["logs-directory"]

# The logs will be copied from each Windows hosts to the local directory $params["logs-directory"]. 
# The logs directory will have a subdirectory named after each Windows agent host. 
# The CCG (Container Credential Guard) .evtx log file can be properly inspected in the Event Viewer, only after the following requirements are met:
# The Containers Windows feature is installed. It can be installed via  using the following command:

# Validate AKS agent pool access to Azure Key Vault
# Your AKS node pools need to be able to access the Azure Key Vault secret in order to use the account that can retrieve the gMSA on Active Directory. It's important that you have configured this access correctly so your nodes can communicate with your Active Directory Domain Controller. Fail to access the secrets means your application won't be able to authenticate. On the other hand, you might want to ensure no access is given to node pools that don't necessarily need it.
# 
# The gMSA on AKS PowerShell module allows you to validate which node pools have access to which secrets on Azure Key Vault.
Get-AksAgentPoolsAkvAccess `
 -AksResourceGroupName $params["aks-cluster-rg-name"] `
 -AksClusterName $params["aks-cluster-name"] `
 -VaultResourceGroupNames $params["aks-cluster-rg-name"]