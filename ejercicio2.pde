#include <WaspUtils.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

WaspUtils utils;

long blink_time;

int8_t read_USB_command(char *term, size_t msz) {
    int8_t sz = 0;
    unsigned long init = millis();
    // Lee caracteres desde USB hasta alcanzar el tamaño máximo o hasta que pase un breve tiempo sin recibir datos
    while (sz < msz) {
        while (USB.available() > 0 && sz < msz) {
            term[sz++] = USB.read();
            init = millis();
        }
        if (sz && (millis() - init) > 50UL) break;
    }
    term[sz] = 0;
    return sz;
}

void setup() {
    USB.ON();
    USB.println(F("Enter command according to format: [command] [argument1] [argument2]"));
    USB.println(F("Available commands: blink, set, unset, get, read, write"));
}

bool isInteger(char *number) {
  for (int i = 0; number[i] != '\0'; i++) {
    if (i == 0 && number[i] == '-') continue;
    if (number[i] < '0' || number[i] > '9') return false;
  }
  return true;
}

void loop() {
    char command[64]; // Increased buffer size to handle longer commands
    int8_t len = read_USB_command(command, sizeof(command) - 1);
    
    if (len > 0) {
        int idx = 0; // Index to traverse the 'command' array
        
        // Skip initial whitespace
        while (idx < len && isspace(command[idx])) idx++;
        if (idx == len) { 
            USB.println(F("Invalid command"));
            return;
        }
        
        // Extract command token
        char cmd[10];
        int cmdIdx = 0;
        while (idx < len && !isspace(command[idx]) && cmdIdx < (int)sizeof(cmd) - 1) {
            cmd[cmdIdx++] = command[idx++];
        }
        cmd[cmdIdx] = '\0';
        
        // Skip whitespace after command
        while (idx < len && isspace(command[idx])) idx++;
        
        // Extract argument1
        char arg1[20] = "";
        int arg1Idx = 0;
        if (idx < len) {
            while (idx < len && !isspace(command[idx]) && arg1Idx < (int)sizeof(arg1) - 1) {
                arg1[arg1Idx++] = command[idx++];
            }
            arg1[arg1Idx] = '\0';
        }
        
        // Skip whitespace after argument1
        while (idx < len && isspace(command[idx])) idx++;
        
        // Extract argument2
        char arg2[20] = "";
        int arg2Idx = 0;
        if (idx < len) {
            while (idx < len && !isspace(command[idx]) && arg2Idx < (int)sizeof(arg2) - 1) {
                arg2[arg2Idx++] = command[idx++];
            }
            arg2[arg2Idx] = '\0';
        }
        
        // Skip whitespace after argument2
        while (idx < len && isspace(command[idx])) idx++;
        
        // If there are additional characters, the command is invalid
        if (idx < len) {
            USB.println(F("Too many arguments"));
            return;
        }
        
        // Process command based on the command type
        if (strcmp(cmd, "blink") == 0) {
            // Handle blink command: blink [red/green] [cron/0/-1/n]
            if (arg1Idx == 0 || arg2Idx == 0) {
                USB.println(F("blink requires two arguments: [red/green] [cron/0/-1/n]"));
                return;
            }
            
            if (strcmp(arg1, "red") != 0 && strcmp(arg1, "green") != 0) {
                USB.println(F("First argument for blink must be 'red' or 'green'"));
                return;
            }
            
            if (strcmp(arg2, "cron") == 0) {
                // Handle cron scheduling
                USB.println(F("Cron scheduling not implemented yet"));
            } else if (isInteger(arg2)) {
                int time_ms = atoi(arg2);
                if (time_ms < -1) {
                    USB.println(F("Time value must be -1, 0, or positive"));
                    return;
                }
                
                if (strcmp(arg1, "red") == 0) {
                    if (time_ms == 0) utils.setLED(LED0, LED_ON);
                    else if (time_ms == -1) utils.setLED(LED0, LED_OFF);
                    else {
                        // Implement blinking for specified milliseconds
                        USB.print(F("Blinking red LED for "));
                        USB.print(time_ms);
                        USB.println(F(" milliseconds"));
                        // Actual blinking implementation would go here
                    }
                } else if (strcmp(arg1, "green") == 0) {
                    if (time_ms == 0) utils.setLED(LED1, LED_ON);
                    else if (time_ms == -1) utils.setLED(LED1, LED_OFF);
                    else {
                        // Implement blinking for specified milliseconds
                        USB.print(F("Blinking green LED for "));
                        USB.print(time_ms);
                        USB.println(F(" milliseconds"));
                        // Actual blinking implementation would go here
                    }
                }
            } else {
                USB.println(F("Second argument must be 'cron', 0, -1, or a positive number"));
            }
        } else if (strcmp(cmd, "set") == 0) {
            // Handle set command: set [pin/rtc] [digital1/digital2/...]
            if (arg1Idx == 0 || arg2Idx == 0) {
                USB.println(F("set requires two arguments: [pin/rtc] [value]"));
                return;
            }
            
            if (strcmp(arg1, "pin") == 0) {
                USB.print(F("Setting pin "));
                USB.println(arg2);
                // Implementation for setting pin
            } else if (strcmp(arg1, "rtc") == 0) {
                USB.print(F("Setting RTC to "));
                USB.println(arg2);
                // Implementation for setting RTC
            } else {
                USB.println(F("First argument for set must be 'pin' or 'rtc'"));
            }
        } else if (strcmp(cmd, "unset") == 0) {
            // Handle unset command: unset [pin] [digital1/digital2/...]
            if (arg1Idx == 0 || arg2Idx == 0) {
                USB.println(F("unset requires two arguments: [pin] [value]"));
                return;
            }
            
            if (strcmp(arg1, "pin") == 0) {
                USB.print(F("Unsetting pin "));
                USB.println(arg2);
                // Implementation for unsetting pin
            } else {
                USB.println(F("First argument for unset must be 'pin'"));
            }
        } else if (strcmp(cmd, "get") == 0) {
            // Handle get command: get [rtc/memory]
            if (arg1Idx == 0) {
                USB.println(F("get requires one argument: [rtc/memory]"));
                return;
            }
            
            if (strcmp(arg1, "rtc") == 0) {
                USB.print(F("Current RTC time: "));
                USB.println(RTC.getTime());
                // Implementation for getting RTC
            } else if (strcmp(arg1, "memory") == 0) {
                USB.println(F("Getting memory information"));
                // Implementation for getting memory
            } else {
                USB.println(F("First argument for get must be 'rtc' or 'memory'"));
            }
        } else if (strcmp(cmd, "read") == 0) {
            // Handle read command: read [value]
            if (arg1Idx == 0) {
                USB.println(F("read requires one argument: [value]"));
                return;
            }
            
            USB.print(F("Reading value: "));
            USB.println(arg1);
            // Implementation for reading value
        } else if (strcmp(cmd, "write") == 0) {
            // Handle write command: write [value]
            if (arg1Idx == 0) {
                USB.println(F("write requires one argument: [value]"));
                return;
            }
            
            USB.print(F("Writing value: "));
            USB.println(arg1);
            // Implementation for writing value
        } else {
            USB.println(F("Unknown command. Available commands: blink, set, unset, get, read, write"));
        }
    }
}
