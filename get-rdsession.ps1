function get-rdsession {
    [CmdletBinding()]
param (
	[parameter(Position=0,
        Mandatory=$false,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="ComputerName")]
        [string[]]$ComputerName,

	[parameter(Position=0,
        Mandatory=$false,
        ValueFromPipeline=$true,
        ParameterSetName="PSSession")]
        [System.Management.Automation.Runspaces.PSSession[]]$PSSession
)

Begin {
    $SessionList = @()

}

Process {
    Switch ($PSCmdlet.ParameterSetName)
        {
            "ComputerName" {
                if ($computerName -eq $null) {
                    $queryResults = (quser 2>$null)
                } else {
                    # Run quser and parse the output 
	                $queryResults = (quser /server:$ComputerName 2>$null)
                }
            }
            "PSSession" {
                $queryresults = (Invoke-command -Session $PSSession -ScriptBlock {quser 2>$null})
                $ComputerName = $PSSession.ComputerName
            }
        }

        if ($queryresults) {
            $sessionList += (ConvertTo-RDSession $queryResults $ComputerName)
        } else { 
            Write-Error "Error.  Unable to retrieve RD Sessions from $ComputerName" 
        }
}

End {
    write-output $SessionList
}  
}

class RDSession {
	[string]$SessionName
	[string]$Username
	[int]$ID
	[string]$State
	[TimeSpan]$IdleTime
	[datetime]$LogonTime
	[string]$ComputerName
    Logoff () {
        $logoffcmd = "logoff.exe $this.ID /server:$this.computername"
        invoke-command -ScriptBlock {$logoffcmd} 
    }
  
}

#Function to convert from RD Idle Time (DD+HH:mm) format into PS TimeSpan type
function ConvertTo-TimeSpan {
    param (
        [string]$RDIdleSpan
    )
    #Non Idle sessions report . instead of 0.  Change to 0 if idle.
    $RDIdleSpan= $RDIdleSpan.replace(".","0")
    if ($RDIdleSpan -eq "None") {$RDIdleSpan = 0}

	$IdleDays = 0
	$IdlePlus = $RDIdleSpan.indexof("+")
	if ($IdlePlus -ne -1) {
		$IdleDays = $RDIdleSpan.substring(0,$IdlePlus)
		$RDIdleSpan = $RDIdleSpan.substring($idleplus+1)
	}
	$IdleHours = 0
	$IdleColon = $RDIdleSpan.indexof(":")
	if ($IdleColon -ne -1) {
		$IdleHours = $RDIdleSpan.substring(0,$IdleColon)
		$RDIdleSpan = $RDIdleSpan.substring($IdleColon+1)
	}
	$IdleMinutes = $RDIdleSpan

    write-output (New-Timespan -Days $IdleDays -Hours $IdleHours -Minutes $IdleMinutes)

}

function ConvertTo-RDSession {
    param(
        [string[]]$quser,
        [string]$computername
    )

	$SessionList = @()

	# Pull the session information from each instance 
	ForEach ($Line in $quser) { 
		$SESSIONNAME = $Line.SubString(23,16).trim()
		if ($SESSIONNAME -ne "SESSIONNAME") {
			$USERNAME = $Line.SubString(1,20).trim()
		    $ID = $Line.SubString(40,5).trim()
			$STATE = $Line.SubString(46,8).trim()
			$IDLE_TIME = $Line.SubString(54,9).trim()
			$LOGON_TIME = $Line.SubString(65).trim()


            $Session = [RDSession]::new()
#			$Session = new-object psobject
			$Session.SessionName = $SESSIONNAME
			$Session.Username = $USERNAME
			$Session.ID = $ID
			$Session.State = $STATE
			$Session.IdleTime = (ConvertTo-TimeSpan $IDLE_TIME)
			$Session.LogonTime = ([system.datetime]($LOGON_TIME))
			$Session.ComputerName = $computername
         
            $SessionList += $Session
		}
	}
    write-output $SessionList
}
