Param(
  [string] [Parameter(Mandatory=$true)] $alias
)

$vmimagerg =$alias+'-vmimages-rg'


New-AzureRmResourceGroupDeployment -Name "SOE-Lab1-VMDeployment" -ResourceGroupName $vmimagerg -TemplateFile D:\azure\Ready19\Lab2\VM_provisioning\Lab2-SoeVM.json -TemplateParameterObject @{"alias"=$alias}

