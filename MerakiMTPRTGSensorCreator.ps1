<#
.SYNOPSIS
Creates PRTG sensors for Meraki MT10 and MT11 temperature/humidity sensors.

.DESCRIPTION
This script identifies MT10 and MT11 sensors in a Meraki organization and creates PRTG sensors for them.
The script allows interactive selection of organization, networks, and sensor types to monitor.
It creates exexml type sensors in PRTG that will call the appropriate PowerShell script for each device.

.PARAMETER PRTGServer
The hostname or IP address of the PRTG server.

.PARAMETER PRTGUsername
The username to access the PRTG API.

.PARAMETER PRTGPasshash
The passhash for PRTG authentication (not the password).

.PARAMETER PRTGDeviceId
The ID of the PRTG device under which to create the sensors.

.PARAMETER MerakiApiKey
The API key for accessing the Meraki API. If not provided, the script will prompt for it.

.INPUTS
None.

.OUTPUTS
Creates sensors in the PRTG system for each selected Meraki MT device.

.NOTES
Author: Richard Travellin
Date: March 30, 2025
Version: 1.0

.EXAMPLE
.\MerakiMTPRTGSensorCreator.ps1 -PRTGServer "prtg.example.com" -PRTGUsername "admin" -PRTGPasshash "1234567890" -PRTGDeviceId 1001
This example connects to the PRTG server, prompts for the Meraki API key, and then guides through sensor creation.

.EXAMPLE
.\MerakiMTPRTGSensorCreator.ps1 -PRTGServer "prtg.example.com" -PRTGUsername "admin" -PRTGPasshash "1234567890" -PRTGDeviceId 1001 -MerakiApiKey "YourApiKey"
This example provides the Meraki API key directly as a parameter without prompting.
#>



param(
    [Parameter(Mandatory=$true)]
    [string]$PRTGServer,
    
    [Parameter(Mandatory=$true)]
    [string]$PRTGUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$PRTGPasshash,
    
    [Parameter(Mandatory=$true)]
    [int]$PRTGDeviceId,
    
    [Parameter(Mandatory=$false)]
    [string]$MerakiApiKey
)

# Function to perform API call with retry logic
function Invoke-WithRetry {
    param (
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$InitialDelay = 2
    )
    $attempt = 1
    $delay = $InitialDelay
    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Host "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
            $attempt++
            $delay *= 2  # Exponential backoff
        }
    }
}

# Function to create a PRTG sensor for Meraki MT device
function New-PRTGSensor {
    param (
        [PSObject]$MerakiDevice,
        [int]$DeviceId,
        [string]$NetworkName,
        [string]$SensorType,
        [hashtable]$ApiHeaders
    )
    try {
        # Get detailed device information to use the exact name from Meraki
        Write-Host "Fetching detailed information for device $($MerakiDevice.serial)..." -ForegroundColor Cyan
        
        # Get the detailed device information
        $deviceDetails = Invoke-WithRetry { 
            Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/devices/$($MerakiDevice.serial)" -Headers $ApiHeaders -Method Get 
        }
        
        # Use the device name from the detailed information
        $deviceName = $deviceDetails.name
        Write-Host "Found device name: $deviceName" -ForegroundColor Green
        
        # Use the device name for the sensor name
        $sensorName = $deviceName
        Write-Host "Creating PRTG sensor named '$sensorName' for Meraki $($MerakiDevice.model) device $($MerakiDevice.serial)" -ForegroundColor Cyan
                
        $prtgDevice = Get-Device -Id $DeviceId
        $params = $prtgDevice | New-SensorParameters -RawType exexml
        $params.Unlock()
        $params["name_"] = $sensorName
        
        # Use different script files based on the sensor type
        if ($SensorType -eq "MT10") {
            $params["exefile_"] = "MerakiMT10Sensor.ps1"
        } else {
            $params["exefile_"] = "MerakiMT11Sensor.ps1"
        }
        
        $params["exeparams"] = "-AuthToken '%windowspassword' -OrganizationID '%windowsuser' -DeviceSerial '$($MerakiDevice.serial)'"
        $params["mutex_"] = "MerakiMTSensor_$($MerakiDevice.serial)"
        $params["tags_"] = "meraki sensor $SensorType $NetworkName"
        $params["priority_"] = 3
        $params["environment"] = 0
        $params["usewindowsauthentication"] = 0
        $params["writeresult"] = 0
        $params.Lock()
        $newSensor = $prtgDevice | Add-Sensor $params
        if ($newSensor) {
            Write-Host "Sensor created. Sensor ID: $($newSensor.Id)" -ForegroundColor Green
            if ($newSensor.Status -eq "Paused") {
                Write-Host "Sensor is paused. Attempting to resume..." -ForegroundColor Yellow
                $newSensor | Resume-Object
                Write-Host "Sensor resumed." -ForegroundColor Green
            }
            return $true
        } else {
            Write-Host "Failed to create sensor for Meraki $SensorType device $($MerakiDevice.serial)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error creating sensor: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main script execution
try {
    Write-Host "Starting Meraki MT Sensor PRTG Creator" -ForegroundColor Green
    
    # Get Meraki API Key (from parameter or prompt user)
    if ([string]::IsNullOrEmpty($MerakiApiKey)) {
        $apiKey = Read-Host "Enter your Meraki API Key"
    } else {
        $apiKey = $MerakiApiKey
        Write-Host "Using provided Meraki API Key" -ForegroundColor Green
    }
    
    # Base URL for Meraki API
    $baseUrl = "https://api.meraki.com/api/v1"
    
    # Set up headers with authentication for direct API call
    $headers = @{
        "X-Cisco-Meraki-API-Key" = $apiKey
        "Content-Type" = "application/json"
    }
    
    # Get list of organizations
    try {
        $orgsEndpoint = "$baseUrl/organizations"
        
        Write-Host "Retrieving organizations..." -ForegroundColor Cyan
        $organizations = Invoke-WithRetry { 
            Invoke-RestMethod -Uri $orgsEndpoint -Headers $headers -Method Get 
        }
        
        if ($organizations.Count -eq 0) {
            Write-Host "No organizations found for this API key." -ForegroundColor Red
            exit
        }
        
        # Display organizations
        Write-Host "`nAvailable Organizations:" -ForegroundColor Green
        for ($i = 0; $i -lt $organizations.Count; $i++) {
            Write-Host "[$i] $($organizations[$i].name) (ID: $($organizations[$i].id))"
        }
        
        # Prompt user to select an organization
        $selection = Read-Host "`nEnter the number of the organization to use [0-$($organizations.Count - 1)]"
        
        $selectedOrg = $organizations[[int]$selection]
        $orgId = $selectedOrg.id
        Write-Host "Selected organization: $($selectedOrg.name) (ID: $orgId)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error retrieving organizations: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
    
    # Get all networks for the organization
    try {
        Write-Host "`nRetrieving networks..." -ForegroundColor Cyan
        $networksEndpoint = "$baseUrl/organizations/$orgId/networks"
        
        $networks = Invoke-WithRetry { 
            Invoke-RestMethod -Uri $networksEndpoint -Headers $headers -Method Get 
        }
        
        if ($networks.Count -eq 0) {
            Write-Host "No networks found in this organization." -ForegroundColor Red
            exit
        }
        
        # Display networks
        Write-Host "`nAvailable Networks:" -ForegroundColor Green
        for ($i = 0; $i -lt $networks.Count; $i++) {
            Write-Host "[$i] $($networks[$i].name) (ID: $($networks[$i].id))"
        }
        
        Write-Host "[A] All networks"
        $networkSelection = Read-Host "`nEnter the network number to use, or 'A' for all networks"
        
        if ($networkSelection -eq "A") {
            $selectedNetworks = $networks
            Write-Host "Selected all networks" -ForegroundColor Green
        }
        else {
            $selectedNetworks = @($networks[[int]$networkSelection])
            Write-Host "Selected network: $($selectedNetworks[0].name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error retrieving networks: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
    
    # Connect to PRTG Server (Delayed until after Meraki information is collected)
    try {
        Write-Host "`nConnecting to PRTG Server at $PRTGServer..." -ForegroundColor Cyan
        Import-Module PrtgAPI -ErrorAction Stop
        Connect-PrtgServer $PRTGServer (New-Credential -Username $PRTGUsername -Password $PRTGPasshash)
        Write-Host "Successfully connected to PRTG Server" -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to PRTG Server: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please verify your PRTG credentials and server address" -ForegroundColor Yellow
        exit
    }
    
    # Ask which type of sensors to create (MT10 or MT11)
    Write-Host "`nWhich type of sensors do you want to create?" -ForegroundColor Cyan
    Write-Host "[1] MT10 sensors only"
    Write-Host "[2] MT11 sensors only"
    Write-Host "[3] Both MT10 and MT11 sensors"
    $sensorTypeSelection = Read-Host "Enter your selection (1-3)"
    
    $createMT10 = $false
    $createMT11 = $false
    
    switch ($sensorTypeSelection) {
        "1" { 
            $createMT10 = $true 
            Write-Host "Will create MT10 sensors" -ForegroundColor Green
        }
        "2" { 
            $createMT11 = $true 
            Write-Host "Will create MT11 sensors" -ForegroundColor Green
        }
        "3" { 
            $createMT10 = $true
            $createMT11 = $true
            Write-Host "Will create both MT10 and MT11 sensors" -ForegroundColor Green
        }
        default {
            Write-Host "Invalid selection. Please enter 1, 2, or 3." -ForegroundColor Red
            exit
        }
    }
    
    # Get devices and create sensors
    $sensorsCreated = 0
    $sensorsSkipped = 0
    
    foreach ($network in $selectedNetworks) {
        Write-Host "`nGetting devices for network: $($network.name)..." -ForegroundColor Cyan
        $devicesEndpoint = "$baseUrl/networks/$($network.id)/devices"
        
        try {
            # Get devices for this network
            $devices = Invoke-WithRetry { 
                Invoke-RestMethod -Uri $devicesEndpoint -Headers $headers -Method Get 
            }
            
            # Filter for MT10 and/or MT11 devices based on user selection
            $mtDevices = @()
            if ($createMT10) {
                $mt10Devices = $devices | Where-Object { $_.model -eq "MT10" }
                $mtDevices += $mt10Devices
                Write-Host "Found $($mt10Devices.Count) MT10 devices in network $($network.name)" -ForegroundColor Cyan
            }
            if ($createMT11) {
                $mt11Devices = $devices | Where-Object { $_.model -eq "MT11" }
                $mtDevices += $mt11Devices
                Write-Host "Found $($mt11Devices.Count) MT11 devices in network $($network.name)" -ForegroundColor Cyan
            }
            
            if ($mtDevices.Count -gt 0) {
                Write-Host "Creating sensors for $($mtDevices.Count) devices in network $($network.name)..." -ForegroundColor Cyan
                
                foreach ($device in $mtDevices) {
                    $sensorType = $device.model  # This will be either "MT10" or "MT11"
                    
                    $result = New-PRTGSensor -MerakiDevice $device -DeviceId $PRTGDeviceId -NetworkName $network.name -SensorType $sensorType -ApiHeaders $headers
                    
                    if ($result) {
                        $sensorsCreated++
                    } else {
                        $sensorsSkipped++
                    }
                }
            } else {
                Write-Host "No matching MT devices found in network $($network.name)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Error processing network $($network.name): $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }
    
    # Display summary
    Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
    Write-Host "Total sensors created: $sensorsCreated" -ForegroundColor Cyan
    Write-Host "Total sensors skipped: $sensorsSkipped" -ForegroundColor Yellow
    
    Write-Host "`nNote: PRTG sensors were created with these parameters:" -ForegroundColor Green
    Write-Host " - AuthToken: %windowspassword (will be automatically substituted by PRTG)" -ForegroundColor Cyan
    Write-Host " - OrganizationID: %windowsuser (will be automatically substituted by PRTG)" -ForegroundColor Cyan
    Write-Host " - DeviceSerial: [Unique to each Meraki device]" -ForegroundColor Cyan
}
catch {
    Write-Host "An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Disconnect from PRTG
    try {
        if (Get-PrtgClient) {
            Disconnect-PrtgServer
            Write-Host "Disconnected from PRTG Server" -ForegroundColor Green
        }
    }
    catch {
        # Silently continue if disconnect fails
    }
    
    Write-Host "Script execution completed." -ForegroundColor Green
}