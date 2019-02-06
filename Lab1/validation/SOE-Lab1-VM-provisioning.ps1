Param(
  [string] [Parameter(Mandatory=$true)] $alias
)

$vmimagerg =$alias+'-vmimages-rg'


New-AzureRmResourceGroupDeployment -Name "SOE-Lab1-VMDeployment" -ResourceGroupName $vmimagerg -TemplateUri 'https://msreadylabs.blob.core.windows.net/workshop/Lab1-SoeVM.json' -TemplateParameterObject @{"alias"=$alias}

