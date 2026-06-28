# PRU (Programmable Real-Time Unit) Usage Guide

This document describes the usage of the **PRU0** and **PRU1** on platforms like the BeagleBone Black for drone applications:

- **PRU0**: Servo and motor control for drones.
- **PRU1**: CAN interface for communication.

---

## Overview

The Programmable Real-Time Unit (PRU) is a microcontroller subsystem present on certain TI processors (e.g., AM335x on BeagleBone Black). It is designed for real-time, deterministic control tasks, making it ideal for drone applications where precise timing is critical.

- **PRU0**: Dedicated to generating PWM signals for servo and motor control.
- **PRU1**: Dedicated to handling CAN bus communication.

---

## PRU0: Servo and Motor Control

### Purpose
PRU0 is used to generate precise PWM signals for controlling drone servos and brushless motors (ESCs). The PRU's deterministic timing ensures jitter-free control, which is essential for stable flight.

### Features
- **High-Resolution PWM**: Generate PWM signals with nanosecond precision.
- **Independent Channels**: Control multiple servos/motors simultaneously.
- **Real-Time Updates**: Adjust PWM duty cycles on-the-fly without CPU intervention.

### Firmware
The firmware for PRU0 is written in PRU assembly or C (using TI's PRU C compiler). Below is a conceptual outline of the firmware logic:

```c
// PRU0 Firmware (Conceptual)
#include <stdint.h>
#include <pru_cfg.h>

volatile register uint32_t __R30; // PRU0 control register
volatile register uint32_t __R31; // PRU0 status register

#define PWM_PERIOD 20000     // 50Hz PWM period (20ms)
#define SERVO_MIN  1000      // 1ms pulse (0°)
#define SERVO_MAX  2000      // 2ms pulse (180°)

void main(void) {
    uint32_t servo_positions[8] = {1500, 1500, 1500, 1500, 1500, 1500, 1500, 1500}; // Neutral positions
    uint32_t counter = 0;
    
    // Configure PRU0 for PWM generation
    CT_CFG.SYSCFG_bit.STACTX_EN = 1; // Enable PRU0
    
    while (1) {
        // Generate PWM for each channel
        for (int i = 0; i < 8; i++) {
            if (counter < servo_positions[i]) {
                __R30 |= (1 << i); // Set PWM high
            } else {
                __R30 &= ~(1 << i); // Set PWM low
            }
        }
        
        counter++;
        if (counter >= PWM_PERIOD) {
            counter = 0;
        }
        
        // Delay for precise timing
        __delay_cycles(1);
    }
}
```

### Registers
| Register | Description                     | Address  |
|----------|---------------------------------|----------|
| `R30`    | PRU0 Control Register           | 0x22000  |
| `R31`    | PRU0 Status Register            | 0x22004  |
| `PWM0`   | PWM Output Register (Channel 0) | 0x22010  |
| `PWM1`   | PWM Output Register (Channel 1) | 0x22014  |

### Example Usage
1. **Load Firmware**:
   Use the `pru_load` utility or TI's PRU compiler to load the firmware onto PRU0.
   ```bash
   pru_load PRU0 servo_motor_control.out
   ```

2. **Start PRU0**:
   ```bash
   pru_run PRU0
   ```

3. **Update Servo Positions**:
   Write new positions to shared memory or registers from the ARM host.

---

## PRU1: CAN Interface

### Purpose
PRU1 is dedicated to handling CAN bus communication for the drone. This allows for real-time, low-latency communication with sensors, flight controllers, or other drones.

### Features
- **CAN 2.0B Support**: Full support for CAN 2.0B protocol.
- **Real-Time Messaging**: Transmit and receive CAN messages with microsecond precision.
- **Interrupt-Driven**: Efficiently handle incoming messages without polling.

### Firmware
The firmware for PRU1 is responsible for reading/writing CAN messages via the PRU's CAN peripheral.

```c
// PRU1 Firmware (Conceptual)
#include <stdint.h>
#include <pru_cfg.h>
#include <pru_intc.h>

volatile register uint32_t __R30; // PRU1 control register
volatile register uint32_t __R31; // PRU1 status register

#define CAN_BASE 0x481CC000 // CAN peripheral base address

void main(void) {
    uint32_t can_msg[8]; // Buffer for CAN messages
    
    // Initialize CAN peripheral
    CT_CFG.SYSCFG_bit.STACTX_EN = 1; // Enable PRU1
    CT_MMR.CAN_CTL = 0x00000001; // Enable CAN module
    
    // Configure CAN bit rate (e.g., 500kbps)
    CT_MMR.CAN_BTR = 0x001C0002; // Example for 500kbps
    
    // Main loop
    while (1) {
        // Check for incoming CAN messages
        if (CT_MMR.CAN_IF1_MSK & 0x00000001) {
            // Read CAN message
            for (int i = 0; i < 8; i++) {
                can_msg[i] = CT_MMR.CAN_IF1_DA1 + i;
            }
            
            // Process message (e.g., update flight parameters)
            process_can_message(can_msg);
            
            // Clear interrupt flag
            CT_MMR.CAN_IF1_MSK = 0x00000000;
        }
        
        // Send CAN messages if needed
        if (new_message_available()) {
            uint32_t msg[8] = {0xDE, 0xAD, 0xBE, 0xEF, 0, 0, 0, 0};
            send_can_message(0x123, msg); // Send message with ID 0x123
        }
    }
}

void process_can_message(uint32_t *msg) {
    // Custom logic to process incoming CAN messages
}

void send_can_message(uint32_t id, uint32_t *data) {
    // Write message to CAN transmit buffer
    CT_MMR.CAN_IF1_ARB1 = id;
    for (int i = 0; i < 8; i++) {
        CT_MMR.CAN_IF1_DA1 + i = data[i];
    }
    CT_MMR.CAN_IF1_CMD = 0x00000087; // Request transmission
}
```

### Registers
| Register       | Description                     | Address  |
|----------------|---------------------------------|----------|
| `CAN_CTL`      | CAN Control Register            | 0x481CC000 |
| `CAN_BTR`      | CAN Bit Timing Register         | 0x481CC004 |
| `CAN_IF1_ARB1` | CAN Interface 1 Arbitration      | 0x481CC020 |
| `CAN_IF1_DA1`  | CAN Interface 1 Data            | 0x481CC024 |
| `CAN_IF1_CMD`  | CAN Interface 1 Command         | 0x481CC030 |

### Example Usage
1. **Load Firmware**:
   ```bash
   pru_load PRU1 can_interface.out
   ```

2. **Start PRU1**:
   ```bash
   pru_run PRU1
   ```

3. **Send/Receive CAN Messages**:
   Use shared memory or registers to pass messages between the ARM host and PRU1.

---

## Compilation and Deployment

### Tools Required
- [TI PRU Code Generation Tools](https://www.ti.com/tool/PRU-CGT)
- [BeagleBone Black System Reference Manual](https://github.com/beagleboard/beagleboard-wiki/wiki/System-Reference-Manual)

### Steps
1. **Write Firmware**:
   Develop your PRU firmware in C or assembly.

2. **Compile**:
   Use the PRU compiler to generate the `.out` file:
   ```bash
   pru-gcc -c servo_motor_control.c -o servo_motor_control.o
   pru-ld -o servo_motor_control.out servo_motor_control.o
   ```

3. **Load and Run**:
   Use the `pru_load` and `pru_run` utilities to load and start the PRU firmware.

4. **Debugging**:
   Use `pru_debug` or JTAG for debugging PRU firmware.

---

## Shared Memory and Communication

The PRUs share memory with the ARM host processor, allowing for seamless communication.

### Shared Memory Map
| Region       | Start Address | Size      | Description                     |
|--------------|---------------|-----------|---------------------------------|
| PRU0 Data RAM| 0x00000000     | 8 KB      | PRU0 local data RAM             |
| PRU1 Data RAM| 0x00002000     | 8 KB      | PRU1 local data RAM             |
| Shared RAM   | 0x00010000     | 12 KB     | Shared between PRU0, PRU1, ARM  |

### Example: ARM to PRU Communication
```c
// ARM Host Code (Linux Userspace)
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>

#define PRU_SHARED_RAM 0x4A310000 // Shared RAM base address
#define PRU_SHARED_SIZE 0x3000     // 12 KB

int main() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    void *shared_mem = mmap(NULL, PRU_SHARED_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, PRU_SHARED_RAM);
    
    // Write to shared memory (e.g., update servo positions)
    uint32_t *servo_positions = (uint32_t *)(shared_mem + 0x100);
    servo_positions[0] = 1600; // New position for servo 0
    
    munmap(shared_mem, PRU_SHARED_SIZE);
    close(fd);
    return 0;
}
```

---

## Debugging and Optimization

### Debugging Tools
- **PRU Debugger**: Use TI's PRU debugger for step-by-step debugging.
- **Logic Analyzer**: Verify PWM signals and CAN bus activity.
- **Oscilloscope**: Check signal integrity and timing.

### Optimization Tips
- **Minimize Interrupts**: Reduce the number of interrupts to improve real-time performance.
- **Use Local RAM**: Store frequently accessed data in PRU local RAM for faster access.
- **Cycle-Accurate Timing**: Use `__delay_cycles()` for precise timing loops.

---

## References
- [TI PRU-ICSS Reference Guide](http://www.ti.com/lit/ug/spruhv7b/spruhv7b.pdf)
- [BeagleBone Black PRU Cape](https://github.com/beagleboard/bbb-pru-pack)
- [PRU Assembly Language Guide](https://www.ti.com/lit/ug/spru514/spru514.pdf)

---

## Appendix: Pin Muxing

Ensure the correct pins are muxed for PRU0 (PWM) and PRU1 (CAN) in the device tree overlay.

### Example Device Tree Overlay (for BeagleBone Black)
```dts
// Enable PRU0 PWM and PRU1 CAN
&pru0 {
    status = "okay";
};

&pru1 {
    status = "okay";
};

// Configure PRU0 PWM pins
&am33xx_pinmux {
    pru0_pwm_pins: pru0_pwm_pins {
        pinctrl-single,pins = <
            AM33XX_IOPAD(0x970, PIN_OUTPUT | MUX_MODE3) /* PRU0_PWM0 */
            AM33XX_IOPAD(0x974, PIN_OUTPUT | MUX_MODE3) /* PRU0_PWM1 */
        >;
    };
};

// Configure PRU1 CAN pins
&am33xx_pinmux {
    pru1_can_pins: pru1_can_pins {
        pinctrl-single,pins = <
            AM33XX_IOPAD(0x980, PIN_INPUT_PULLUP | MUX_MODE2) /* PRU1_CAN_RX */
            AM33XX_IOPAD(0x984, PIN_OUTPUT | MUX_MODE2)     /* PRU1_CAN_TX */
        >;
    };
};
```

---

**Note**:
- This document assumes familiarity with PRU programming and the BeagleBone Black platform.
- Adjust addresses, registers, and pin muxing according to your specific hardware and requirements.