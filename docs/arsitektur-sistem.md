# Arsitektur Sistem ANCHORPULSE

ANCHORPULSE (Point Rescue) adalah alat komunikasi taktis untuk evakuasi bencana
di area **Non-Line-Of-Sight** (tanpa WiFi/seluler). Node saling terhubung lewat
**LoRa mesh** dan berbagi posisi GPS. Satu node **GATEWAY** meneruskan seluruh
data ke PC untuk dipantau di **dashboard web lokal**.

---

## 1. Peran node

| Peran | Node ID | Fungsi |
|---|---|---|
| **GATEWAY** | `0` | Base station di posko, tersambung PC. Selalu me-relay. Tanpa GPS. |
| **SAR** | `1001+` | Tim penyelamat. Broadcast posisi, relay paket, bisa trigger SOS. |
| **KORBAN** | `2001+` | Orang hilang/korban. Broadcast posisi + SOS. **Tidak** me-relay (hemat daya). |

Peran ditentukan otomatis dari `NODE_ID / 1000`.

---

## 2. Alur data end-to-end

```
   [SAR]      [KORBAN]          Node lapangan mem-broadcast paket JSON
     \          /               (tracking tiap 5s, heartbeat tiap 10s, SOS saat ditekan)
      \  LoRa  /                Controlled flooding: node lain me-relay dengan
       \ mesh /                 hop-limit + duplicate detection
        \    /
      [ GATEWAY ]               Menerima semua paket, cetak ke Serial (USB)
          |  USB serial 115200
          v
   serial_listener.py           Baca serial → parse JSON → normalisasi field
          |  tulis                (lat→latitude, dst) → tulis gps.json
          v
       gps.json                 Snapshot node aktif (array), di-overwrite tiap update
          |  HTTP (fetch)
          v
     server.py  ─────►  Browser (index.html + script.js + style.css)
   (HTTP no-cache)      Peta Leaflet, sidebar, panel jarak, banner SOS
```

Untuk **demo tanpa hardware**, `simulate.py` menggantikan
`(node LoRa + GATEWAY + serial_listener.py)` dengan menulis `gps.json` langsung.

### Jalur kedua: App mobile SAR (BLE, lokal)

```
   [Node SAR]  ── BLE (lokal, jangkauan pendek) ──►  [HP personel SAR]
        |                                                  |
   (paket mesh yang sama persis yang di-relay ke LoRa)      |
        └──────────────────────────────────────────────────┘
                    mobile/ (Flutter, lihat mobile/README.md)
```

Jalur ini **independen** dari jalur GATEWAY/dashboard di atas — node SAR
meneruskan paket yang sama (tracking/heartbeat/SOS/chat) lewat BLE ke HP yang
terhubung, sambil tetap mem-broadcast ke mesh LoRa seperti biasa. Detail GATT
service: [protokol-paket.md §8](protokol-paket.md).

---

## 3. Pemetaan ke modul (CLAUDE.md)

Firmware satu sketch per peran, tetapi secara logis terbagi menjadi blok modular:

| Modul (konsep) | Lokasi di firmware |
|---|---|
| LoRa Driver | `setup()` init SPI+LoRa, `processTxQueue()`, `handleIncomingPacket()` |
| GPS Driver | `gpsSerial` + `gps.encode()` (SAR/KORBAN) |
| Packet Manager | `buildPacket()` / `buildHeartbeat()`, `validatePacket()` |
| Routing | `handleIncomingPacket()` + `hopLimitFor()` (controlled flooding) |
| Duplicate Detection | `seenCache[]`, `isPacketSeen()`, `markPacketSeen()` |
| Priority TX Queue | `txQueue[]`, `enqueueTx()`, `pickHighestPriorityIdx()` |
| BLE Bridge (hanya SAR) | `initBLE()`, `bleNotifyMeshPacket()`, `bleNotifyChat()`, `originateChat()` |
| UI/Logging | `Serial.printf(...)` (OLED/LED menyusul sesuai tahap hardware) |

Sisi PC:

| Komponen | File |
|---|---|
| Serial ingest & normalisasi | `dashboard/serial_listener.py` |
| HTTP server lokal | `dashboard/server.py` |
| Simulator (dev) | `dashboard/simulate.py` |
| UI dashboard | `dashboard/index.html`, `script.js`, `style.css` |

---

## 4. Keputusan desain kunci

- **Controlled flooding**, bukan routing tabel — sederhana & tahan terhadap node
  yang datang/pergi, cocok untuk skenario bencana. Detail:
  [protokol-paket.md](protokol-paket.md).
- **KORBAN tidak me-relay** — menghemat daya baterai node yang dibawa korban;
  jaringan tetap tersambung lewat SAR & GATEWAY.
- **Delay adaptif per peran** (GATEWAY tercepat, KORBAN terlambat) mengurangi
  tabrakan paket di kanal LoRa yang half-duplex.
- **GATEWAY tanpa GPS** → di dashboard ditampilkan sebagai **base tetap**
  (dikonfigurasi manual). Lihat [fitur-jarak.md](fitur-jarak.md).
- **gps.json sebagai perantara** — memisahkan proses serial (Python) dari UI
  (browser); UI cukup polling file, tanpa dependency websocket.
- **BLE di node SAR sebagai jembatan mobile** — dipilih ketimbang menaruh BLE
  di GATEWAY, karena SAR yang dibawa personel di lapangan (jauh dari GATEWAY);
  paket yang di-forward BLE persis sama dengan yang di-relay LoRa, jadi tidak
  ada logika baru untuk dijaga konsisten dengan protokol utama.

---

## 5. Toleransi kegagalan

- **Duplicate detection** (TTL 30s) mencegah badai paket saat flooding.
- **serial_listener.py**: auto-reconnect bila kabel serial terputus; buang paket
  `seq` lama/duplikat.
- **Dashboard**: deteksi node offline (>10s tanpa update) & status koneksi;
  fetch error ditangani tanpa crash.
- **Rencana firmware** (objektif CLAUDE.md, menyusul): auto-reset bila gagal
  mendeteksi node lain selama beberapa menit.
