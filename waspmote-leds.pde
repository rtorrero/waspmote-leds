#include <WaspUtils.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

WaspUtils utils;

// Global variables for scheduled command execution
char scheduledCommand[64] = "";
bool alarmScheduled = false;
//volatile uint8_t intFlag = 0; // This flag is set by the RTC interrupt (RTC_INT)

// Blink variables and EEPROM address remain unchanged
unsigned long nextRedBlink = 0;  // 0 means no blinking
unsigned long nextGreenBlink = 0;  // 0 means no blinking
int redBlinkInterval = 0;  // Store the interval for repeating blinks
int greenBlinkInterval = 0;
int address = 1024;

//--- Helper function: getToken ---
// Reads a token from 'command' starting at index 'idx' (which is updated)
// A token is either a group of non-space characters or if it starts with a double quote,
// all characters up to the matching double quote (quotes are not included).
bool getToken(char *command, int len, int &idx, char *token, int maxLen) {
    int tokenIdx = 0;
    // Skip initial whitespace
    while (idx < len && isspace(command[idx])) idx++;
    if (idx >= len) return false;
    
    if (command[idx] == '"') {
        idx++; // skip opening quote
        while (idx < len && command[idx] != '"' && tokenIdx < maxLen - 1) {
            token[tokenIdx++] = command[idx++];
        }
        token[tokenIdx] = '\0';
        if (idx < len && command[idx] == '"') idx++; // skip closing quote
    } else {
        while (idx < len && !isspace(command[idx]) && tokenIdx < maxLen - 1) {
            token[tokenIdx++] = command[idx++];
        }
        token[tokenIdx] = '\0';
    }
    return true;
}

//--- Modified parseCommand ---
// This function now supports quoted strings for arguments.
bool parseCommand(char* command, int len, char* cmd, char* arg1, char* arg2) {
    int idx = 0;
    // Get first token as the command name.
    if (!getToken(command, len, idx, cmd, 10)) {
        USB.println(F("Invalid command"));
        return false;
    }
    // Get second token (if any)
    if (!getToken(command, len, idx, arg1, 64)) {
        arg1[0] = '\0';
    }
    // Get third token (if any)
    if (!getToken(command, len, idx, arg2, 64)) {
        arg2[0] = '\0';
    }
    // Check for extra characters (non-space)
    while (idx < len && isspace(command[idx])) idx++;
    if (idx < len) {
        USB.println(F("Too many arguments"));
        return false;
    }
    return true;
}

void setup() {
    USB.ON();
    RTC.ON();
    USB.println(F("Enter command according to format: [command] [argument1] [argument2]"));
    USB.println(F("Available commands: blink, set, unset, get, read, write, schedule"));
}

void loop() {
    unsigned long currentMillis = millis();
    
    // Handle red LED blinking
    if (nextRedBlink > 0 && currentMillis >= nextRedBlink) {
        uint8_t currentRedState = utils.getLED(LED0);
        uint8_t newRedState = (currentRedState == LED_ON) ? LED_OFF : LED_ON;
        utils.setLED(LED0, newRedState);
        
        if (redBlinkInterval > 0) {
            nextRedBlink = currentMillis + redBlinkInterval;
        } else {
            nextRedBlink = 0;
        }
    }
    
    // Handle green LED blinking
    if (nextGreenBlink > 0 && currentMillis >= nextGreenBlink) {
        uint8_t currentGreenState = utils.getLED(LED1);
        uint8_t newGreenState = (currentGreenState == LED_ON) ? LED_OFF : LED_ON;
        utils.setLED(LED1, newGreenState);
        
        if (greenBlinkInterval > 0) {
            nextGreenBlink = currentMillis + greenBlinkInterval;
        } else {
            nextGreenBlink = 0;
        }
    }

    // Check if the RTC alarm interrupt has occurred
    // (In the real device, intFlag is set by the RTC interrupt)
    if (intFlag & RTC_INT) {
        intFlag &= ~RTC_INT;  // Clear the RTC interrupt flag
        if (alarmScheduled) {
            USB.println(F("Executing scheduled command: "));
            USB.println(scheduledCommand);
            // Parse and dispatch the scheduled command.
            char schCmd[10], schArg1[64], schArg2[64];
            int lenSch = strlen(scheduledCommand);
            if (parseCommand(scheduledCommand, lenSch, schCmd, schArg1, schArg2)) {
                if (strcmp(schCmd, "blink") == 0) {
                    handleBlinkCommand(schArg1, schArg2);
                }
                // Add additional commands here as needed.
            }
            alarmScheduled = false; // Reset the flag after execution
        }
    }
    
    // Read USB command input
    char command[128]; // Increase buffer size to allow longer schedule strings.
    char cmd[10], arg1[64], arg2[64];
    
    int8_t len = read_USB_command(command, sizeof(command) - 1);
    
    if (len > 0) {
        if (parseCommand(command, len, cmd, arg1, arg2)) {
            if (strcmp(cmd, "blink") == 0) {
                handleBlinkCommand(arg1, arg2);
            } else if (strcmp(cmd, "set") == 0) {
                handleSetCommand(arg1, arg2);
            } else if (strcmp(cmd, "unset") == 0) {
                handleUnsetCommand(arg1, arg2);
            } else if (strcmp(cmd, "get") == 0) {
                handleGetCommand(arg1, arg2);
            } else if (strcmp(cmd, "read") == 0) {
                handleReadCommand(arg1, arg2);
            } else if (strcmp(cmd, "write") == 0) {
                handleWriteCommand(arg1, arg2);
            } else if (strcmp(cmd, "schedule") == 0) {
                handleScheduleCommand(arg1, arg2);
            } else {
                USB.println(F("Unknown command. Available commands: blink, set, unset, get, read, write, schedule"));
            }
        }
    }
}

int8_t read_USB_command(char *term, size_t msz) {
    int8_t sz = 0;
    if (USB.available() > 0) {
        unsigned long init = millis();
        while (sz < msz) {
            while (USB.available() > 0 && sz < msz) {
                term[sz++] = USB.read();
                init = millis();
            }
            if ((millis() - init) > 50UL) break;
        }
    }
    term[sz] = 0;
    return sz;
}

bool isInteger(char *number) {
    for (int i = 0; number[i] != '\0'; i++) {
        if (i == 0 && number[i] == '-') continue;
        if (number[i] < '0' || number[i] > '9') return false;
    }
    return true;
}

bool isTime(char *time) {
    if (strlen(time) != 20) {
        return false;
    }
    for (int i = 0; i < 20; i++) {
        if (i == 2 || i == 5 || i == 8 || i == 11 || i == 14 || i == 17) {
            if (time[i] != ':') {
                return false;
            }
        } else {
            if (!isdigit(time[i])) {
                return false;
            }
        }
    }
    return true;
}

//--- Command Handlers ---

void handleBlinkCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("blink requires two arguments: [red/green] [0/-1/n]"));
        return;
    }
    if (strcmp(arg1, "red") != 0 && strcmp(arg1, "green") != 0) {
        USB.println(F("First argument for blink must be 'red' or 'green'"));
        return;
    }
    if (isInteger(arg2)) {
        int time_ms = atoi(arg2);
        if (time_ms < -1) {
            USB.println(F("Time value must be -1, 0, or positive"));
            return;
        }
        if (strcmp(arg1, "red") == 0) {
            if (time_ms == 0) {
                redBlinkInterval = 0;
                nextRedBlink = 0;
                utils.setLED(LED0, LED_ON);
            } else if (time_ms == -1) {
                redBlinkInterval = 0;
                nextRedBlink = 0;
                utils.setLED(LED0, LED_OFF);
            } else {
                USB.print(F("Blinking red LED for "));
                USB.print(time_ms);
                USB.println(F(" milliseconds"));
                redBlinkInterval = time_ms;
                nextRedBlink = millis() + time_ms;
                utils.setLED(LED0, LED_ON);
            }
        } else if (strcmp(arg1, "green") == 0) {
            if (time_ms == 0) {
                greenBlinkInterval = 0;
                nextGreenBlink = 0;
                utils.setLED(LED1, LED_ON);
            } else if (time_ms == -1) {
                greenBlinkInterval = 0;
                nextGreenBlink = 0;
                utils.setLED(LED1, LED_OFF);
            } else {
                USB.print(F("Blinking green LED for "));
                USB.print(time_ms);
                USB.println(F(" milliseconds"));
                greenBlinkInterval = time_ms;
                nextGreenBlink = millis() + time_ms;
                utils.setLED(LED1, LED_ON);
            }
        }
    } else {
        USB.println(F("Second argument must be 'cron', 0, -1, or a positive number"));
    }
}

void handleSetCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("set requires two arguments: [digital/rtc] [value]"));
        return;
    }
    if (strcmp(arg1, "digital") == 0) {
        handleSetPin(arg2);
    } else if (strcmp(arg1, "rtc") == 0) {
        if (!isTime(arg2)) {
            USB.println(F("set time requires time formatted as yy:mm:dd:dow:hh:mm:ss"));
            return;
        }
        USB.print(F("Set RTC to "));
        USB.println(arg2);
        RTC.setTime(arg2);
    } else {
        USB.println(F("First argument for set must be 'digital' or 'rtc'"));
    }
}

void handleSetPin(char* arg2) {
    if (!isInteger(arg2)) {
        USB.println(F("set digital requires a numerical value"));
        return;
    }
    int pin = atoi(arg2);
    if (pin < 1 || pin > 8) {
        USB.println(F("The pin must be between 1 and 8"));
        return;
    }
    const uint8_t digitalPins[8] = {DIGITAL1, DIGITAL2, DIGITAL3, DIGITAL4, DIGITAL5, DIGITAL6, DIGITAL7, DIGITAL8};
    uint8_t selectedPin = digitalPins[pin - 1];
    pinMode(selectedPin, OUTPUT); 
    digitalWrite(selectedPin, HIGH);
    USB.print(F("Setted pin "));
    USB.println(arg2);
}

void handleUnsetCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("unset requires two arguments: [pin] [value]"));
        return;
    }
    if (!isInteger(arg2)) {
        USB.println(F("Unset requires a numerical position"));
        return;
    }
    if (strcmp(arg1, "digital") == 0) {
        handleUnsetPin(arg2);
    } else {
        USB.println(F("First argument for unset must be 'digital'"));
    }
}

void handleUnsetPin(char* arg2) {
    if (!isInteger(arg2)) { 
        USB.println(F("Unset pin requires a numerical value"));
        return;
    }
    int pin = atoi(arg2);
    if (pin < 1 || pin > 8) {
        USB.println(F("The pin must be between 1 and 8"));
        return;
    }
    const uint8_t digitalPins[8] = {DIGITAL1, DIGITAL2, DIGITAL3, DIGITAL4, DIGITAL5, DIGITAL6, DIGITAL7, DIGITAL8};
    uint8_t selectedPin = digitalPins[pin - 1];
    pinMode(selectedPin, OUTPUT); 
    digitalWrite(selectedPin, LOW); 
    USB.print(F("Unsetted pin "));
    USB.println(arg2);
}

void handleGetCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0') {
        USB.println(F("get requires one argument: [rtc/memory]"));
        return;
    }
    if (strcmp(arg1, "rtc") == 0) {
        USB.print(F("Current date: "));
        USB.println(RTC.getTime());
    } else if (strcmp(arg1, "memory") == 0) {
        USB.print(F("Available memory (Bytes): "));
        USB.println(freeMemory());
    } else {
        USB.println(F("First argument for get must be 'rtc' or 'memory'"));
    }
}

void handleReadCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0') {
        USB.println(F("read requires one argument: [position]"));
        return;
    }
    if (!isInteger(arg1)) {
        USB.println(F("read requires a numerical position"));
        return;
    }
    int position = atoi(arg1);
    if (position < 0 || position > 3071) {
        USB.println(F("position must be between 0 and 3071"));
        return;
    }
    USB.printf("Reading value: %d\n%d\n", position, Utils.readEEPROM(address + position - 1));
}

void handleWriteCommand(char* arg1, char* arg2) {
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("write requires two arguments: [position] [value]"));
        return;
    }
    if (!isInteger(arg1) || !isInteger(arg2)) {
        USB.println(F("write requires a numerical position and a numerical value"));
        return;
    }
    int position = atoi(arg1);
    if (position < 0 || position > 3071) {
        USB.println(F("position must be between 0 and 3071"));
        return;
    }
    int value = atoi(arg2);
    Utils.writeEEPROM(address + position - 1, value);
    USB.printf("Wrote value %d in position %d\n", value, position);
}

//--- New: handleScheduleCommand ---
// The schedule command expects two quoted strings:
//   1. The alarm parameters string in CSV format: "dd:hh:mm:ss,RTC_ABSOLUTE,RTC_ALM1_MODE2"
//   2. The command to execute when the alarm triggers, e.g. "blink red 200"
void handleScheduleCommand(char* alarmParamStr, char* schedCmdStr) {
    if (alarmParamStr[0] == '\0' || schedCmdStr[0] == '\0') {
        USB.println(F("schedule requires two quoted arguments: alarm parameters and scheduled command"));
        return;
    }
    
    // Split alarmParamStr by commas into three parts.
    char timeStr[32], offsetStr[32], modeStr[32];
    char *token = strtok(alarmParamStr, ",");
    if (token != NULL) {
        strncpy(timeStr, token, sizeof(timeStr)-1);
        timeStr[sizeof(timeStr)-1] = '\0';
    } else { USB.println(F("Invalid alarm format")); return; }
    
    token = strtok(NULL, ",");
    if (token != NULL) {
        strncpy(offsetStr, token, sizeof(offsetStr)-1);
        offsetStr[sizeof(offsetStr)-1] = '\0';
    } else { USB.println(F("Invalid alarm format")); return; }
    
    token = strtok(NULL, ",");
    if (token != NULL) {
        strncpy(modeStr, token, sizeof(modeStr)-1);
        modeStr[sizeof(modeStr)-1] = '\0';
    } else { USB.println(F("Invalid alarm format")); return; }
    
    // Convert offset string to constant value.
    int offsetVal = 0;
    if (strcmp(offsetStr, "RTC_ABSOLUTE") == 0) {
        offsetVal = RTC_ABSOLUTE;
    } else if (strcmp(offsetStr, "RTC_OFFSET") == 0) {
        offsetVal = RTC_OFFSET;
    } else {
        USB.println(F("Invalid offset value"));
        return;
    }
    
    // Convert mode string to constant value.
    int modeVal = 0;
    if (strcmp(modeStr, "RTC_ALM1_MODE1") == 0) {
        modeVal = RTC_ALM1_MODE1;
    } else if (strcmp(modeStr, "RTC_ALM1_MODE2") == 0) {
        modeVal = RTC_ALM1_MODE2;
    } else if (strcmp(modeStr, "RTC_ALM1_MODE3") == 0) {
        modeVal = RTC_ALM1_MODE3;
    } else if (strcmp(modeStr, "RTC_ALM1_MODE4") == 0) {
        modeVal = RTC_ALM1_MODE4;
    } else if (strcmp(modeStr, "RTC_ALM1_MODE5") == 0) {
        modeVal = RTC_ALM1_MODE5;
    } else if (strcmp(modeStr, "RTC_ALM1_MODE6") == 0) {
        modeVal = RTC_ALM1_MODE6;
    } else {
        USB.println(F("Invalid alarm mode"));
        return;
    }
    
    // Set Alarm1 using the string version.
    RTC.setAlarm1(timeStr, offsetVal, modeVal);
    USB.print(F("Scheduled alarm set: "));
    USB.println(RTC.getAlarm1());
    
    // Save the scheduled command in a global variable.
    strncpy(scheduledCommand, schedCmdStr, sizeof(scheduledCommand)-1);
    scheduledCommand[sizeof(scheduledCommand)-1] = '\0';
    alarmScheduled = true;
}


