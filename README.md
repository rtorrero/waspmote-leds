[command] [argument1] [argument2]


command:
    - blink
    - set
    - unset
    - get
    - read
    - write



blink:
    argument1:
        red
        green
    argument2:
        cron
        0 -> on static
        -1 -> off
        n -> milliseconds


set:
    argument1:
        pin
        rtc
    argument2:
        digital1
        digital2
        .
        .
        .


unset:
    argument1:
        pin
    argument2:
        digital1
        digital2
        .
        .
        .


get:
    argument1:
        rtc
        memory



read:
    argument1:
        value



write:
    argument1:
        value
