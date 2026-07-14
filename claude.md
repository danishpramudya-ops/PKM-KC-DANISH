# CLAUDE.md

# ANCHORPULSE Development Guidelines

You are assisting with the development of ANCHORPULSE.

ANCHORPULSE is an embedded tactical communication device for disaster evacuation in a Non-Line Of Sight Area (no wifi/cellular) that uses ESP32, LoRa SX1278, and GPS Neo-M8N.

Your role is to assist as a senior embedded systems engineer on building the project.

read the file on /docs/"proposal alat.pdf" for more detailed information about the project. notice that a few component is changed due to further research, and could be more.

note: this project is done in steps and its parrel to the hardware designing process. soo, some fetures like button, oled, led will came later on.

---

# Primary Goals

Always prioritize:

1. Reliability
2. Simplicity
3. Low Power Consumption
4. Memory Efficiency
5. Maintainability
6. Readability


---

# Hardware

Target MCU:
- ESP32 30 pin

Radio:
- LoRa SX1278 433mz

GPS:
- u-blox Neo-M8N

Power:
- a Li-ion Battery 
- Step-up
- BMS

I/O:
- Oled (small size)
- LED indicator (for ON and OFF)
- 1 button (sending pulse/signals SOS per press)
---

# Project Objectives

The device must:

- Operate without internet
- Operate without cellular signal
- Form a LoRa mesh network
- Share GPS positions
- Be power efficient
- Support disaster evacuation scenarios
- fault tolerant (automaticly reset if failed to detect other nodes for minutes)
---

# Struktur folder (boleh kau ubah / sesuaikan)

ANCHORPULSE/
│
├── CLAUDE.md
├── README.md
├── platformio.ini
├── .gitignore
│
├── docs/
│
├── include/
│
├── src/
│   ├── main.cpp
│   │
│   ├── common/
│   │
│   ├── communication/
│   │
│   ├── sensors/
│   │
│   ├── nodes/   #di flash ke esp32
│   │   ├── sar/
│   │   ├── victim/
│   │   └── gateway/
│   │
│   └── app/
│
├── lib/
│
├── test/
│
└── tools/
---

# Software Architecture

The project should remain modular.

Suggested modules:

- LoRa Driver
- GPS Driver
- Routing
- Packet Manager
- Duplicate Detection
- Battery Manager
- Power Manager
- OLED/UI
- Configuration
- Logging

Avoid putting everything inside main.cpp.

---

# Nodes specification (bahasa indonesia)

## Identitas & Role

| | GATEWAY | SAR | KORBAN |
|---|---|---|---|
| Node ID | `0` | `1001`, `1002`, ... | `2001`, `2002`, ... |
| Role ID | `0` | `1` | `2` |
| Net ID (sama) | `PR01` | `PR01` | `PR01` |

---

## Hardware

| | GATEWAY | SAR | KORBAN |
|---|---|---|---|
| LoRa SX1278 | ✅ | ✅ | ✅ |
| GPS M10 | ❌ | ✅ | ✅ |
| Tombol SOS fisik | ❌ | ❌ | ✅ (pin 4 → GND) |
| Sambung ke PC | ✅ (selalu) | ❌ | ❌ |
---

## Perilaku Jaringan

| | GATEWAY | SAR | KORBAN |
|---|---|---|---|
| Broadcast lokasi sendiri | ❌ | ✅ tiap 5 detik | ✅ tiap 5 detik |
| Broadcast heartbeat | ✅ tiap 10 detik | ✅ tiap 10 detik | ✅ tiap 10 detik |
| Boleh relay paket lain | ✅ selalu | ✅ selalu | ❌ tidak pernah |
| Trigger SOS | ❌ | Via Serial Monitor | Tombol fisik + Serial |
---

## Konfigurasi Paket

| | GATEWAY | SAR | KORBAN |
|---|---|---|---|
| Delay adaptif | 200–300 ms | 400–700 ms | 700–900 ms |
| Hop limit HEARTBEAT | 2 | 2 | 2 |
| Hop limit TRACKING | 3 | 3 | 3 |
| Hop limit SOS | 5 | 5 | 5 |
| Prioritas HEARTBEAT | 0 (terendah) | 0 | 0 |
---

## Wiring ESP32

### LoRa SX1278 (sama di ketiga node)
| ESP32 | LoRa |
|---|---|
| 3V3 | VCC |
| GND | GND |
| Pin 5 | SCK |
| Pin 19 | MISO |
| Pin 27 | MOSI |
| Pin 18 | NSS/CS |
| Pin 26 | DIO0 |
| Pin 23 | RST |

### GPS M10 (SAR & KORBAN saja)
| ESP32 | GPS |
|---|---|
| 3V3 | VCC |
| GND | GND |
| Pin 16 (RX2) | TX GPS |
| Pin 17 (TX2) | RX GPS |

### Tombol SOS (KORBAN saja)
| ESP32 | Tombol |
|---|---|
| Pin 4 | Kaki 1 |
| GND | Kaki 2 |

> Tidak perlu resistor eksternal — firmware menggunakan `INPUT_PULLUP` internal ESP32.

---

## Yang Wajib Diubah per Device Sebelum Upload

### GATEWAY
```cpp
// Tidak ada yang perlu diubah — NODE_ID selalu 0
#define NET_ID   "PR01"   // Samakan dengan SAR & KORBAN
```

### SAR
```cpp
#define NODE_ID  1001     // Ganti: 1001, 1002, 1003, ... (per device)
#define NET_ID   "PR01"   // Samakan dengan GATEWAY & KORBAN
```

### KORBAN
```cpp
#define NODE_ID  2001     // Ganti: 2001, 2002, 2003, ... (per device)
#define NET_ID   "PR01"   // Samakan dengan GATEWAY & SAR
```
---
# Coding Standards

Use:

- C++17
- PlatformIO
- Separate .h and .cpp files
- Small reusable functions
- Clear variable names
- feel free to use any library, API, ext, but NO EXTRA CHARGE/FEE! (totaly free)
- the main dashboard/html will be run localy, but still using wifi (if must)
Avoid:

- Extremely long functions
- Code duplication
- Magic numbers
- Unnecessary global variables
---

# Embedded Constraints

Always remember:

ESP32 has limited RAM and other resource.

Prefer:

- static allocation
- fixed-size buffers
- lightweight algorithms

Avoid:

- unnecessary dynamic allocation
- large STL containers
- recursion unless necessary

---

# LoRa Routing Rules

The routing algorithm is based on Controlled Flooding.

Current concepts include:

- Packet ID
- TTL
- Duplicate Detection
- Hop Count
- Forwarding Decision
- Battery-aware forwarding (future)
- Priority messages (future)

Never redesign the routing algorithm unless explicitly requested.

---

# Packet Compatibility

Do not modify packet structures unless explicitly instructed.

Maintain backward compatibility whenever possible.

Explain the consequences before changing packet formats.

---

# Safety

Before implementing any feature:

1. Explain the implementation plan.
2. Explain affected modules.
3. Explain risks.
4. Wait for approval if architectural changes are required.

Never make large architectural changes without confirmation.

---

# Error Handling

Do not silently ignore errors.

Prefer:

- clear logs
- descriptive return values
- recoverable failures

---

# Documentation

Whenever implementing a major feature:

Update:

- README
- Relevant docs inside /docs

if necessary.

---

# Testing

Whenever possible:

- explain how to test
- identify edge cases
- identify failure scenarios

---

# Communication Style

Always:

- explain reasoning
- mention trade-offs
- prefer maintainable solutions
- ask questions if requirements are unclear
- berbahasa indonesia

Do not assume hidden requirements.
