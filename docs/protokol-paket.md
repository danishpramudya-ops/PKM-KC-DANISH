# Protokol Paket & Routing

> ⚠️ Format paket dan algoritma routing **tidak boleh diubah** tanpa permintaan
> eksplisit (CLAUDE.md). Dokumen ini mendeskripsikan yang sudah berjalan.

---

## 1. Format paket (JSON)

Setiap paket dikirim sebagai satu baris JSON melalui LoRa.

### Field wajib (semua paket)
| Field | Tipe | Arti |
|---|---|---|
| `net` | string | Network ID (mis. `"PR01"`). Paket dengan `net` beda diabaikan. |
| `id` | int | Node ID pengirim asal (origin). Menentukan peran = `id/1000`. |
| `seq` | int | Nomor urut paket dari origin (naik terus). |
| `type` | int | 0 = HEARTBEAT, 1 = TRACKING, 2 = SOS, 3 = CHAT. |
| `hop` | int | Jumlah hop yang sudah dilewati (mulai 0 di origin). |

### Field lokasi (hanya TRACKING & SOS; heartbeat & chat tidak membawa lokasi)
| Field | Tipe | Arti |
|---|---|---|
| `lat` | float | Lintang. |
| `lng` | float | Bujur. |
| `alt` | float | Ketinggian (m). |
| `spd` | float | Kecepatan (m/s). |
| `sats` | int | Jumlah satelit. |
| `valid` | bool | `true` bila fix GPS asli; `false` bila koordinat dummy (belum fix). |

### Field pesan (hanya CHAT)
| Field | Tipe | Arti |
|---|---|---|
| `msg` | string | Isi pesan chat tim SAR. Maks **100 karakter** (`CHAT_MSG_MAX_LEN`) — dibatasi supaya airtime LoRa tetap kecil. Paket dengan `msg` lebih panjang atau bukan string ditolak `validatePacket()`. |

Contoh paket TRACKING:
```json
{"net":"PR01","id":1001,"seq":42,"type":1,"hop":0,
 "lat":-7.95385,"lng":112.61496,"alt":535.5,"spd":0.0,"sats":10,"valid":true}
```

Contoh paket CHAT (asal dari node SAR, dikirim lewat BLE dari HP — lihat
[../mobile/README.md](../mobile/README.md)):
```json
{"net":"PR01","id":1001,"seq":57,"type":3,"hop":0,"msg":"kontak di sisi utara, butuh bantuan angkut"}
```

---

## 2. Identitas paket & duplicate detection

Identitas unik sebuah paket = `id + "-" + seq` (mis. `1001-42`).

Tiap node menyimpan **cache 30 entri** (`seenCache`) dengan TTL **30 detik**:
- Jika paket sudah pernah dilihat → **diabaikan** (mencegah loop/badai flooding).
- Jika belum → diproses, ditandai, lalu (bila boleh) di-relay.

---

## 3. Controlled flooding (relay)

Saat menerima paket baru yang valid dan belum pernah dilihat:

1. Abaikan bila `id == NODE_ID` (paket sendiri yang memantul).
2. Cek duplikat (§2).
3. Cek **hop limit** per tipe. Bila `hop + 1 > maxHop` → berhenti (tidak relay).
4. Bila boleh relay: `hop += 1`, masukkan ke antrian TX.

**Hop limit per tipe:**
| Tipe | Hop limit |
|---|---|
| HEARTBEAT | 1 |
| TRACKING | 3 |
| CHAT | 4 |
| SOS | 5 |

**Siapa yang me-relay:**
| Peran | Relay? |
|---|---|
| GATEWAY | ✅ selalu |
| SAR | ✅ selalu |
| KORBAN | ❌ tidak pernah (hemat daya) |

---

## 4. Prioritas & antrian TX

Kanal LoRa half-duplex → hanya satu paket bisa dikirim dalam satu waktu.
Tiap node punya **antrian TX (8 slot)** dengan prioritas:

| Tipe | Prioritas |
|---|---|
| SOS | 3 (tertinggi) |
| CHAT | 2 |
| TRACKING | 1 |
| HEARTBEAT | 0 (terendah) |

> Prioritas ini murni keputusan lokal tiap node untuk menjadwalkan antrian TX-nya
> sendiri (`priorityFor(type)`) — nilainya **tidak** ikut dikirim di paket JSON,
> jadi mengubah skala ini tidak memengaruhi kompatibilitas antar node.

`processTxQueue()` mengirim paket berprioritas tertinggi (bila sama, yang lebih
lama mengantre). Setelah kirim, node menunggu **delay adaptif** sebelum TX
berikutnya, berbeda per peran untuk mengurangi tabrakan:

| Peran | Delay TX |
|---|---|
| GATEWAY | 200–300 ms (tercepat, hub utama) |
| SAR | 400–700 ms |
| KORBAN | 700–900 ms (terlambat, hanya paket sendiri) |

---

## 5. Perilaku broadcast

| | GATEWAY | SAR | KORBAN |
|---|---|---|---|
| TRACKING (lokasi sendiri) | ❌ | tiap 5 s | tiap 5 s |
| HEARTBEAT | tiap 10 s | tiap 10 s | tiap 10 s |
| SOS | ❌ | via Serial | tombol fisik + Serial |
| CHAT | ❌ (relay saja) | via BLE (mobile app) | ❌ (relay saja, tak pernah kirim) |

Semua node (termasuk KORBAN yang tak me-relay) mengenali `type=3` (CHAT) di
`validatePacket()` supaya tidak salah ditolak sebagai paket tidak valid — hanya
**SAR** yang benar-benar bisa origination CHAT (lewat BLE), GATEWAY & KORBAN
sekadar meneruskan bila boleh relay.

---

## 6. Parameter radio LoRa (sama di semua node)

| Parameter | Nilai |
|---|---|
| Frekuensi | 433 MHz |
| Spreading Factor | 10 |
| Bandwidth | 125 kHz |
| Coding Rate | 4/5 |
| TX Power | 20 dBm |

> Mengubah salah satu parameter ini berarti node lama & baru **tidak akan saling
> mendengar**. Ubah serempak di semua unit bila perlu.

---

## 7. Konsekuensi bila format paket diubah

Menambah/menghapus field berisiko:
- **serial_listener.py** menolak paket bila field wajib (`net,id,seq,type,hop`)
  hilang → node tak muncul di dashboard.
- Node firmware versi lama & baru bisa saling tolak → jaringan pecah.

Bila memang perlu ubah: naikkan versi, jaga kompatibilitas mundur, dan uji
seluruh unit bersamaan. Jelaskan dampak sebelum mengeksekusi.

---

## 8. Jembatan BLE di node SAR (untuk mobile app)

Node **SAR** (dan hanya SAR) menjalankan **BLE GATT server** di samping tugas
LoRa-nya, sebagai jembatan ke aplikasi mobile yang dibawa personel SAR. Ini
**tidak mengubah** apa pun di jalur LoRa/mesh — BLE murni komunikasi lokal
HP ↔ node SAR yang sedang dipegang.

Service `ANCHORPULSE Bridge` (UUID lihat `firmware/point_rescue_SAR/point_rescue_SAR.ino`):

| Characteristic | Arah | Isi |
|---|---|---|
| `NODE_INFO` | read/notify | JSON info node SAR ini sendiri (id, net, uptime). |
| `MESH_RX` | notify | JSON paket mesh apa pun (TRACKING/SOS/HEARTBEAT/CHAT) yang baru diterima node ini dari LoRa — payload **sama persis** dengan yang dicetak ke Serial/diteruskan ke `serial_listener.py`. |
| `CHAT_TX` | write | HP menulis teks pesan ke sini → node SAR membungkusnya jadi paket `PKT_CHAT` (origin = node SAR ini) dan mengantrekannya ke TX queue LoRa yang sudah ada. |
| `CHAT_RX` | notify | Notifikasi khusus saat node ini menerima/relay paket CHAT — supaya app tidak perlu mem-parse ulang `MESH_RX` untuk filter chat. |

Detail implementasi & cara pakai dari sisi aplikasi: [../mobile/README.md](../mobile/README.md).
