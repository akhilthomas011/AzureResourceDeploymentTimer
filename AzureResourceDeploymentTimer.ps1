<#
        .SYNOPSIS
        Gets the first audit log incident timelines associated with Azure Resources.

        .DESCRIPTION
        Fetches the timeline associated with the first incident of Azure Resources in a Resource Group.

        .PARAMETER ResourceGroupName
        Specifies the name of the Resource Group under investigation.

        .PARAMETER ExcludedCallers
        Specifies the callers of the event to be excluded from the list

        .INPUTS
        None. You cannot pipe objects to Get-AzureResourceFirstEvent.

        .OUTPUTS
        System.Object. Get-AzureResourceTimeline returns an object with the details of event.

        .EXAMPLE
        PS> . .\AzureResourceDeploymentTimer.ps1 -ResourceGroupName "myRG" -excludedCallers "8efc3a47-f464-4194-b518-861c4c9b143d","8efc4a47-f464-4193-b518-861c4c9b143d"
        EventTimestamp         ResourceEvent                                             TimeElapsed
        --------------         -------------                                             -----------
        18-05-2021 05:29:24 PM resourceGroups/RBAC_Validator-RG                          00:00:00:00
        18-05-2021 05:33:23 PM deployments/Microsoft.Template-20210518230322             00:00:03:59
        18-05-2021 05:33:29 PM deployments/Microsoft.Template-20210518230328             00:00:04:05
        18-05-2021 05:33:37 PM storageAccounts/bootdiagsy7he5hkzvlz5m                    00:00:04:13
        18-05-2021 05:33:45 PM networkSecurityGroups/default-NSG                         00:00:04:21
        18-05-2021 05:33:45 PM publicIPAddresses/myPublicIP                              00:00:04:21


        .LINK
        Online version: NA

#>


[CmdletBinding()]
param (

    [Parameter(Position = 0, mandatory = $true)]
    [String]
    $resourceGroupName,

    [Parameter(Position = 1, mandatory = $false)]
    [Array]
    $excludedCallers


)


#Azure Resource creation order
Function Get-AzureResourceDeploymentTimer ([String]$resourceGroupName,[Array]$excludedCallers){
    #Connect to Azure
    Connect-AzAccount
    #Get the Audit details
    $auditDetails = Get-AzLog -ResourceGroupName $resourceGroupName | where{$_.Caller -notin $excludedCallers} |
                    ` Select-Object EventTimeStamp, Caller, @{n='Operation'; e={$_.OperationName.value}}, @{n='Status'; e={$_.Status.value}},
                    ` @{n='ResourceType'; e={$_.authorization.scope.Split('/')[-2]}},@{n='ResourceName'; e={$_.authorization.scope.Split('/')[-1]}}
    #Sort the events based on Timestamp
    $sortedEvents = $auditDetails | Select-Object EventTimestamp, @{n='ResourceEvent'; e={$_.ResourceType+'/'+$_.ResourceName}} |
                    ` Sort-Object EventTimestamp
    #Get the unique events
    $sortedUniqueEvents=@()
    for($i=0;$i -lt $($sortedEvents.count);$i++){
        if($($sortedEvents[$i].ResourceEvent) -notin $($sortedUniqueEvents.ResourceEvent)){
            $sortedUniqueEvents+=$sortedEvents[$i]
        }
    }
    #Add TimeElapsed property
    for($i=0;$i -lt $($sortedUniqueEvents.count);$i++){
        $timeDifference= New-TimeSpan -Start $($sortedUniqueEvents[$i].EventTimestamp) -End $($sortedUniqueEvents[0].EventTimestamp)
        $sortedUniqueEvents[$i] | Add-Member -NotePropertyMembers @{TimeElapsed=$($timeDifference.ToString("dd\:hh\:mm\:ss"))}
    }

    #Return the object
    return $sortedUniqueEvents
}


Get-AzureResourceDeploymentTimer $resourceGroupName $excludedCallers
