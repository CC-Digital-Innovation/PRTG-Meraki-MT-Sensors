<#
.SYNOPSIS
Monitors temperature for Meraki MT11 sensors and outputs the results to PRTG.
.DESCRIPTION
This script retrieves temperature readings from the Meraki API for a specific MT11 sensor device. It then outputs a PRTG sensor result with the temperature metric and appropriate status (OK, WARNING, or ERROR) based on configurable thresholds.
.PARAMETER AuthToken
The API key for accessing the Meraki API.
.PARAMETER DeviceSerial
The serial number of the Meraki MT11 device to monitor.
.PARAMETER OrganizationID
The Meraki organization ID.
.INPUTS
None.
.OUTPUTS
Outputs PRTG sensor results with temperature information for the specified Meraki MT11 device.
.NOTES
Author: Richard Travellin
Date: 3/29/2025
Version: 1.0
.LINK
https://github.com/CC-Digital-Innovation/PRTG-Meraki-MT-Sensors
.EXAMPLE
./MerakiMT11Sensor.ps1 -AuthToken "YOUR_API_KEY" -DeviceSerial "DEVICE_SERIAL_NUMBER" -OrganizationID "YOUR_ORG_ID"
This example runs the script to check the temperature for the specified Meraki MT11 sensor using the provided API key, device serial number, and organization ID.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AuthToken,
    
    [Parameter(Mandatory = $true)]
    [string]$DeviceSerial,
    
    [Parameter(Mandatory = $true)]
    [string]$OrganizationID
)
# Add a small random delay to stagger API requests when multiple instances are running
Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum 500)
# Set up headers with authentication
$headers = @{
    "X-Cisco-Meraki-API-Key" = $AuthToken
    "Content-Type" = "application/json"
}
# Create URL with query parameters to filter results
$url = "https://api.meraki.com/api/v1/organizations/$OrganizationID/sensor/readings/latest?serials[]=$DeviceSerial&metrics[]=temperature"
# Setup REST parameters
$restParams = @{
    Uri = $url
    Headers = $headers
    Method = 'Get'
    UseBasicParsing = $true
}
# Get sensor readings - only API call
$sensorData = Invoke-RestMethod @restParams
# Find our device in the results
$deviceData = $sensorData | Where-Object { $_.serial -eq $DeviceSerial }
# Look for temperature readings
$tempReading = $deviceData.readings | 
              Where-Object { $null -ne $_.temperature } | 
              Select-Object -First 1 -ExpandProperty temperature
# Output in PRTG XML format
$fahrenheit = $tempReading.fahrenheit
@"
<prtg>
  <result>
    <channel>Temperature</channel>
    <value>$fahrenheit</value>
    <unit>Custom</unit>
    <customunit>&#176;F</customunit>
    <float>1</float>
    <limitmode>1</limitmode>
    <limitmaxerror>46</limitmaxerror>
    <limitminerror>36</limitminerror>
  </result>
  <text>Model: MT11, Serial: $DeviceSerial</text>
</prtg>
"@ | Write-Output