# Waspmote LEDs Control

This utility allows controlling LEDs and other functions on Waspmote devices using a simple command syntax.

## Command Syntax

```
[command] [argument1] [argument2]
```

## Available Commands

### `blink`
Controls LED blinking behavior.

- **Argument1**: LED color
  - `red`
  - `green`
- **Argument2**: Blink duration
  - `0` - Turn on static (no blinking)
  - `-1` - Turn off
  - `n` - Blink duration in milliseconds

### `set`
Configure device settings.

- **Argument1**: Setting type
  - `digital` - Configure a digital pin
  - `rtc` - Configure real-time clock
- **Argument2**:
  - For pins: `1`, `2`, etc.
  - For RTC: Configuration parameters

### `unset`
Remove configuration.

- **Argument1**: Setting type
  - `digital` - Unconfigure a digital pin
- **Argument2**:
  - `1`, `2`, etc.

### `get`
Retrieve device information.

- **Argument1**: Information type
  - `rtc` - Get real-time clock data
  - `memory` - Get memory information

### `read`
Read data.

- **Argument1**:
  - `value` - Read a specific value

### `write`
Write data.

- **Argument1**:
  - `value` - Write a specific value

### `schedule`
Schedule a command to run at a specific time using Waspmote's RTC alarm functionality.

- **Argument1**: Alarm configuration string in the format:
  ```
  "time_spec,offset_mode,alarm_mode"
  ```
  
  Where:
  - **time_spec**: Time specification in format `DD:HH:MM:SS`
    - `DD` - Day/Date (depends on alarm mode)
    - `HH` - Hours
    - `MM` - Minutes
    - `SS` - Seconds
  
  - **offset_mode**: How the time is interpreted
    - `RTC_OFFSET` - Time is added to the current RTC time
    - `RTC_ABSOLUTE` - Time is set as the absolute time for the alarm
  
  - **alarm_mode**: Specifies which time components must match
    - `RTC_ALM1_MODE1` - Day, hours, minutes and seconds match
    - `RTC_ALM1_MODE2` - Date, hours, minutes and seconds match
    - `RTC_ALM1_MODE3` - Hours, minutes and seconds match
    - `RTC_ALM1_MODE4` - Minutes and seconds match
    - `RTC_ALM1_MODE5` - Seconds match
    - `RTC_ALM1_MODE6` - Once per second

  Example:
  ```
  schedule "29:11:00:00,RTC_ABSOLUTE,RTC_ALM1_MODE2"
  ```
  This sets an alarm for the 29th day of the month at 11:00:00.

  Example with offset:
  ```
  schedule "00:00:05:00,RTC_OFFSET,RTC_ALM1_MODE4"
  ```
  This sets an alarm to trigger 5 minutes from the current time.
