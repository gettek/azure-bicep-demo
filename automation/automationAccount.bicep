param p_shortEnv string

resource automation_acount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name                 : '${toUpper(p_shortEnv)}-AutomationAccount'
  properties           : {
    sku                : {
      name             : 'Free'
    }
    publicNetworkAccess: false
  }
  location             : resourceGroup().location
  identity             : {
    type               : 'SystemAssigned'
  }
  tags: {}
}

output identity string = automation_acount.identity.principalId
output agentEndpoint string = reference(automation_acount.id, '2018-01-15').RegistrationUrl
output aaPrimaryKey string = listKeys(automation_acount.id, '2015-10-31').keys[0].Value

