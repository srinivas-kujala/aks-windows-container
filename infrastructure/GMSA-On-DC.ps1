Install-Module -Name AksGMSA -Repository PSGallery -Force

# Module requirements
# The gMSA on AKS  module relies on different modules and tools. In order to install these requirements, run the following on an elevated session:

Install-ToolingRequirements

# Login with your Azure credential
# You will need to be logged in to Azure with your credentials for the gMSA on AKS  module to properly configure your AKS cluster. To log into Azure via , run the following:

Connect-AzAccount -DeviceCode -Subscription "<SUBSCRIPTION_ID>"

# You also need to log in with the Azure CLI, as the  module also uses that in the background:
az login --use-device-code
az account set --subscription "<SUBSCRIPTION_ID>"

# Setting up required inputs for gMSA on AKS module
# Throughout the configuration of gMSA on AKS many inputs will be needed, such as: 
# Your AKS cluster name, Azure Resource Group name, 
# region to deploy the necessary assets, Active Directory domain name, and much more. 
# To streamline the process below, we created an input command that will gather all the necessary values and store it on a variable that will then be used on the commands below.

# To start, run the following:

$params = Get-AksGMSAParameters

# Connect to your AKS cluster
# While using the gMSA on AKS  module, you will be connecting to the AKS cluster you want to configure. 
# The gMSA on AKs  module relies on the kubectl connection. 
# To connect your cluster, run the following: (Notice that because you provided the inputs above, you can simply  and paste the command below into your  session).

 Import-AzAksCredential -Force `
 -ResourceGroupName $params["aks-cluster-rg-name"] `
 -Name $params["aks-cluster-name"]

# Confirm the AKS cluster has gMSA feature properly configured
# Your AKS cluster might or might not be already configured for gMSA. To validate that the cluster is ready for utilization of gMSA, run the following command:

Confirm-AksGMSAConfiguration `
 -AksResourceGroupName $params["aks-cluster-rg-name"] `
 -AksClusterName $params["aks-cluster-name"] `
 -AksGMSADomainDnsServer $params["domain-dns-server"] `
 -AksGMSARootDomainName $params["domain-fqdn"]

# Configure your Active Directory environment
# The first step in preparing your Active Directory, 
# is to ensure the Key Distribution System is configured. 
# For this step, the commands need to be executed with credentials with the proper delegation, against a Domain Controller. 
# This task can be delegated to authorized people.
# 
# From a Domain Controller, run the following to enable the root key:
# 
# For production environments:


# You will need to wait 10 hours before the KDS root key is
# replicated and available for use on all domain controllers.
Add-KdsRootKey -EffectiveImmediately

# For testing environments:

# For single-DC test environments ONLY.
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

# Creates the standard domain user.
New-GMSADomainUser `
 -Name $params["gmsa-domain-user-name"] `
 -Password $params["gmsa-domain-user-password"] `
 -DomainControllerAddress $params["domain-controller-address"] `
 -DomainAdmin "$($params["domain-fqdn"])\$($params["domain-admin-user-name"])" `
 -DomainAdminPassword $params["domain-admin-user-password"]

# Creates the gMSA account, and it authorizes only the standard domain user.
New-GMSA `
 -Name $params["gmsa-name"] `
 -AuthorizedUser $params["gmsa-domain-user-name"] `
 -DomainControllerAddress $params["domain-controller-address"] `
 -DomainAdmin "$($params["domain-fqdn"])\$($params["domain-admin-user-name"])" `
 -DomainAdminPassword $params["domain-admin-user-password"]

# Setup Azure Key Vault and Azure user-assigned Managed Identity
# Azure Key Vault (AKV) will be used to store the credential used by the Windows nodes on AKS to communicate to the Active Directory Domain Controllers. 
# A Managed Identity (MI) will be used to provide proper access to AKV for your Windows nodes.


# The Azure key vault will have a secret with the credentials of the standard
# domain user authorized to fetch the gMSA.
New-GMSAAzureKeyVault `
 -ResourceGroupName $params["aks-cluster-rg-name"] `
 -Location $params["azure-location"] `
 -Name $params["akv-name"] `
 -SecretName $params["akv-secret-name"] `
 -GMSADomainUser "$($params["domain-fqdn"])\$($params["gmsa-domain-user-name"])" `
 -GMSADomainUserPassword $params["gmsa-domain-user-password"]

# Create the Azure user-assigned managed identity
New-GMSAManagedIdentity `
 -ResourceGroupName $params["aks-cluster-rg-name"] `
 -Location $params["azure-location"] `
 -Name $params["ami-name"]

# Grant AKV access to the AKS Windows hosts
# Appends the user-assigned managed identity to the AKS Windows agent pools given as input parameter.
# Configures the AKV read access policy for the user-assigned managed identity.
Grant-AkvAccessToAksWindowsHosts `
 -AksResourceGroupName $params["aks-cluster-rg-name"] `
 -AksClusterName $params["aks-cluster-name"] `
 -AksWindowsNodePoolsNames $params["aks-win-node-pools-names"] `
 -VaultResourceGroupName $params["aks-cluster-rg-name"] `
 -VaultName $params["akv-name"] `
 -ManagedIdentityResourceGroupName $params["aks-cluster-rg-name"] `
 -ManagedIdentityName $params["ami-name"]

# Setup gMSA credential spec with the RBAC resources
# Creates the gMSA credential spec.
# Configures the appropriate RBAC resources (ClusterRole and RoleBinding) for the spec.
# Executes AD commands to get the appropriate domain information for the credential spec.
New-GMSACredentialSpec `
 -Name $params["gmsa-spec-name"] `
 -GMSAName $params["gmsa-name"] `
 -ManagedIdentityResourceGroupName $params["aks-cluster-rg-name"] `
 -ManagedIdentityName $params["ami-name"] `
 -VaultName $params["akv-name"] `
 -VaultGMSASecretName $params["akv-secret-name"] `
 -DomainControllerAddress $params["domain-controller-address"] `
 -DomainUser "$($params["domain-fqdn"])\$($params["gmsa-domain-user-name"])" `
 -DomainUserPassword $params["gmsa-domain-user-password"]

#At this stage, the configuration of gMSA on AKS is completed. You can now deploy your workload on your Windows nodes.