# Azure Bicep Demos


## Getting Started

* [Install the Bicep CLI](https://github.com/Azure/bicep/blob/main/docs/installing.md) by following the instruction.
* Build the `main.bicep` file by running the Bicep CLI command to generate the ARM template:

```bash
bicep build ./main.bicep
```

## Validate

```bash
az deployment group validate -f main.bicep -g rg-dev-uks-bicep-test --debug
```

## Deploy with Bicep

```bash
az deployment group create -f main.bicep -g rg-dev-uks-bicep-test
```

## Deploy with ARM

```bash
az deployment group create -f main.json -g rg-dev-uks-bicep-test
```
