Param(
  [string] [Parameter(Mandatory=$true)] $alias
)

$vmimagerg =$alias+'-vmimages-rg'


New-AzureRmResourceGroupDeployment -Name "SOE-Lab1-VMDeployment" -ResourceGroupName $vmimagerg -TemplateFile D:\azure\Ready19\Lab2\VM_provisioning\VM-WestuS\Lab2-SoeVM-WestUS.json -TemplateParameterObject @{"alias"=$alias}

