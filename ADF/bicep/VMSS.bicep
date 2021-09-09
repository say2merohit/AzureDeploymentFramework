@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var DataDiskInfo = computeGlobal.DataDiskInfo
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var VMSizeLookup = {
  D: 'D'
  I: 'D'
  U: 'P'
  P: 'P'
  S: 'S'
}
var DeploymentName = deployment().name
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var storageAccountType = ((Environment == 'P') ? 'Premium_LRS' : 'Standard_LRS')
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VNetID = resourceId(subscriptionId, resourceGroupName, 'Microsoft.Network/VirtualNetworks', '${Deployment}-vn')
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var AppInsightsName = replace('${Deployment}AppInsights', '-', '')
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)
var SADiagName = toLower('${replace(Deployment, '-', '')}sadiag')
var SAAppDataName = toLower('${replace(Deployment, '-', '')}sadata')
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts/', SADiagName)
var saaccountidglobalsource = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${Global.HubRGName}/providers/Microsoft.Storage/storageAccounts/${Global.SAName}'
var Domain = split(Global.DomainName, '.')[0]
var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
  VMAppSS: 'AppServers'
}
var AppServers = contains(DeploymentInfo, 'AppServersVMSS') ? DeploymentInfo.AppServersVMSS : []
var azureActiveDirectory = {
  clientApplication: Global.clientApplication
  clusterApplication: Global.clusterApplication
  tenantId: subscription().tenantId
}
var secrets = [
  {
    sourceVault: {
      id: resourceId(Global.HubRGName, 'Microsoft.KeyVault/vaults', Global.KVName)
    }
    vaultCertificates: [
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'My'
      }
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'Root'
      }
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'CA'
      }
    ]
  }
]
var userAssignedIdentities = {
  Cluster: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
}
var vmss = [for (vm, index) in AppServers: {
  match: ((Global.CN == '.') || contains(Global.CN, vm.Name))
}]

var VM = [for (vm, index) in AppServers: {
  name: vm.Name
  Extensions: (contains(OSType[vm.OSType], 'RoleExtensions') ? union(Extensions, OSType[vm.OSType].RoleExtensions) : Extensions)
  DataDisk: (contains(vm, 'DDRole') ? DataDiskInfo[vm.DDRole] : json('null'))
  NodeType: toLower(concat(Global.AppName, vm.Name))
  vmHostName: toLower('${Environment}${DeploymentID}${vm.Name}')
  Name: '${Prefix}${Global.AppName}-${Environment}${DeploymentID}-${vm.Name}'
  Primary: vm.IsPrimary
  durabilityLevel: vm.durabilityLevel
  placementProperties: vm.placementProperties
}]

module DISKLOOKUP 'y.disks.bicep' = [for (vm,index) in AppServers: {
  name: 'dp${Deployment}-VMSS-diskLookup${vm.Name}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Name: vm.Name
    DATASS: (contains(DataDiskInfo[vm.DDRole], 'DATASS') ? DataDiskInfo[vm.DDRole].DATASS : json('{"1":1}'))
    Global: Global
  }
}]

module VMSS 'VMSS-VM.bicep' = [for (vm,index) in AppServers: if (vmss[index].match) {
  name: 'dp${Deployment}-VMSS-Deploy${vm.Name}'
  params: {
    Deployment: Deployment
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    AppServer: vm
    VM: VM[index]
    Global: Global
    Stage: Stage
    OMSworkspaceID: OMSworkspaceID
    vmAdminPassword: vmAdminPassword
    devOpsPat: devOpsPat
    sshPublic: sshPublic
  }
}]
