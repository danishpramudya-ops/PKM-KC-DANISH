<div align="center">
  <img src="dashboard/assets/logo.png" alt="ANCHORPULSE / Point Rescue" width="120">

  # ANCHORPULSE — Point Rescue

  **Alat komunikasi taktis untuk evakuasi bencana di area tanpa sinyal (Non-Line-Of-Sight).**
  Mesh LoRa + GPS untuk berbagi posisi dan sinyal SOS, dipantau lewat dashboard web lokal.
</div>

---

## Apa ini?

Node saling terhubung tanpa WiFi/seluler memakai **LoRa 433 MHz** membentuk
**mesh** (controlled flooding). Node **SAR** (penyelamat) dan **KORBAN** berbagi
posisi GPS; satu node **GATEWAY** di posko meneruskan semua data ke PC untuk
ditampilkan di **dashboard** (peta real-time, status node, SOS, dan **pengukuran
jarak antar node**).

- ESP32 · LoRa SX1278 433 MHz · GPS u-blox (Neo-M8N / M10)
- Tanpa internet, tanpa seluler
- Dashboard lokal (Python + HTML/JS, peta Leaflet/OpenStreetMap)

---

## Struktur proyek

```
firmware/     Kode ESP32 (3 peran: GATEWAY / SAR / KORBAN) + README
dashboard/    Dashboard web + pipeline Python + simulator + assets
mobile/       App Android untuk personel SAR (BLE ke node SAR) + README
docs/         Dokumentasi teknis (arsitektur, protokol, fitur jarak)
refrence/     Arsip implementasi awal (tidak dipakai saat menjalankan)
```

Dokumentasi teknis:
[Arsitektur](docs/arsitektur-sistem.md) ·
[Protokol paket & routing](docs/protokol-paket.md) ·
[Fitur jarak](docs/fitur-jarak.md) ·
[Panduan firmware](firmware/README.md) ·
[App mobile SAR](mobile/README.md)

---

## Prasyarat

| Untuk | Butuh |
|---|---|
| Dashboard & simulator | **Python 3.9+** dan `pip install pyserial` |
| Firmware | **Arduino IDE**/arduino-cli + library `LoRa`, `TinyGPSPlus`, `ArduinoJson 7.x` (lihat [firmware/README.md](firmware/README.md)) |

---

## Cara menjalankan

Ada dua jalur. Coba **Jalur B dulu** kalau ingin langsung melihat dashboard-nya
tanpa merakit perangkat.

### Jalur A — Dengan perangkat asli

1. **Flash firmware** ke tiap ESP32 (atur `NODE_ID`/`NET_ID` per unit).
   Panduan lengkap: [firmware/README.md](firmware/README.md).
2. **Colok GATEWAY** ke PC via USB. Nyalakan node SAR/KORBAN.
3. **Jalankan listener** (baca serial GATEWAY → tulis `gps.json`):
   ```bash
   cd dashboard
   pip install pyserial            # sekali saja
   python serial_listener.py       # auto-pilih port, atau: --port COM5
   ```
4. **Jalankan server** di terminal terpisah:
   ```bash
   cd dashboard
   python server.py                # buka browser otomatis ke http://localhost:8000
   ```
5. Buka **http://localhost:8000** bila belum terbuka.

### Jalur B — Demo tanpa hardware (pakai simulator)

Menjalankan node SAR & KORBAN palsu yang bergerak, agar seluruh dashboard +
fitur jarak bisa dicoba.

**Terminal 1** — server:
```bash
cd dashboard
python server.py
```
**Terminal 2** — simulator:
```bash
cd dashboard
python simulate.py                 # 2 SAR + 2 KORBAN bergerak
# contoh lain:
python simulate.py --sos 2001      # node 2001 mengirim SOS
python simulate.py --sar 3 --korban 2 --interval 0.5
```
Lalu buka **http://localhost:8000**. Hentikan simulator dengan `Ctrl+C`.

---

## Mencoba fitur jarak

Setelah ada ≥ 2 node berposisi di peta:

- **Panel "Jarak Antar Node"** (kanan) menampilkan jarak semua pasangan, terupdate
  otomatis; pasangan terdekat disorot. Klik satu baris → garis pasangan tergambar
  di peta.
- Tombol **"Ukur Jarak"** (kanan-atas peta) → klik node A lalu node B untuk
  menggambar garis + label jarak. Tombol *layers_clear* untuk membersihkan.
- GATEWAY tampil sebagai **base tetap** (tanpa GPS). Detail & cara ganti lokasi:
  [docs/fitur-jarak.md](docs/fitur-jarak.md).

---

## Aplikasi Mobile (App SAR)

Personel SAR yang membawa node SAR di lapangan (jauh dari GATEWAY/PC) bisa
memakai **app Android terpisah** di [mobile/](mobile/) — terhubung lewat
Bluetooth Low Energy langsung ke node SAR yang dibawa, untuk melihat daftar
node & lokasi, serta chat tim (di-broadcast ke mesh LoRa sebagai paket
`PKT_CHAT`). Panduan lengkap & stack teknologi: [mobile/README.md](mobile/README.md).

Ini proyek Flutter yang berdiri sendiri — tidak memengaruhi cara menjalankan
dashboard di atas.

---

## Troubleshooting singkat

| Masalah | Solusi |
|---|---|
| Browser tidak menampilkan node | Pastikan `serial_listener.py` **atau** `simulate.py` sedang jalan (yang menulis `gps.json`). |
| `serial_listener.py` tak menemukan port | Colok GATEWAY, cek driver USB (CP2102/CH340). Jalankan `python serial_listener.py --debug`. |
| Node tak muncul walau listener jalan | Node kirim heartbeat saja (tanpa lokasi) atau `NET_ID` beda. Cek `--debug`. |
| Peta kosong/abu-abu | Butuh internet untuk tile OpenStreetMap. Pastikan PC daring saat membuka dashboard. |
| Port 8000 dipakai | `python server.py --port 8080` lalu buka `http://localhost:8080`. |

---

## Prioritas desain (CLAUDE.md)

Reliability › Simplicity › Low Power › Memory efficiency › Maintainability › Readability.
Algoritma routing dan format paket dijaga stabil dan tidak diubah tanpa permintaan
eksplisit.
