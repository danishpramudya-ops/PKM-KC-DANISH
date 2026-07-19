# Fase 0C — Implementation Plan: Honest Chat

Status: **menunggu persetujuan — belum ada kode yang diubah**

Ruang lingkup: pesan chat berhenti hilang tanpa jejak, dan berhenti mengklaim
terkirim padahal belum tentu. Tidak ada perubahan protokol, tidak ada perubahan
tata letak.

Batasan keras sama persis dengan Fase 0A — lihat `docs/fase-0-handoff.md` §4.

---

## 1. Temuan verifikasi yang mengubah rencana

Rencana awal berasumsi pesan chat sering hilang karena LoRa lossy. **Pembacaan
firmware membuktikan asumsi itu salah, dan menemukan masalah yang lebih serius.**

`point_rescue_SAR.ino:226-240` — `originateChat()`:

```cpp
String payload = buildChatPacket(msg);
enqueueTx(payload, priorityFor(PKT_CHAT));

// HP pengirim juga ikut lihat pesannya sendiri di UI chat (echo lokal)
bleNotifyMeshPacket(payload);
bleNotifyChat(NODE_ID, NODE_ID / 1000, msg.c_str());
```

Echo dikirim balik ke HP **segera setelah pesan dimasukkan ke antrean TX** —
bukan setelah LoRa berhasil menyiarkannya, dan jelas bukan setelah ada node
lain yang menerimanya.

**Dua konsekuensi:**

**1. Pesan lebih jarang hilang dari dugaan.** Echo bersifat lokal dan hampir
pasti datang selama BLE tersambung. Pesan hanya benar-benar lenyap kalau
penulisan BLE gagal atau notifikasi terjatuh. Masalahnya lebih sempit dari
perkiraan awal — tapi tetap nyata, dan saat ini **sepenuhnya tak terlihat**
oleh pengguna.

**2. Masalah yang lebih besar: "terkirim" akan jadi kebohongan.** Kalau 0C
menandai pesan "Terkirim" berdasarkan echo, aplikasi mengklaim pesan sampai ke
tim, padahal yang terbukti hanyalah *node SAR di ranselku sudah menerimanya*.
Pesan itu masih bisa gagal disiarkan, atau disiarkan tanpa ada yang mendengar.

Protokol **tidak punya ACK sama sekali** — tidak ada konfirmasi hop-by-hop
maupun ujung-ke-ujung. Itu butir B4 di `saran-tindaklanjut.txt` dan menuntut
perubahan format paket, yang dilarang di Fase 0.

**Maka 0C tidak boleh menampilkan "Terkirim".** Yang jujur adalah menyatakan
pesan sudah diserahkan ke node, dan berhenti di situ.

Ini contoh langsung prinsip nomor 1 mengalahkan kenyamanan: tanda centang
"terkirim" akan terasa lebih rapi dan lebih mirip WhatsApp, tapi ia berbohong
tentang hal yang menyangkut nyawa.

---

## 2. Ringkasan perubahan

| # | Perubahan | Berkas | Ukuran |
|---|---|---|---|
| C-1 | Konstanta terpusat | `ble_constants` | Kecil |
| C-2 | Batas 100 **byte**, bukan 100 karakter | `chat_screen`, `chat_repository` | Sedang |
| C-3 | Status pesan yang jujur + rekonsiliasi echo | `chat_message`, `chat_repository` | Besar |
| C-4 | Tampilkan status di widget teks yang sudah ada | `chat_screen` | Kecil |

Urutan commit: `C-1 → C-2 → C-3 → C-4`

---

## 3. C-2 — Batas 100 byte, bukan 100 karakter

### Tujuan
Batas yang ditegakkan aplikasi harus sama dengan batas yang ditegakkan firmware.

### Mengapa diperlukan
`chat_screen.dart:127` memakai `maxLength: 100`, yang membatasi **karakter**.
`point_rescue_SAR.ino:46` mendefinisikan `CHAT_MSG_MAX_LEN 100`, dan
`originateChat()` menegakkannya dengan `msg.length()` — pada Arduino `String`,
itu menghitung **byte**.

Untuk teks ASCII keduanya sama. Untuk yang lain tidak: karakter beraksen
memakan 2 byte dalam UTF-8, dan emoji 4 byte.

`originateChat()` **memotong, bukan menolak**:
```cpp
if (msg.length() > CHAT_MSG_MAX_LEN) msg = msg.substring(0, CHAT_MSG_MAX_LEN);
```

Pemotongan dilakukan pada batas byte, bukan batas karakter — sehingga bisa
memutus satu karakter multi-byte di tengah dan menghasilkan UTF-8 tidak valid.
Aplikasi lalu membacanya dengan `utf8.decode(value, allowMalformed: true)`
(`anchorpulse_ble_service.dart:118`), yang menggantinya dengan karakter
pengganti. Relawan melihat pesannya sendiri kembali dalam keadaan rusak di
ujung.

### Berkas & simbol
- `mobile/lib/presentation/screens/chat_screen.dart` → `TextField`
- `mobile/lib/data/repositories/chat_repository.dart` → `send()`
- `mobile/lib/core/constants/ble_constants.dart` → `chatMaxBytes`

### Alur lama vs baru
**Lama:** 100 karakter diizinkan; firmware memotong pada byte ke-100; hasilnya
bisa rusak.
**Baru:** `TextInputFormatter` khusus menolak masukan yang membuat panjang
UTF-8 melewati 100 byte. `ChatRepository.send()` memvalidasi ulang sebagai
lapis kedua. Firmware tidak pernah lagi perlu memotong.

### Keputusan tentang penghitung karakter

`maxLength: 100` bukan hanya batas — ia juga yang memunculkan penghitung
"0/100" di bawah kolom masukan, dan penghitung itulah alasan adanya tambalan
`margin: EdgeInsets.only(bottom: 24)` di `chat_screen.dart:130`.

Menghapus `maxLength` akan menghilangkan penghitung dan **mengubah tata letak** —
dilarang di Fase 0.

**Maka:** `maxLength: 100` dipertahankan apa adanya demi penghitung, dan
formatter byte ditambahkan di sampingnya. Untuk teks ASCII tidak ada perubahan
sama sekali. Untuk teks multi-byte, masukan berhenti lebih awal sementara
penghitung masih menunjukkan angka karakter.

Ini **kompromi yang diketahui**: penghitung jadi sedikit menyesatkan pada teks
multi-byte, tetapi datanya tidak pernah rusak lagi. Penghitung byte yang benar
adalah butir wajib Fase 2, bersamaan dengan penghapusan tambalan `bottom: 24`.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Formatter menolak di tengah komposisi IME | Hitung panjang byte dari nilai final, jangan blokir teks komposisi |
| Penghitung membingungkan pada emoji | Diterima dan didokumentasikan; diperbaiki di Fase 2 |
| Tempel (paste) teks panjang | Formatter memotong pada batas **karakter** terakhir yang masih muat — jangan pernah memotong di tengah rune |

---

## 4. C-3 — Status pesan yang jujur

### Tujuan
Pesan yang dikirim harus langsung terlihat, dan kegagalannya tidak boleh senyap.

### Mengapa diperlukan
`chat_repository.dart:47-53`:

```dart
/// Pesan yang terkirim TIDAK ditambah optimistic ke list di sini — firmware
/// node SAR meng-echo balik lewat CHAT_RX ... jadi akan muncul otomatis.
Future<void> send(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  await ble.sendChat(trimmed);
}
```

Dan `chat_screen.dart:31`: `_controller.clear()` dipanggil segera setelah
`send()` berhasil.

Kalau echo tidak pernah datang — penulisan BLE diterima tapi notifikasi
terjatuh, atau koneksi putus tepat setelahnya — maka: teks lenyap dari kolom
masukan, tidak pernah muncul di daftar, dan **tidak ada tanda apa pun**.
Relawan yakin sudah melaporkan sesuatu yang penting, padahal tidak.

### Berkas & simbol
- `mobile/lib/data/models/chat_message.dart` → tambah `ChatMessageStatus`,
  `localId`, jadikan `status` dapat diubah
- `mobile/lib/data/repositories/chat_repository.dart` → `send()`, `_onRawChat()`
- `mobile/lib/core/constants/ble_constants.dart` → `chatEchoTimeout`

### Status dan maknanya

**Penamaan di sini penting dan disengaja.**

| Status | Arti sebenarnya | Yang boleh ditampilkan |
|---|---|---|
| `sending` | Ditulis ke CHAT_TX, menunggu echo lokal | "mengirim…" |
| `handedToNode` | Echo diterima. Node SAR sudah menerima dan mengantrekan ke LoRa. **Bukan bukti sampai ke tim.** | "diteruskan ke node" |
| `failed` | Penulisan BLE melempar, atau echo tidak datang dalam batas waktu | "gagal terkirim" |

**Dilarang** memakai kata "Terkirim", "Delivered", atau ikon centang. Semuanya
menyiratkan penerimaan ujung-ke-ujung yang tidak bisa dibuktikan protokol saat
ini. Kalau ACK ditambahkan nanti (butir B4 saran-tindaklanjut, perubahan
protokol), status `delivered` yang sesungguhnya baru boleh ada.

### Alur lama vs baru

**Lama**
```
kirim → tulis BLE → (tidak ada apa pun di UI)
                  → echo datang → pesan muncul
                  → echo hilang → SENYAP SELAMANYA
```

**Baru**
```
kirim → sisipkan pesan lokal (status: sending) → langsung terlihat
      → tulis BLE
            gagal → status: failed
            sukses → mulai timer chatEchoTimeout
                  → echo cocok datang → status: handedToNode, timer dibatalkan
                  → timer habis        → status: failed
```

### Mencocokkan echo dengan pesan lokal
Echo berbentuk `{"id", "role", "msg"}` — tidak membawa pengenal apa pun yang
bisa dipetakan ke pesan lokal, dan menambahkannya akan mengubah protokol.

Pencocokan karena itu bersifat heuristik:
1. Kalau `echo.id != myNodeId` → pesan dari node lain. Tambahkan sebagai baru.
2. Kalau `echo.id == myNodeId` → cari pesan `sending` **tertua** yang teksnya
   sama persis. Ketemu → tandai `handedToNode`. Tidak ketemu → tambahkan
   sebagai baru (kemungkinan pesan dari sesi lain atau relay).

**Kasus tepi `myNodeId == null`:** kalau pembacaan NODE_INFO gagal, kepemilikan
tidak bisa ditentukan. Perilaku: tetap cocokkan berdasarkan teks saja. Kurang
tepat, tapi lebih baik daripada menandai gagal padahal berhasil. Fase 0A (C4)
membuat `myNodeId` jauh lebih andal karena kini ikut dipulihkan setelah sambung
ulang.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Dua pesan identik berturut-turut saling tertukar | Cocokkan yang tertua lebih dulu; hasil akhirnya sama karena teksnya identik |
| Echo datang setelah batas waktu | Status sudah `failed` tapi pesan tetap tampil. Dibiarkan `failed` — lebih baik terlalu berhati-hati daripada terlalu percaya diri. Batas waktu 10 detik jauh di atas latensi BLE lokal. |
| Duplikat: pesan lokal + echo tercatat dua kali | Justru ini yang dicegah pencocokan. Diuji di P4. |
| Timer bocor saat repository dibuang | Kumpulkan timer di `Map<String, Timer>`, batalkan semua di `dispose()` dan `reset()` |

### Alternatif yang ditolak
**Tetap menunggu echo, hanya tambahkan indikator kegagalan.**
*Ditolak:* pesan tetap tidak terlihat selama beberapa ratus milidetik pertama,
dan kolom masukan sudah terlanjur dikosongkan. Sisipan optimistis adalah yang
membuat pesan tidak pernah lenyap.

**Beri pesan pengenal unik lewat protokol agar pencocokan pasti.**
*Ditolak:* perubahan protokol, dilarang di Fase 0. Dicatat sebagai perbaikan
sah kalau ACK jadi ditambahkan.

---

## 5. C-4 — Menampilkan status tanpa mengubah tata letak

### Tujuan
Status terlihat tanpa menambah widget atau mengubah tata letak apa pun.

### Cara
`chat_screen.dart:96-102` sudah punya sebuah `Text` untuk jam:

```dart
Text(formatClock(m.timestamp), style: TextStyle(fontSize: 10, ...))
```

0C hanya mengubah **isi string** widget itu untuk pesan milik sendiri:

| Status | Teks |
|---|---|
| `sending` | `10:42:03 · mengirim…` |
| `handedToNode` | `10:42:03` (tanpa tambahan — keadaan normal) |
| `failed` | `10:42:03 · gagal terkirim` |

Nol widget baru, nol perubahan tata letak, nol perubahan warna, nol ikon.
Kategorinya sama persis dengan C7 di Fase 0A: isi teks di widget yang sudah ada.

Aksi "kirim ulang" adalah UI dan masuk **Fase 2**.

### Kenapa `handedToNode` tidak diberi teks
Menambahkan "diteruskan ke node" pada setiap pesan yang berhasil akan
memenuhi layar dengan hal yang tidak dibutuhkan. Keadaan normal tetap sunyi;
hanya penyimpangan yang bersuara. Ini prinsip "Terbaca dalam tiga detik".

---

## 6. C-1 — Konstanta terpusat

```dart
static const int      chatMaxBytes    = 100;   // = CHAT_MSG_MAX_LEN firmware
static const Duration chatEchoTimeout = Duration(seconds: 10);
```

`chatMaxBytes` **wajib** sama dengan `CHAT_MSG_MAX_LEN` di ketiga firmware.
Tambahkan komentar yang menyebut berkas firmware-nya, mengikuti pola yang
sudah dipakai `BleConstants`.

---

## 7. Dampak lintas komponen

| Komponen | Dampak |
|---|---|
| Firmware | **Nihil.** Perilaku pemotongan tidak lagi terpicu karena aplikasi mencegahnya lebih dulu. |
| Protokol / JSON | **Nihil.** |
| Dashboard | **Nihil.** Chat hanya ada di mobile. |
| Fase 0A | `myNodeId` yang diperbaiki C4 membuat pencocokan echo jauh lebih andal. Saling menguatkan, tidak bertabrakan. |
| Fase 0B | Tidak ada tumpang tindih berkas. |

---

## 8. Pengujian

### Otomatis
`test/core/utils/utf8_limit_test.dart` — fungsi murni pembatas byte:
ASCII tepat 100 byte, teks beraksen, emoji, tempel teks panjang, dan bukti
bahwa pemotongan **tidak pernah** membelah rune.

Fungsi pembatas itu **harus ditulis sebagai fungsi murni** agar bisa diuji.
Formatter membungkusnya.

### Manual — butuh 1 HP, 2 node (SAR + satu lainnya)

| # | Skenario | Langkah | Hasil yang diharapkan |
|---|---|---|---|
| P1 | **Kirim normal** | Ketik "test", kirim. | Muncul **seketika** di kanan dengan "mengirim…", lalu tambahannya hilang dalam <1 detik. |
| P2 | **Batas ASCII** | Ketik 100 huruf 'a'. | Huruf ke-101 ditolak. Terkirim utuh. |
| P3 | **Batas emoji** | Tempel 40 emoji. | Masukan berhenti sekitar 25 emoji (4 byte masing-masing). Pesan tiba **tanpa karakter rusak**. Ini bug utama C-2. |
| P4 | **Tanpa duplikat** | Kirim 5 pesan berturut-turut. | Tepat 5 pesan di daftar. Tidak ada yang muncul dua kali. |
| P5 | **Pesan identik** | Kirim "ok" tiga kali. | Tiga pesan, semuanya keluar dari status "mengirim…". |
| P6 | **Kegagalan terlihat** | Matikan node SAR tepat setelah menekan kirim. | Pesan tetap terlihat dan menjadi "gagal terkirim" dalam 10 detik. **Tidak pernah lenyap senyap.** Ini bug utama C-3. |
| P7 | **Pesan dari node lain** | Kirim chat dari node lain. | Muncul di **kiri** dengan label pengirim. Tanpa teks status. |
| P8 | **Setelah sambung ulang** | Putuskan, biarkan 0A menyambung ulang, kirim pesan. | Muncul di **kanan**. Memverifikasi 0A-C4 dan 0C bersama-sama. |
| P9 | **Tanpa "Terkirim"** | Tinjau semua string yang tampil. | Tidak ada kata "Terkirim"/"Delivered", tidak ada ikon centang. |

---

## 9. Rollback

Empat commit terpisah. `C-4` bergantung pada `C-3`. `C-2` dan `C-1` bebas.
Mengembalikan `C-3` mengembalikan perilaku menunggu-echo yang lama.

---

## 10. Acceptance Criteria

- [ ] AC-C1 — Pesan muncul seketika saat dikirim (P1)
- [ ] AC-C2 — Batas ditegakkan dalam **byte**, bukan karakter (P2, P3)
- [ ] AC-C3 — Pemotongan tidak pernah membelah rune (uji otomatis)
- [ ] AC-C4 — Tidak ada pesan duplikat (P4, P5)
- [ ] AC-C5 — Pesan gagal selalu terlihat, tidak pernah senyap (P6)
- [ ] AC-C6 — Pesan node lain tetap di kiri tanpa status (P7)
- [ ] AC-C7 — **Tidak ada** string "Terkirim"/"Delivered" atau ikon centang (P9)
- [ ] AC-C8 — Semua timer dibatalkan di `dispose()` dan `reset()` (tinjauan kode)
- [ ] AC-C9 — Nol perubahan tata letak; hanya isi teks yang berubah
- [ ] AC-C10 — Nol perubahan di `firmware/`, `dashboard/`, `docs/protokol-paket.md`
- [ ] AC-C11 — `flutter analyze` bersih
- [ ] AC-C12 — Uji otomatis pembatas byte lulus
