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

var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)

var WebSiteInfo = (contains(DeploymentInfo, 'WebSiteInfo') ? DeploymentInfo.WebSiteInfo : [])

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, ws.name))
  saName: toLower('${DeploymentURI}sa${ws.saname}')
}]

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
var myAppConfig = {
  abc: 'value'
  def: 'value'
}

resource appsettingsCurrent 'Microsoft.Web/sites/config@2021-01-15' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-ws${ws.Name}/appsettings'
}]

module website 'x.appService.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    OMSworkspaceID: OMSworkspaceID
    diagLogs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      // supported on premium
      // {
      //   category: 'AppServiceFileAuditLogs'
      //   enabled: true
      //   retentionPolicy: {
      //     days: 30
      //     enabled: false
      //   }
      // }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
  }
}]

module websiteSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    appConfigCustom: myAppConfig
    appConfigCurrent: appsettingsCurrent[index].list().properties
    appConfigNew: {
      APPINSIGHTS_INSTRUMENTATIONKEY: reference(AppInsightsID, '2015-05-01').InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(AppInsightsID, '2015-05-01').InstrumentationKey}'
    }
  }
  dependsOn: [
    website[index]
  ]
}]
