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
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var frontDoorInfo = contains(DeploymentInfo, 'frontDoorInfo') ? DeploymentInfo.frontDoorInfo : []

var frontDoor = [for i in range(0, length(frontDoorInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.fd.Name))
}]

module FD 'FD-frontDoor.bicep'= [for (fd,index) in frontDoorInfo: if (frontDoor[index].match) {
  name: 'dp${Deployment}-FD-Deploy${((length(frontDoorInfo) == 0) ? 'na' : fd.name)}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Environment: Environment
    frontDoorInfo: fd
    Global: Global
    Stage: Stage
    OMSworkspaceID: OMSworkspaceID
  }
}]
