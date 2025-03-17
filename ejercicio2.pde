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
    USB.println(F("Enter command: red on, red off, green on, green off"));
}

bool isInteger(char *number) {
  for (int i = 0; number[i] != '\0'; i++) {
    if (i == 0 && number[i] == '-') continue;
    if (number[i] < '0' || number[i] > '9') return false;
  }
  return true;
}

void loop() {
    char command[20];
    int8_t len = read_USB_command(command, sizeof(command) - 1);
    if (len > 0) {
        int idx = 0; // Índice para recorrer el arreglo 'command'
        
        // Se ignoran los espacios iniciales
        while (idx < len && isspace(command[idx])) idx++;
        if (idx == len) { 
            USB.println(F("Invalid command"));
            return;
        }
        
        char color[10];  // Arreglo para almacenar el primer token (color)
        int cidx = 0;    // Índice para recorrer el arreglo 'color'
        // Se extrae el primer token hasta encontrar un espacio o el final del comando
        while (idx < len && !isspace(command[idx]) && cidx < (int)sizeof(color) - 1) {
            color[cidx++] = command[idx++];
        }
        color[cidx] = '\0';  // Se finaliza la cadena 'color'
        
        // Se ignoran los espacios entre el primer y segundo token
        while (idx < len && isspace(command[idx])) idx++;
        if (idx >= len) { 
            USB.println(F("Invalid command"));
            return;
        }
        
        char action[6]; // Arreglo para almacenar el segundo token (acción)
        int aidx = 0;    // Índice para recorrer el arreglo 'action'
        // Se extrae el segundo token hasta encontrar un espacio o el final del comando
        while (idx < len && !isspace(command[idx]) && aidx < (int)sizeof(action) - 1) {
            action[aidx++] = command[idx++];
        }
        action[aidx] = '\0';  // Se finaliza la cadena 'action'
        if (strcmp(action, "blink") != 0) {
            USB.println(F("Invalid command"));
            return;
        }
        while (idx < len && isspace(command[idx])) idx++;
        if (idx >= len) { 
            USB.println(F("Invalid command"));
            return;
        }

        char number[10]; // Arreglo para almacenar el segundo token (number)
        int nidx = 0;    // Índice para recorrer el arreglo 'number'
        // empezamos a leer el número
        // Se extrae el tercer token hasta encontrar un espacio o el final del comando
        while (idx < len && !isspace(command[idx]) && nidx < (int)sizeof(number) - 1) {
            number[nidx++] = command[idx++];
        }
        number[nidx] = '\0';  // Se finaliza la cadena 'number'
        if (!isInteger(number)) {
            USB.println(F("Invalid command"));
            return;
        }
        int time_ms = atoi(number);
        if (time_ms < -1) {
            USB.println(F("Invalid command"));
            return;
        }
        
        
        // Se ignoran los espacios finales después del tercer token
        while (idx < len && isspace(command[idx])) idx++;
        // Si quedan caracteres adicionales, el comando es inválido
        if (idx < len) {
            USB.println(F("Invalid command"));
            return;
        }
        USB.println(RTC.getTime());
        // Se valida el token 'color' y se enciende o apaga el LED correspondiente
        if (strcmp(color, "red") == 0) {
            // Para el LED rojo se acepta solo "on" o "off"
            if (time_ms == 0) utils.setLED(LED0, LED_ON);
            else if (time_ms == -1) utils.setLED(LED0, LED_OFF);
            else if (strcmp(action, "off") == 0) utils.setLED(LED0, LED_OFF);
            else { 
                USB.println(F("Invalid command"));
                return;
            }
        } else if (strcmp(color, "green") == 0) {
            // Para el LED verde se acepta solo "on" o "off"
            if (time_ms == 0) utils.setLED(LED1, LED_ON);
            else if (time_ms == -1) utils.setLED(LED1, LED_OFF);
            else { 
                USB.println(F("Invalid command"));
                return;
            }
        } else {
            USB.println(F("Invalid command"));
            return;
        }
    }
}

