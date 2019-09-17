$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\New-Service.ps1"
. "$source\Get-BaseHost.ps1"
. "$source\Get-Header.ps1"
. "$source\Invoke-Retry.ps1"
. "$source\..\Private\Compare-HashTable.ps1"
. "$source\..\Private\PesterMatchHashtable.ps1"

Describe "New-Service" {
    $Space = [PSCustomObject]@{metadata=@{guid="1"}}
    $serviceplan1 = [PSCustomObject]@{entity=@{name="plan1"};metadata=@{guid="2"}}
    $serviceplan2 = [PSCustomObject]@{entity=@{name="plan2"};metadata=@{guid="3"}}
    $ServicePlans = @($serviceplan1,$serviceplan2)
    $Name = "servicename1"
    Mock Invoke-Retry { & $ScriptBlock }
    It "throws when service plan not found" {
        {New-Service -Space $Space -ServicePlans $ServicePlans -Plan "notfound" -Name $Name} | Should -Throw "service plan not found"
    }
    It "returns correct result when service_instances returns <StatusCode>" -TestCases @( @{StatusCode=202}, @{StatusCode=201}) {
        param ($StatusCode)
        $response = "{'foo': 'bar'}"
        Mock Get-baseHost { "http://google.com" }
        Mock Get-Header { @{} }
        Mock Invoke-WebRequest { @{StatusCode=$StatusCode;Content=$response} }
        New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name $Name | Should MatchHashtable ($response | ConvertFrom-Json)
    }
    It "it thows exception when service_instances returns <StatusCode>" -TestCases @( @{StatusCode=500}, @{StatusCode=401}) {
        param ($StatusCode)
        $response = "{'foo': 'bar'}"
        Mock Get-baseHost { "http://google.com" }
        Mock Get-Header { @{} }
        Mock Invoke-WebRequest { @{StatusCode=$StatusCode;Content=$response} }
        { New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name $Name } | Should -Throw "http://google.com/v2/service_instances?accepts_incomplete=true $($StatusCode)"
    }    
    It "thows exceptions when service_instances returns <StatusCode>" -TestCases @( @{StatusCode=204}) {
        param ($StatusCode)
        $response = "{'foo': 'bar'}"
        Mock Get-baseHost { "http://google.com" }
        Mock Get-Header { @{} }
        Mock -Command Invoke-WebRequest -MockWith {@{StatusCode=$StatusCode;Content=$response}}
        { New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name $Name } | Should -Throw " http://google.com/v2/service_instances?accepts_incomplete=true $($StatusCode)"
    }    
    Context "Correct results" {
        $response = "{'foo': 'bar'}"
        Mock Get-baseHost { "http://google.com" }
        Mock Get-Header { @{} }
        Mock -Command Invoke-WebRequest -MockWith { @{StatusCode=202;Content=$response} } `
            -ParameterFilter { 
                $MatchBody = @{      
                    "name" = $Name
                    "parameters" = @()
                    "service_plan_guid" = $serviceplan[0].metadata.guid
                    "space_guid" = $Space.metadata.guid
                }
                $hashtable = @{}
                (ConvertFrom-Json $Body).psobject.properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
                (Compare-HashTable $hashtable $MatchBody) -eq $null
            }
        it "creates space" {
            New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name $Name | Should MatchHashtable ($response | ConvertFrom-Json)
            Assert-VerifiableMock
        }
    }
    Context "parameters" {
        $response = "{'foo': 'bar'}"
        Mock Get-baseHost { "http://google.com" }
        Mock Get-Header { @{} }
        Mock -Command Invoke-WebRequest -MockWith { @{StatusCode=202;Content=$response} } `
            -ParameterFilter { 
                $MatchBody = @{      
                    "name" = $Name
                    "parameters" = @()
                    "service_plan_guid" = $serviceplan[0].metadata.guid
                    "space_guid" = $Space.metadata.guid
                }
                $hashtable = @{}
                (ConvertFrom-Json $Body).psobject.properties | ForEach-Object { $hashtable[$_.Name] = $_.Value }
                (Compare-HashTable $hashtable $MatchBody) -eq $null
            }
        It "ensures 'Space' cannot be null" {
            { New-Service -Space $null -ServicePlans $ServicePlans -Plan "plan1" -Name $Name  } | Should -Throw "Cannot validate argument on parameter 'Space'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "ensures 'ServicePlans' cannot be null" {
            { New-Service -Space $Space -ServicePlans $null -Plan "plan1" -Name $Name  } | Should -Throw "Cannot validate argument on parameter 'ServicePlans'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "ensures 'Plan' cannot be empty" {
            { New-Service -Space $Space -ServicePlans $ServicePlans -Plan "" -Name $Name  } | Should -Throw "Cannot validate argument on parameter 'Plan'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "ensures 'Plan' cannot be null" {
            { New-Service -Space $Space -ServicePlans $ServicePlans -Plan $null -Name $Name  } | Should -Throw "Cannot validate argument on parameter 'Plan'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "ensures 'Name' cannot be empty" {
            { New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name "" } | Should -Throw "Cannot validate argument on parameter 'Name'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "ensures 'Name' cannot be null" {
            { New-Service -Space $Space -ServicePlans $ServicePlans -Plan "plan1" -Name $null  } | Should -Throw "Cannot validate argument on parameter 'Name'. The argument is null or empty"
            Assert-VerifiableMock
        }
        It "support positional" {
            New-Service $Space $ServicePlans "plan1" $Name | Should MatchHashtable ($response | ConvertFrom-Json)
            Assert-VerifiableMock
        }
        It "supports 'Space' from pipeline" {
            $Space | New-Service -ServicePlans $ServicePlans -Plan "plan1" -Name $Name | Should MatchHashtable ($response | ConvertFrom-Json)
            Assert-VerifiableMock
        }
    }
}