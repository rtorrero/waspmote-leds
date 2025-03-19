#include <WaspUtils.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

WaspUtils utils;

unsigned long nextRedBlink = 0;  // 0 means no blinking
unsigned long nextGreenBlink = 0;  // 0 means no blinking
int redBlinkInterval = 0;  // Store the interval for repeating blinks
int greenBlinkInterval = 0;
bool redLedState = false;
bool greenLedState = false;
int address = 1024;

void setup() {
    USB.ON();
    RTC.ON();
    USB.println(F("Enter command according to format: [command] [argument1] [argument2]"));
    USB.println(F("Available commands: blink, set, unset, get, read, write"));
}

void loop() {
    unsigned long currentMillis = millis();
    // USB.printf("Current time: %lu", currentMillis);
    // USB.printf("Current intervals: red = %d, green = %d", redBlinkInterval, greenBlinkInterval);
    // USB.printf("Next red blink: %lu, next green blink: %lu", nextRedBlink, nextGreenBlink);
    // Handle red LED blinking
    if (nextRedBlink > 0 && currentMillis >= nextRedBlink) {
        redLedState = !redLedState;
        utils.setLED(LED0, redLedState ? LED_ON : LED_OFF);
        
        // Schedule next blink if interval is set
        if (redBlinkInterval > 0) {
            nextRedBlink = currentMillis + redBlinkInterval;
        } else {
            nextRedBlink = 0;  // Stop blinking after this toggle
        }
    }
    
    // Handle green LED blinking
    if (nextGreenBlink > 0 && currentMillis >= nextGreenBlink) {
        greenLedState = !greenLedState;
        utils.setLED(LED1, greenLedState ? LED_ON : LED_OFF);
        
        // Schedule next blink if interval is set
        if (greenBlinkInterval > 0) {
            nextGreenBlink = currentMillis + greenBlinkInterval;
        } else {
            nextGreenBlink = 0;  // Stop blinking after this toggle
        }
    }

    char command[64]; // Buffer for command input
    char cmd[10], arg1[21], arg2[21]; // Buffers for parsed components
    
    int8_t len = read_USB_command(command, sizeof(command) - 1);
    
    if (len > 0) {
        if (parseCommand(command, len, cmd, arg1, arg2)) {
            // Process command based on the command type
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
            } else {
                USB.println(F("Unknown command. Available commands: blink, set, unset, get, read, write"));
            }
        }
    }
}

int8_t read_USB_command(char *term, size_t msz) {
    int8_t sz = 0;
    
    // Only read if data is available
    if (USB.available() > 0) {
        unsigned long init = millis();
        // Read characters from USB until reaching max size or brief timeout
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

bool parseCommand(char* command, int len, char* cmd, char* arg1, char* arg2) {
    int idx = 0; // Index to traverse the 'command' array
    
    // Skip initial whitespace
    while (idx < len && isspace(command[idx])) idx++;
    if (idx == len) { 
        USB.println(F("Invalid command"));
        return false;
    }
    
    // Extract command token
    int cmdIdx = 0;
    while (idx < len && !isspace(command[idx]) && cmdIdx < 9) {
        cmd[cmdIdx++] = command[idx++];
    }
    cmd[cmdIdx] = '\0';
    
    // Skip whitespace after command
    while (idx < len && isspace(command[idx])) idx++;
    
    // Extract argument1
    int arg1Idx = 0;
    arg1[0] = '\0'; // Initialize to empty string
    if (idx < len) {
        while (idx < len && !isspace(command[idx]) && arg1Idx < 20) {
            arg1[arg1Idx++] = command[idx++];
        }
        arg1[arg1Idx] = '\0';
    }
    
    // Skip whitespace after argument1
    while (idx < len && isspace(command[idx])) idx++;
    
    // Extract argument2
    int arg2Idx = 0;
    arg2[0] = '\0'; // Initialize to empty string
    if (idx < len) {
        while (idx < len && !isspace(command[idx]) && arg2Idx < 20) {
            arg2[arg2Idx++] = command[idx++];
        }
        arg2[arg2Idx] = '\0';
    }
    
    // Skip whitespace after argument2
    while (idx < len && isspace(command[idx])) idx++;
    
    // If there are additional characters, the command is invalid
    if (idx < len) {
        USB.println(F("Too many arguments"));
        return false;
    }
    
    return true;
}

// Command handlers
void handleBlinkCommand(char* arg1, char* arg2) {
    // Handle blink command: blink [red/green] [0/-1/n]
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
                utils.setLED(LED0, LED_ON);
                redLedState = true;
            }
            else if (time_ms == -1) {
                redBlinkInterval = 0;
                utils.setLED(LED0, LED_OFF);
                redLedState = false;
            }
            else {
                // Implement blinking for specified milliseconds
                USB.print(F("Blinking red LED for "));
                USB.print(time_ms);
                USB.println(F(" milliseconds"));
                redBlinkInterval = time_ms;
                nextRedBlink = millis() + time_ms;  // Schedule first blink
                utils.setLED(LED0, LED_ON);  // Start with LED on
                redLedState = true;
            }
        } else if (strcmp(arg1, "green") == 0) {
            if (time_ms == 0) {
                greenBlinkInterval = 0;
                utils.setLED(LED1, LED_ON);
                greenLedState = true;
            } else if (time_ms == -1) {
                greenBlinkInterval = 0;
                utils.setLED(LED1, LED_OFF);
                greenLedState = false;
            } else {
                // Implement blinking for specified milliseconds
                USB.print(F("Blinking green LED for "));
                USB.print(time_ms);
                USB.println(F(" milliseconds"));
                greenBlinkInterval = time_ms;
                nextGreenBlink = millis() + time_ms;  // Schedule first blink
                utils.setLED(LED1, LED_ON);  // Start with LED on
                greenLedState = true;
            }
        }
    } else {
        USB.println(F("Second argument must be 'cron', 0, -1, or a positive number"));
    }
}

void handleSetCommand(char* arg1, char* arg2) {
    // Handle set command: set [digital/rtc] [1/2/...]
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("set requires two arguments: [digital/rtc] [value]"));
        return;
    }
    if (strcmp(arg1, "digital") == 0) {
        handleSetPin(arg2);
    } else if (strcmp(arg1, "rtc") == 0) {
        USB.print(F("Setting RTC to "));
        USB.println(arg2);
        // Implementation for setting pin
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
    // Handle unset command: unset [digital] [1/2/...]
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
    // Handle get command: get [rtc/memory]
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
    // Handle read command: read [position]
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
    // Handle write command: write [value]
    if (arg1[0] == '\0' || arg2[0] == '\0') {
        USB.println(F("write requires two arguments: [position] [value]"));
        return;
    }
    if (!isInteger(arg1) || !isInteger(arg2)) {
        USB.println(F("read requires a numerical position and a numerical value"));
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