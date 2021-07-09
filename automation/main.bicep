targetScope = 'subscription'

param p_shortEnv string = 'autotst'

var v_longLocation  = 'uksouth'
var v_shortLocation = 'uks'

resource rg_automation 'Microsoft.Resources/resourceGroups@2021-01-01' = {
    name    : '${v_shortLocation}-${p_shortEnv}-ss-automation-rg'
    location: v_longLocation
}

module automation 'automationAccount.bicep' = {
    name: 'automation-account'
    scope: rg_automation
    params: {
        p_shortEnv: p_shortEnv
    }
}

module storage 'storageAccount.bicep' = {
    name: 'storage-account'
    scope: rg_automation
    params: {
        p_shortEnv: p_shortEnv
        p_identity: automation.outputs.identity
    }
}
