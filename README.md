# PRTG-Meraki-MT-Sensors

PowerShell scripts for monitoring Meraki MT environmental sensors in PRTG Network Monitor. Includes support for MT10 (temperature/humidity) and MT11 (temperature) devices.

## Overview

These scripts allow you to integrate Cisco Meraki MT sensor data into PRTG Network Monitor. They make direct API calls to the Meraki dashboard, retrieve sensor readings, and format the output for PRTG consumption.

Key features:
- No additional PowerShell modules required
- Optimized for performance with staggered execution
- Configurable alert thresholds
- Supports MT10 (temperature and humidity) and MT11 (temperature) sensors

## Scripts

### MerakiMT10Sensor.ps1

Monitors temperature and humidity for Meraki MT10 sensors. Produces a PRTG sensor with two channels:
- Temperature (in Fahrenheit)
- Humidity (percentage)

### MerakiMT11Sensor.ps1

Monitors temperature for Meraki MT11 sensors. Produces a PRTG sensor with one channel:
- Temperature (in Fahrenheit)

## Prerequisites

- PRTG Network Monitor
- Meraki API key with read access
- Meraki organization ID
- Device serial numbers for your MT sensors

## Installation

1. Download the scripts to your PRTG probe server
2. Create new "Advanced EXE/Script" sensors in PRTG
3. Point the sensors to the appropriate script
4. Configure the parameters (see below)

## Parameters

Both scripts use the same parameters:

```
Parameter       Description
---------       -----------
AuthToken       Your Meraki API key
DeviceSerial    The serial number of the specific MT device
OrganizationID  Your Meraki organization ID
```

## Usage Example

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

## Alert Thresholds

The scripts include default alert thresholds that you can adjust in the script or override in PRTG:

### MT10
- Temperature: Error if below 55°F or above 95°F
- Humidity: Error if above 80%

### MT11
- Temperature: Error if below 36°F or above 46°F

## Performance Considerations

These scripts include a small random delay (0-500ms) to stagger API requests when multiple sensors are running. This helps to avoid hitting Meraki API rate limits when monitoring many devices.

## Notes

- These scripts are designed to be lightweight and have minimal dependencies
- Ensure your Meraki API key has the necessary permissions
- Consider Meraki API rate limits if monitoring many devices

## License

MIT License

## Author

Richard Travellin
