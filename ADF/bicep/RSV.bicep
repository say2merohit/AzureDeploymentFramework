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

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var RSVInfo = [
  {
    Name: 'Vault01'
    skuName: 'RS0'
    skuTier: 'Standard'
  }
]

resource RSV 'Microsoft.RecoveryServices/vaults@2021-01-01' = [for i in range(0, length(RSVInfo)): if (Stage.RSV == 1) {
  location: resourceGroup().location
  name: '${DeploymentURI}${RSVInfo[i].Name}'
  sku: {
    name: RSVInfo[i].skuName
    tier: RSVInfo[i].skuTier
  }
  properties: {}
}]

resource RSVDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for i in range(0, length(RSVInfo)): if (Stage.RSV == 1) {
  name: 'service'
  scope: RSV[i]
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'AzureBackupReport'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryJobs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryEvents'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicatedItems'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicationStats'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryRecoveryPoints'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicationDataUploadRate'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryProtectedDiskDataChurn'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}]
