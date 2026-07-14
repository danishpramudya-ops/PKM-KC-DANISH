# ANCHORPULSE — Firmware ESP32

Firmware untuk tiga peran node pada jaringan mesh LoRa ANCHORPULSE / Point Rescue.
Logika routing (controlled flooding), format paket, dan parameter LoRa **identik**
di ketiga peran — hanya perilaku peran yang berbeda.

| Sketch | Peran | Node ID | GPS | Tombol SOS | Relay paket |
|---|---|---|---|---|---|
| `point_rescue_GATEWAY/` | Base station (colok ke PC) | `0` | ❌ | ❌ | ✅ selalu |
| `point_rescue_SAR/` | Tim penyelamat | `1001,1002,…` | ✅ | Serial | ✅ selalu |
| `point_rescue_KORBAN/` | Korban/orang hilang | `2001,2002,…` | ✅ | Tombol fisik + Serial | ❌ tidak pernah |

---

## 1. Prasyarat perangkat lunak

**Arduino IDE** (1.8.x atau 2.x) atau **arduino-cli**.

### Board package
- Pasang **esp32 by Espressif Systems** lewat Boards Manager.
- Board: **ESP32 Dev Module** (ESP32 30-pin / DOIT DEVKIT V1).
- Upload speed: 115200.

### Library (Library Manager)
| Library | Penulis | Versi |
|---|---|---|
| `LoRa` | Sandeep Mistry | ≥ 0.8.0 |
| `TinyGPSPlus` | Mikal Hart | ≥ 1.0.3 |
| `ArduinoJson` | Benoit Blanchon | **7.x** |

> Kode memakai API ArduinoJson 7 (`JsonDocument doc;` tanpa kapasitas). Jangan
> pakai ArduinoJson 6 — API-nya berbeda dan tidak akan ter-compile.
>
> GATEWAY tidak butuh `TinyGPSPlus` (tak ada GPS), tapi tak masalah bila terpasang.

### BLE — hanya untuk `point_rescue_SAR/`
Sketch SAR memakai `BLEDevice`/`BLEServer`/`BLE2902` dari **board package esp32
itu sendiri** (bukan library terpisah — tidak perlu install apa pun tambahan).
Ini jembatan lokal ke [mobile app](../mobile/README.md); detail GATT service
& characteristic ada di [../docs/protokol-paket.md §8](../docs/protokol-paket.md).

> **Catatan RAM:** LoRa + GPS parsing + BLE stack berjalan bersamaan di ESP32
> yang sama. Belum diuji di hardware asli (lingkungan pengembangan ini tidak
> punya `arduino-cli`/toolchain ESP32 untuk compile-check) — **wajib** compile
> & flash langsung ke board SAR untuk verifikasi sebelum dipakai di lapangan.
> Bila RAM/stability jadi masalah, pertimbangkan migrasi ke library `NimBLE-Arduino`
> (footprint lebih kecil) sebagai langkah optimasi lanjutan.

---

## 2. Wiring

### LoRa SX1278 433 MHz (sama di ketiga node)
| ESP32 | LoRa |
|---|---|
| 3V3 | VCC |
| GND | GND |
| GPIO5 | SCK |
| GPIO19 | MISO |
| GPIO27 | MOSI |
| GPIO18 | NSS/CS |
| GPIO26 | DIO0 |
| GPIO23 | RST |

### GPS u-blox (Neo-M8N / M10) — **SAR & KORBAN saja**
| ESP32 | GPS |
|---|---|
| 3V3 | VCC |
| GND | GND |
| GPIO16 (RX2) | TX GPS |
| GPIO17 (TX2) | RX GPS |

### Tombol SOS — **KORBAN saja**
| ESP32 | Tombol |
|---|---|
| GPIO4 | Kaki 1 |
| GND | Kaki 2 |

> Tidak perlu resistor eksternal — firmware memakai `INPUT_PULLUP` internal.

---

## 3. Yang WAJIB diubah per unit sebelum upload

Buka file `.ino` yang sesuai, ubah nilai di bagian atas:

```cpp
// GATEWAY — tidak ada yang perlu diubah (NODE_ID selalu 0)
#define NET_ID   "PR01"

// SAR
#define NODE_ID  1001     // ganti unik per unit SAR: 1001, 1002, 1003, ...
#define NET_ID   "PR01"

// KORBAN
#define NODE_ID  2001     // ganti unik per unit KORBAN: 2001, 2002, 2003, ...
#define NET_ID   "PR01"
```

**Aturan penting:**
- `NET_ID` **harus sama persis** di semua node yang ingin saling terhubung
  (default `"PR01"`). Paket dari `NET_ID` berbeda diabaikan.
- `NODE_ID` **harus unik** di seluruh jaringan. ID menentukan peran otomatis:
  `0` = GATEWAY, `1xxx` = SAR, `2xxx` = KORBAN (peran = `NODE_ID / 1000`).

---

## 4. Upload

1. Pilih sketch (mis. `point_rescue_SAR/point_rescue_SAR.ino`).
2. Tools → Board → ESP32 Dev Module; pilih Port yang benar.
3. Ubah `NODE_ID`/`NET_ID` sesuai unit (lihat §3).
4. Upload. Jika gagal, tahan tombol **BOOT** di ESP32 saat "Connecting...".
5. Buka Serial Monitor **115200 baud** untuk melihat log.

Dengan arduino-cli:
```bash
arduino-cli compile --fqbn esp32:esp32:esp32 point_rescue_SAR
arduino-cli upload  --fqbn esp32:esp32:esp32 -p COM5 point_rescue_SAR
```

---

## 5. Uji cepat & trigger SOS

Di Serial Monitor tiap node akan tampil log `[TX]`, `[RX]`, `[RELAY]`.

- **KORBAN**: tekan tombol fisik (GPIO4→GND) **atau** ketik `SOS` lalu Enter.
- **SAR**: ketik `SOS` lalu Enter di Serial Monitor.
- **GATEWAY**: tidak mengirim SOS; tugasnya menerima & relay ke PC.

SOS punya prioritas & hop-limit tertinggi (lihat [../docs/protokol-paket.md](../docs/protokol-paket.md)).

---

## 6. Menghubungkan ke dashboard

Hanya **GATEWAY** yang dicolok ke PC. Jalankan `serial_listener.py` pada port
GATEWAY untuk meneruskan data ke dashboard. Lihat
[../README.md](../README.md) dan [../dashboard/](../dashboard/).

> Node dengan `gps_valid=false` mengirim koordinat *dummy* (belum dapat fix GPS).
> Bawa perangkat ke area terbuka agar mendapat sinyal satelit.
