# PRTG-Meraki-MT-Sensors

PowerShell scripts for monitoring Meraki MT environmental sensors in PRTG Network Monitor. Includes support for MT10 (temperature/humidity) and MT11 (temperature) devices, along with an automated sensor creation tool.

## Overview

These scripts allow you to integrate Cisco Meraki MT sensor data into PRTG Network Monitor. They make direct API calls to the Meraki dashboard, retrieve sensor readings, and format the output for PRTG consumption.

Key features:
- No additional PowerShell modules required for sensor scripts
- Optimized for performance with staggered execution
- Configurable alert thresholds
- Supports MT10 (temperature and humidity) and MT11 (temperature) sensors
- Automated sensor creation tool for rapid deployment

## Scripts

### MerakiMT10Sensor.ps1

Monitors temperature and humidity for Meraki MT10 sensors. Produces a PRTG sensor with two channels:
- Temperature (in Fahrenheit)
- Humidity (percentage)

### MerakiMT11Sensor.ps1

Monitors temperature for Meraki MT11 sensors. Produces a PRTG sensor with one channel:
- Temperature (in Fahrenheit)

### MerakiMTPRTGSensorCreator.ps1

Interactive tool to automatically discover Meraki MT sensors and create corresponding PRTG sensors. Features:
- Retrieves all MT10 and MT11 devices in your Meraki organization
- Allows filtering by organization and network
- Creates PRTG sensors with the exact device names from Meraki
- Uses the appropriate script (MT10 or MT11) based on device type
- Handles PRTG and Meraki API authentication

## Prerequisites

For MT10 and MT11 sensor scripts:
- PRTG Network Monitor
- Meraki API key with read access
- Meraki organization ID
- Device serial numbers for your MT sensors

For the sensor creator script:
- PRTG Network Monitor
- Meraki API key with read access
- PrtgAPI PowerShell module (install with `Install-Module PrtgAPI`)
- PRTG username and passhash
- PRTG device ID where sensors will be created

## Installation

### Sensor Scripts

1. Download the MT10 and MT11 scripts to your PRTG probe server
2. Place the scripts in the PRTG custom sensors directory (typically 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML')
3. Run the sensor creator tool to automatically create sensors (or create them manually following the usage examples below)

### Sensor Creator Tool

1. Download the MerakiMTPRTGSensorCreator.ps1 script to a system with PowerShell
2. Install the PrtgAPI module if not already installed:
   ```powershell
   Install-Module PrtgAPI
   ```
3. Run the script with appropriate parameters (see below)

## Parameters

### MT10 and MT11 Sensor Scripts

Both scripts use the same parameters:
```
Parameter       Description
---------       -----------
AuthToken       Your Meraki API key
DeviceSerial    The serial number of the specific MT device
OrganizationID  Your Meraki organization ID
```

### Sensor Creator Script

```
Parameter       Description
---------       -----------
PRTGServer      The hostname or IP address of the PRTG server
PRTGUsername    The username to access the PRTG API
PRTGPasshash    The passhash for PRTG authentication (not the password)
PRTGDeviceId    The ID of the PRTG device under which to create the sensors
MerakiApiKey    The API key for accessing the Meraki API
```

All parameters can be provided on the command line or entered when prompted if not specified.

## Usage Examples

### Creating Individual Sensors Manually

To set up a sensor for an MT10 device:
1. In PRTG, create a new "Advanced EXE/Script" sensor
2. Set the "EXE/Script" field to:
   ```
   MerakiMT10Sensor.ps1
   ```
3. Set the "Parameters" field to:
   ```
   -AuthToken "YOUR_API_KEY" -DeviceSerial "Q2XX-XXXX-XXXX" -OrganizationID "123456"
   ```
4. Configure other PRTG settings as needed
5. Create the sensor

### Using the Sensor Creator Tool

To automatically create sensors for all MT devices:

```powershell
.\MerakiMTPRTGSensorCreator.ps1 -PRTGServer "prtg.example.com" -PRTGUsername "admin" -PRTGPasshash "1234567890" -PRTGDeviceId 1001
```

The script will prompt for your Meraki API key and guide you through selecting your organization, networks, and sensor types.

To provide the Meraki API key as a parameter:

```powershell
.\MerakiMTPRTGSensorCreator.ps1 -PRTGServer "prtg.example.com" -PRTGUsername "admin" -PRTGPasshash "1234567890" -PRTGDeviceId 1001 -MerakiApiKey "YourApiKey"
```

## Alert Thresholds

The scripts include default alert thresholds that you can adjust in the script or override in PRTG:

### MT10
- Temperature: Error if below 55°F or above 95°F
- Humidity: Error if above 80%

### MT11
- Temperature: Error if below 36°F or above 46°F

## Performance Considerations

- The sensor scripts include a small random delay (0-500ms) to stagger API requests when multiple sensors are running. This helps to avoid hitting Meraki API rate limits when monitoring many devices.
- The sensor creator tool includes retry logic with exponential backoff to handle transient API issues.

## Sensor Creator Implementation Notes

The MerakiMTPRTGSensorCreator script creates PRTG sensors with these characteristics:

- **Sensor Names**: Uses the exact device name from Meraki (e.g., "Tahlequah Refrigerator")
- **Sensor Type**: "Advanced EXE/Script" (exexml)
- **Script File**: MerakiMT10Sensor.ps1 or MerakiMT11Sensor.ps1 based on device model
- **Parameters**: Uses PRTG placeholders for credentials
  ```
  -AuthToken '%windowspassword' -OrganizationID '%windowsuser' -DeviceSerial 'SERIAL-NUMBER'
  ```
- **Tags**: "meraki sensor MT10/MT11 [NetworkName]" for easy filtering

You must set up the credentials in PRTG before using the created sensors:
1. Edit the device (or parent group to allow inheritance) in PRTG
2. Under "Credentials for Windows Systems", set:
   - Username = Your Meraki Organization ID
   - Password = Your Meraki API Key

## Notes

- These scripts are designed to be lightweight and have minimal dependencies
- Ensure your Meraki API key has the necessary permissions
- Consider Meraki API rate limits if monitoring many devices
- The sensor creator tool requires PowerShell 5.1 or later

## License

MIT License

## Author

Richard Travellin
