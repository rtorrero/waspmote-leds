[command] [argument1] [argument2]


command:
  - blink
  - set
  - unset
  - get
  - read
  - write

schedule:
  - argument1:
    - <command>  // e.g.: "blink red 0" (quoted so the spaces are not ignored)
  - argument2:
    - <datetime-value> // In waspmote format, e.g: 19:03:25:04:13:22:00

blink:
  - argument1:
    - red
    - green
  - argument2:
    - 0 -> on static
    - -1 -> off
    - n -> milliseconds
    - schedule
      - <toggle-date>

set:
  - argument1:
    - pin
    - rtc
  - argument2:
    - digital1
    - digital2
    - ...

unset:
  - argument1:
    - pin
  - argument2:
    - digital1
    - digital2
    - ...

get:
  - argument1:
    - rtc
    - memory

read:
  - argument1:
    - value

write:
  - argument1:
    - value
