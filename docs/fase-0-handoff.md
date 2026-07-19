# Fase 0 — Handoff Document: Reliability & Correctness

**Dokumen ini self-contained.** Seorang engineer atau AI lain harus bisa
menyelesaikan seluruh Fase 0 hanya dengan dokumen ini plus akses ke repo,
tanpa membaca riwayat percakapan mana pun.

> **Ini satu-satunya dokumen handoff untuk Fase 0.** Kalau menemukan dokumen
> handoff lain untuk fase ini, dokumen itu usang.

| | |
|---|---|
| Fase | 0 — Reliability & Correctness (0A + 0B + 0C) |
| Status | Menunggu persetujuan pemilik proyek |
| Branch | `fase-0-reliability` |
| Rencana rinci | `docs/fase-0a-implementation-plan.md`<br>`docs/fase-0b-implementation-plan.md`<br>`docs/fase-0c-implementation-plan.md` |
| Strategi keseluruhan | `docs/strategi-ux.md` |
| Protokol paket | `docs/protokol-paket.md` — **hanya baca** |

---

## 1. Konteks proyek

**POINTRESCUE** adalah sistem komunikasi taktis untuk evakuasi bencana di area
tanpa internet dan tanpa sinyal seluler (Non-Line-Of-Sight). Node LoRa mesh
berbasis ESP32 saling meneruskan paket dengan algoritma *controlled flooding*.

Tiga peran node, dibedakan dari rentang ID-nya:

| Peran | Node ID | GPS | Menyiarkan lokasi | Boleh me-relay |
|---|---|---|---|---|
| GATEWAY | `0` | ❌ | ❌ (hanya heartbeat) | ✅ selalu |
| SAR | `1001`, `1002`, … | ✅ | ✅ tiap 5 detik | ✅ selalu |
| KORBAN | `2001`, `2002`, … | ✅ | ✅ tiap 5 detik | ❌ tidak pernah |

Empat tipe paket: `HEARTBEAT=0`, `TRACKING=1`, `SOS=2`, `CHAT=3`.
Semua node mengirim heartbeat tiap 10 detik.

**Dua permukaan perangkat lunak:**
- `mobile/` — aplikasi Flutter untuk relawan SAR di lapangan *(fokus fase ini)*
- `dashboard/` — dashboard web untuk command center *(tidak disentuh di fase ini)*

**Cara mobile terhubung:** HP tersambung lewat **BLE** ke **satu node SAR**
yang dibawa relawan. Node SAR itu bertindak sebagai jembatan — ia meneruskan
setiap paket LoRa yang didengarnya ke HP lewat notifikasi GATT, dan mengirim
pesan chat dari HP ke mesh LoRa.

```
[Node KORBAN] ──LoRa──┐
[Node SAR lain] ─LoRa─┼──→ [Node SAR milikku] ──BLE──→ [HP Relawan]
[Node GATEWAY] ──LoRa─┘
```

**Layanan GATT** (harus sama persis dengan firmware — jangan diubah):

| Characteristic | UUID | Arah |
|---|---|---|
| Service | `9c370001-3a1e-4f6a-9c37-a1b2c3d4e5f6` | — |
| NODE_INFO | `9c370002-…` | baca — id/net/role node yang tersambung |
| MESH_RX | `9c370003-…` | notify — tiap paket mesh sebagai JSON |
| CHAT_TX | `9c370004-…` | tulis — teks chat dari HP |
| CHAT_RX | `9c370005-…` | notify — chat masuk **dan echo pesan sendiri** |

---

## 2. Mengapa Fase 0 ada

Audit menyeluruh terhadap aplikasi mobile (2.065 baris, 21 berkas) menemukan
bahwa masalah terbesar bukan tampilan, melainkan **aplikasi yang macet dan
memberi informasi palsu**. Delapan bug P0 dikelompokkan jadi tiga bagian yang
menyentuh berkas **saling terpisah**, sehingga aman dikerjakan dalam satu sesi:

| Bagian | Isi | Berkas |
|---|---|---|
| **0A** | Keandalan koneksi | `connection_repository`, `anchorpulse_ble_service` |
| **0B** | Status node berhenti berbohong | `node_repository`, `node_status` |
| **0C** | Chat jujur | `chat_message`, `chat_repository`, `chat_screen` |

Setelah Fase 0, aplikasi akan terlihat **persis sama** seperti sekarang — tapi
berhenti macet dan berhenti berbohong. Itu memang tujuannya.

---

## 3. Keputusan arsitektur yang mengikat

Diambil dari `docs/strategi-ux.md`. **Jangan diubah sepihak.**

### Prinsip desain, urut prioritas
1. **Jujur tentang keadaan** — aplikasi tidak boleh menampilkan sesuatu yang
   lebih baik dari kenyataan. Ini mengalahkan prinsip lain saat bertabrakan.
2. **Nol ketukan di jalur normal**
3. **Terbaca dalam tiga detik**
4. **Gagal dengan terang** — setiap kegagalan punya sebab manusia, akibat, dan satu aksi
5. **Satu bahasa, dua dialek** (mobile + dashboard berbagi token)

Prinsip 1 adalah alasan keberadaan seluruh Fase 0. Kalau sebuah keputusan
implementasi membuat aplikasi terdengar lebih meyakinkan daripada yang bisa
dibuktikan, keputusan itu salah.

### Keputusan produk yang relevan
| Topik | Keputusan |
|---|---|
| Auto-connect | Otomatis hanya untuk node **tersimpan**; node baru dikonfirmasi sekali |
| Bahasa | Dwibahasa, default Indonesia (i18n baru masuk di Fase 1) |
| Arah visual | Tactical-Utilitarian |
| Animasi | Fungsional saja, ≤200ms |
| Skala | 5–20 node |
| Firmware | Boleh diubah — **tapi tidak di fase ini** |

### Arsitektur kode
```
presentation/  ← Widget. TIDAK BOLEH menyentuh flutter_blue_plus langsung.
     ↓ Provider
data/repositories/  ← State + logika bisnis (ChangeNotifier)
     ↓
data/ble/  ← Pembungkus tipis flutter_blue_plus. Nol logika bisnis.
```

Aturan ini sudah ditegakkan hari ini dan **harus dipertahankan**. Selama Fase 0,
tidak boleh ada berkas baru di `presentation/` yang mengimpor
`flutter_blue_plus` — hanya `connect_screen.dart` yang sudah melakukannya, dan
hanya untuk tipe `BluetoothDevice`.

---

## 4. Batasan keras

Melanggar salah satu berarti fase ini gagal.

| # | Batasan |
|---|---|
| B1 | **Nol perubahan protokol LoRa/BLE.** Tidak ada UUID, tipe paket, atau field JSON baru. |
| B2 | **Nol perubahan pada struktur JSON** yang dipakai dashboard. |
| B3 | **Nol perubahan visual.** Tidak ada tata letak, warna, ukuran huruf, padding, ikon, atau animasi yang diubah. **Hanya isi teks yang boleh berubah.** |
| B4 | **Nol pemutusan kompatibilitas firmware.** Aplikasi harus tetap bekerja dengan firmware yang ada hari ini, tanpa flash ulang. |
| B5 | **Perubahan sekecil mungkin.** Tanpa refactor oportunistik. Bug di luar cakupan dicatat di §12, bukan diperbaiki. |
| B6 | **Nol dependensi baru**, termasuk dependensi uji. |
| B7 | Satu commit per perubahan; tiap commit harus bisa di-build. |
| B8 | **Dilarang menampilkan klaim yang tidak bisa dibuktikan protokol.** Khususnya: tidak ada "Terkirim"/"Delivered"/ikon centang di chat. Lihat rencana 0C §1. |

---

## 5. Berkas

### 5.1 Boleh diubah
| Berkas | Bagian |
|---|---|
| `mobile/lib/core/constants/ble_constants.dart` | 0A, 0B, 0C — hanya **tambah** konstanta |
| `mobile/lib/data/repositories/connection_repository.dart` | 0A |
| `mobile/lib/data/ble/anchorpulse_ble_service.dart` | 0A |
| `mobile/lib/presentation/app.dart` | 0A (perkabelan `myNodeId`) |
| `mobile/lib/presentation/screens/connect_screen.dart` | 0A |
| `mobile/lib/presentation/widgets/connection_status_bar.dart` | 0A |
| `mobile/lib/data/repositories/node_repository.dart` | 0B |
| `mobile/lib/data/models/node_status.dart` | 0B *(hanya bila perlu)* |
| `mobile/lib/data/models/chat_message.dart` | 0C |
| `mobile/lib/data/repositories/chat_repository.dart` | 0C |
| `mobile/lib/presentation/screens/chat_screen.dart` | 0C |

### 5.2 Berkas baru
| Berkas | Isi |
|---|---|
| `mobile/lib/data/models/connection_failure.dart` | 0A — taksonomi kegagalan |
| `mobile/lib/core/utils/utf8_limit.dart` | 0C — pembatas byte sebagai fungsi murni |
| `mobile/test/data/models/connection_failure_test.dart` | 0A |
| `mobile/test/core/utils/utf8_limit_test.dart` | 0C |

### 5.3 🚫 TIDAK BOLEH DIUBAH
| Berkas / folder | Alasan |
|---|---|
| `firmware/**` | Batasan B1, B4 |
| `dashboard/**` | Batasan B2. Lihat §11 soal divergensi. |
| `docs/protokol-paket.md` | Sumber kebenaran protokol. Hanya baca. |
| `mobile/lib/data/models/mesh_packet.dart` | Cermin format paket firmware. Menyentuhnya = menyentuh protokol. |
| `mobile/lib/presentation/screens/map_screen.dart` | Fase 2 |
| `mobile/lib/presentation/screens/node_list_screen.dart` | Fase 2 |
| `mobile/lib/presentation/screens/settings_screen.dart` | Fase 1/3 |
| `mobile/lib/presentation/screens/developer_mode_screen.dart` | Fase 6 |
| `mobile/lib/presentation/screens/home_shell.dart` | Fase 2 |
| `mobile/lib/core/theme/app_theme.dart` | Fase 1. Menyentuhnya = perubahan visual. |
| `mobile/lib/presentation/widgets/premium_card.dart` | Fase 1 |
| `mobile/lib/presentation/widgets/node_tile.dart` | Fase 1/2 |
| UUID di `ble_constants.dart` | Batasan B1 |

---

## 6. Urutan pengerjaan

Kerjakan berurutan. **Satu commit per butir.**

```
0A:  C6 → C2 → C1 → C5 → C3 → C4 → C7
0B:  B4 → B1 → B2 → B3
0C:  C-1 → C-2 → C-3 → C-4
```

Boleh menggabungkan seluruh penambahan konstanta (`C6`, `B4`, `C-1`) menjadi
satu commit pembuka jika lebih rapi — itu satu-satunya penggabungan yang
diizinkan.

Detail tiap butir ada di rencana implementasi masing-masing. **Baca rencana
yang relevan sebelum mengerjakan bagiannya.**

---

## 7. Checklist implementasi

### 0A — Connection Reliability
- [ ] **C6** Konstanta: `scanTimeout`, `connectTimeout`, `reconnectInitial`, `reconnectMax`, `autoReconnectEnabled`
- [ ] **C2** `connection_failure.dart` — 7 kind, `fromException()`, simpan `technicalDetail`, cocokkan **tipe** dulu baru string
- [ ] **C1** Berlangganan `FlutterBluePlus.isScanning`; abaikan `false` sebelum `true` pertama; scan berakhir → `idle` atau `failed(nodeNotFound)`
- [ ] **C5** Bersihkan state bila `connect()` gagal setelah `device.connect()`; `rethrow` selalu
- [ ] **C3** `reconnecting` + `_userInitiatedDisconnect` + backoff 1→2→4→8→16→30s tanpa batas percobaan
- [ ] **C4** `app.dart` menyalin `myNodeId` ke `ChatRepository` lewat listener; hapus `connect_screen.dart:106`
- [ ] **C7** Tampilkan `failure.message`; teks status `reconnecting`

> **Sebelum C3:** verifikasi klaim bahwa `autoConnect: true` pada
> `flutter_blue_plus ^1.35.3` tidak bisa dikombinasikan dengan `mtu:`.
> Klaim itu **belum diverifikasi**. Baca dokumentasi/source paket terpasang,
> laporkan temuan, dan **berhenti untuk konfirmasi** sebelum lanjut.

### 0B — Truthful Node State
- [ ] **B4** Konstanta: `rebootSeqGap` (5), `rebootSilence` (2 menit), `presenceTick` (5 detik)
- [ ] **B1** Heartbeat boleh **membuat** node baru; `touch()` tetap **tidak** menulis `seq`
- [ ] **B2** Deteksi reboot: `gap >= rebootSeqGap` **atau** `silence > rebootSilence` → terima & reset baseline
- [ ] **B3** `Timer.periodic(presenceTick)` → `notifyListeners()`; guard `_nodes.isEmpty`; `cancel()` di `dispose()`

### 0C — Honest Chat
- [ ] **C-1** Konstanta: `chatMaxBytes` (100), `chatEchoTimeout` (10 detik)
- [ ] **C-2** `utf8_limit.dart` sebagai **fungsi murni**; formatter membungkusnya; **jangan pernah** memotong di tengah rune; `maxLength: 100` **dipertahankan** demi penghitung
- [ ] **C-3** Sisipan optimistis + status `sending`/`handedToNode`/`failed` + rekonsiliasi echo + timer batas waktu
- [ ] **C-4** Status ditampilkan di `Text` jam yang **sudah ada**; `handedToNode` tanpa teks tambahan
- [ ] **B8** Verifikasi: tidak ada string "Terkirim"/"Delivered", tidak ada ikon centang

---

## 8. Checklist pengujian

### Otomatis
- [ ] `connection_failure_test.dart` — tiap kind, fallback `unknown`, `technicalDetail` terisi
- [ ] `utf8_limit_test.dart` — ASCII, aksen, emoji, tempel panjang, **tidak pernah membelah rune**
- [ ] `test/widget_test.dart` yang ada tetap lulus **tanpa diubah**
- [ ] `flutter analyze` bersih, nol peringatan baru

### Manual — butuh 1 HP Android + node SAR, GATEWAY, dan KORBAN

**0A — koneksi**
- [ ] M1 Scan tanpa hasil → tombol hidup kembali, bisa pindai lagi *(bug utama)*
- [ ] M2 Sambung normal tanpa regresi
- [ ] M3 Putus tak sengaja → "Menyambungkan ulang… (percobaan N)"
- [ ] M4 Pulih otomatis tanpa sentuhan
- [ ] M5 Chat setelah sambung ulang muncul di **kanan** *(verifikasi C4)*
- [ ] M6 Putus sengaja → **TIDAK** menyambung ulang *(verifikasi C3)*
- [ ] M7 Bluetooth mati → pesan manusia, tanpa teks exception
- [ ] M8 Izin ditolak → pesan izin yang benar
- [ ] M9 Perangkat salah → state bersih *(verifikasi C5)*
- [ ] M10 Pindai 5× berturut → tanpa duplikat/kebocoran
- [ ] M11 Regresi node & peta setelah sambung ulang

**0B — status node**
- [ ] N1 GATEWAY muncul di daftar *(bug utama)*
- [ ] N2 GATEWAY **tidak** muncul di peta
- [ ] N3 Node tanpa fix GPS tetap muncul lewat heartbeat
- [ ] N4 Node restart pulih ≤20 detik *(bug utama)*
- [ ] N5 Duplikat multi-hop masih ditolak
- [ ] N6 Semua node jadi Offline ≤65 detik tanpa interaksi *(bug utama)*
- [ ] N7 Teks waktu relatif menyegar sendiri
- [ ] N8 Node pulih kembali jadi Online
- [ ] N9 Timer presence tidak bocor setelah sambung ulang

**0C — chat**
- [ ] P1 Pesan muncul seketika
- [ ] P2 Batas ASCII 100
- [ ] P3 Emoji tidak pernah rusak *(bug utama)*
- [ ] P4 Tanpa duplikat
- [ ] P5 Pesan identik berturut-turut
- [ ] P6 Kegagalan terlihat, tidak pernah senyap *(bug utama)*
- [ ] P7 Pesan node lain di kiri tanpa status
- [ ] P8 Kirim setelah sambung ulang muncul di kanan
- [ ] P9 Tidak ada "Terkirim"/centang

---

## 9. Definition of Done

**Fungsional**
- [ ] Seluruh AC di ketiga rencana implementasi terpenuhi
- [ ] Seluruh skenario manual M1–M11, N1–N9, P1–P9 lulus di perangkat sungguhan

**Kualitas**
- [ ] Nol `e.toString()` mencapai widget *(`grep -rn "toString()" mobile/lib/presentation/`)*
- [ ] Nol string "Terkirim"/"Delivered"/ikon centang di chat
- [ ] Nol perubahan visual *(tangkapan layar sebelum/sesudah semua layar)*
- [ ] Nol perubahan di `firmware/`, `dashboard/`, `docs/protokol-paket.md` *(`git diff --stat`)*
- [ ] Nol dependensi baru *(`git diff mobile/pubspec.yaml` kosong)*
- [ ] `flutter analyze` bersih
- [ ] Semua uji otomatis lulus
- [ ] Semua timer dan langganan dibatalkan di `dispose()`

**Proses**
- [ ] Satu commit per butir, tiap commit bisa di-build
- [ ] `autoReconnectEnabled = false` mengembalikan perilaku lama
- [ ] Dokumen ini diperbarui dengan penyimpangan apa pun dari rencana
- [ ] Bug di luar cakupan dicatat di §12, bukan diperbaiki

---

## 10. Rollback

**Tingkat 1** — `autoReconnectEnabled = false`. Menonaktifkan 0A-C3. Satu baris.

**Tingkat 2** — balikkan satu commit. Ketergantungan:
`0A-C7` butuh `C1`+`C2`; `0A-C3` butuh `C6`; `0C-C-4` butuh `C-3`.
Selebihnya saling bebas. 0A, 0B, dan 0C sepenuhnya bebas satu sama lain.

**Tingkat 3** — balikkan branch. Karena nol perubahan pada firmware, dashboard,
dan protokol, pengembalian penuh **tidak mungkin memutus kompatibilitas apa pun**.

---

## 11. ⚠️ Divergensi dashboard yang diketahui

`dashboard/serial_listener.py` punya **dua bug yang sama persis** dengan yang
diperbaiki 0B:

| Baris | Bug | Padanan mobile |
|---|---|---|
| `223-233` | Heartbeat dari node yang belum dikenal diabaikan → GATEWAY tak terlihat | 0B-B1 |
| `248-252` | `seq <= prev` → node yang restart jadi hantu | 0B-B2 |

Setelah Fase 0, **mobile dan dashboard akan tidak sepakat** tentang node mana
yang ada. HP menampilkan GATEWAY; dashboard command center tidak.

**Ini disengaja dan diterima untuk Fase 0.** Dashboard berada di luar cakupan
(batasan B2 dan §5.3). Menyelipkan perbaikan Python ke dalam fase perbaikan
Flutter akan merusak reviewability yang jadi seluruh alasan pembagian fase ini.

**Kewajiban:** memindahkan kedua perbaikan yang sama ke `serial_listener.py`
adalah **butir wajib** dan sudah dicatat di `docs/strategi-ux.md` Fase 7.
Sampai itu dikerjakan, siapa pun yang menguji kedua permukaan berdampingan
harus tahu perbedaan ini **diharapkan**, bukan regresi.

---

## 12. Catatan untuk pelaksana

**Bug di luar cakupan yang sudah diketahui — JANGAN diperbaiki di sini:**
- `app_theme.dart:20` — `fontFamily: 'Inter'` tapi font tak pernah didaftarkan di `pubspec.yaml` → Fase 1
- `connect_screen.dart:31` — animasi denyut 1500ms melanggar aturan ≤200ms → Fase 2
- `connect_screen.dart:121` — string-replace ANCHORPULSE→POINTRESCUE, tambalan kosmetik → Fase 2 + firmware
- `chat_screen.dart:130` — tambalan `margin bottom: 24` untuk penghitung → Fase 2
- Penghitung karakter chat menyesatkan pada teks multi-byte → Fase 2 (lihat 0C §3)
- `node_list_screen.dart:43` — `NodeTile.onTap` tak pernah diteruskan; kartu memberi efek riak tapi tak melakukan apa pun → Fase 2
- `map_screen.dart:57` — marker tidak bisa diketuk, tanpa label → Fase 2
- 40+ warna hardcoded di seluruh `presentation/` → Fase 1
- `withOpacity()` usang di 40+ tempat, `withValues()` hanya di satu tempat → Fase 1
- Tidak ada posisi pengguna sendiri (tidak ada paket geolokasi) → Fase 2
- Peringatan getar/suara saat koneksi putus → **Fase 2 butir 14** (utang sadar dari 0A)

Kalau menemukan bug baru: **catat di sini, jangan diperbaiki.** Batasan B5.

**Keputusan yang sudah final — tidak perlu ditanyakan ulang:**
- Getar/suara/banner saat putus **ditunda ke Fase 2**. P0 #2 hanya tertutup
  sebagian setelah fase ini; itu disengaja dan disetujui.
- Uji otomatis **hanya untuk fungsi murni** (`ConnectionFailure.fromException`,
  pembatas UTF-8). Jangan menambah dependensi uji, jangan merefactor arsitektur
  demi testability di fase ini.
- Perbaikan `serial_listener.py` **ditunda ke Fase 7**. Lihat §11.

**Satu klaim yang harus diverifikasi, bukan dipercaya:**
Rencana 0A menyatakan `autoConnect: true` pada `flutter_blue_plus` tidak bisa
digabung dengan permintaan `mtu:`. Ini berasal dari ingatan, bukan dari
pembacaan dokumentasi versi terpasang (`flutter_blue_plus: ^1.35.3`).
**Periksa dulu, laporkan, lalu berhenti untuk konfirmasi.**

**Konteks perangkat keras:** proyek ini berjalan paralel dengan perancangan
perangkat keras. Tombol fisik, OLED, dan LED indikator belum ada. Jangan
berasumsi ada masukan selain layar sentuh.

---

## 13. Log penyimpangan dari rencana

Diisi selama implementasi, sesuai DoD ("dokumen ini diperbarui dengan
penyimpangan apa pun dari rencana").

**0A-C2 — getter shim `errorMessage`.**
Rencana meminta `String? errorMessage` diganti `ConnectionFailure? failure`.
Mengganti begitu saja membuat commit C2 tidak bisa build (connect_screen
masih membaca `errorMessage`). Solusi: `errorMessage` dipertahankan sementara
sebagai getter turunan `failure?.message`, dihapus di 0A-C7. Efek samping
yang disengaja: snackbar gagal-connect sudah menampilkan pesan manusia
sejak C2, bukan menunggu C7.

**0A-C1 — bentuk API `AnchorpulseBleService.startScan()` berubah.**
Rencana hanya menyebut penambahan `isScanningStream`. Saat implementasi
ditemukan bahwa `startScan()` lama ber-return `Stream` sambil menjalankan
`FlutterBluePlus.startScan()` fire-and-forget di dalamnya — kegagalan
memulai scan (mis. adapter mati) menjadi unhandled async error DAN
meninggalkan `status == scanning` selamanya, melanggar AC2. Solusi:
`startScan()` menjadi `Future<void>` (bisa ditangkap try/catch), hasil scan
dipindah ke getter `scanResults` terpisah. Satu-satunya pemanggil
(ConnectionRepository) disesuaikan di commit yang sama.

**0A-C2 — pemetaan `FbpErrorCode` lebih presisi dari rencana.**
Rencana meminta pencocokan tipe `FlutterBluePlusException` lalu string.
Sumber fbp 1.36.8 terpasang ternyata menyediakan `code` terstruktur;
dipakai `FbpErrorCode.timeout/adapterIsOff/deviceIsDisconnected.index`
sebelum jatuh ke pencocokan string. Lebih stabil, semangatnya sama.
