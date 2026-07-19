# Fase 0A — Implementation Plan: Connection Reliability

Status: **menunggu persetujuan — belum ada kode yang diubah**

Ruang lingkup: keandalan koneksi BLE antara aplikasi mobile dan node SAR.
Tidak ada perubahan protokol, tidak ada perubahan tampilan.

---

## 0. Aturan yang mengikat fase ini

Diambil langsung dari arahan, dan diperlakukan sebagai batasan keras:

| Aturan | Status di rencana ini |
|---|---|
| Jangan ubah protokol LoRa/BLE | ✅ Nol perubahan. Tidak ada UUID, tipe paket, atau field baru. |
| Jangan ubah struktur JSON dashboard | ✅ Nol perubahan. Tidak ada berkas dashboard yang disentuh. |
| Jangan ubah UI di Fase 0 | ⚠️ Lihat §1.1 — ada satu ketegangan jujur yang harus kamu putuskan. |
| Jangan hapus kompatibilitas firmware lama | ✅ Nol perubahan. Aplikasi tetap bekerja dengan firmware yang ada hari ini. |
| Perubahan sekecil mungkin, bisa di-rollback | ✅ 6 berkas, 1 di antaranya baru. Auto-reconnect di balik sakelar fitur. |

## 0.1 Ketegangan yang harus disampaikan sejujurnya

Butir P0 nomor 2 berbunyi: *"koneksi putus harus terasa seperti putus"* —
getar, suara, banner persisten. **Itu pekerjaan UI.**

Aturanmu melarang perubahan UI di Fase 0. Keduanya tidak bisa dipenuhi sekaligus.

**Cara saya menyelesaikannya:** Fase 0A memperbaiki seluruh *logika* — deteksi
putus, sambung ulang otomatis, dan status yang jujur — lalu **menyediakan** state
itu untuk dibaca UI. Widget yang sudah ada hanya menampilkan teks yang lebih
benar. Tidak ada widget baru, tidak ada warna baru, tidak ada tata letak baru.

**Akibatnya:** setelah 0A, koneksi yang putus akan **sembuh sendiri secara
otomatis**, dan bar status akan mengatakan yang sebenarnya. Tapi getar, alarm,
dan banner yang tak bisa diabaikan **belum ada** — itu masuk Fase 2 saat UI
memang boleh disentuh.

Jadi P0 #2 hanya **tertutup sebagian** di 0A. Saya lebih memilih menyatakan ini
terang-terangan daripada mengklaim fase ini selesai padahal relawan masih bisa
melewatkan koneksi yang putus.

Kalau kamu ingin penutupan penuh sekarang, ada alternatif di §9 (Keputusan Terbuka).

---

## 1. Ringkasan perubahan

Tujuh perubahan, disusun agar tiap satuannya bisa direview dan dibalik sendiri-sendiri.

| # | Perubahan | Berkas | Ukuran |
|---|---|---|---|
| C1 | Siklus hidup scan tidak lagi buntu | `connection_repository`, `anchorpulse_ble_service` | Sedang |
| C2 | Kamus kegagalan menggantikan `e.toString()` | **baru:** `connection_failure.dart` | Sedang |
| C3 | Pisahkan putus sengaja vs tak sengaja + sambung ulang otomatis | `connection_repository` | Besar |
| C4 | `myNodeId` dipulihkan setelah sambung ulang | `app.dart`, `connect_screen` | Kecil |
| C5 | Pembersihan state saat `connect()` gagal separuh jalan | `anchorpulse_ble_service` | Kecil |
| C6 | Konstanta waktu terpusat (hapus angka ajaib) | `ble_constants` | Kecil |
| C7 | Perkabelan teks di UI yang sudah ada | `connect_screen`, `connection_status_bar` | Kecil |

---

## 2. C1 — Siklus hidup scan tidak lagi buntu

### Tujuan
Status koneksi harus kembali ke keadaan yang bisa dipakai ketika pemindaian
berakhir, dengan cara apa pun ia berakhir.

### Mengapa diperlukan
Ini bug yang mengunci aplikasi. Rantainya:

1. `anchorpulse_ble_service.dart:70` — `startScan()` memakai
   `timeout: Duration(seconds: 15)`. Bluetooth berhenti memindai setelah 15 detik.
2. `connection_repository.dart:31` — `status` diset `scanning`. **Tidak ada satu
   baris pun di seluruh codebase yang mengembalikannya ke `idle`** saat scan
   selesai tanpa hasil.
3. `connect_screen.dart:224` — `onPressed: (_requestingPermission || isScanning) ? null : _startScan`

Akibatnya tombol "Mulai Pindai" jadi abu-abu **selamanya**, spinner berputar
selamanya, teks tetap "Mencari Node..." padahal pemindaian sudah lama berhenti.
Satu-satunya jalan keluar bagi relawan adalah menutup paksa aplikasi.

### Berkas & simbol
- `mobile/lib/data/ble/anchorpulse_ble_service.dart` → tambah getter
  `Stream<bool> get isScanningStream`
- `mobile/lib/data/repositories/connection_repository.dart` → `startScan()`,
  field baru `_isScanningSub`, `dispose()`

### Alur lama vs baru

**Lama**
```
startScan() → status = scanning → FBP timeout 15s → FBP berhenti
                                                  → status TETAP scanning selamanya
```

**Baru**
```
startScan() → status = scanning → berlangganan FlutterBluePlus.isScanning
                                → FBP berhenti (timeout / stopScan / error)
                                → isScanning memancarkan false
                                → ada hasil?  ya → status = idle (daftar tampil)
                                              tidak → status = failed(nodeTidakDitemukan)
```

### Pendekatan yang saya pilih, dan alternatif yang saya tolak

**Dipilih: berlangganan `FlutterBluePlus.isScanning`.**
Pustaka sudah punya satu sumber kebenaran soal "apakah sedang memindai" —
`anchorpulse_ble_service.dart:75` bahkan sudah memakai `isScanningNow`.
Berlangganan streamnya membuat status kita mustahil melenceng dari keadaan
sebenarnya.

**Ditolak: `Timer(Duration(seconds: 15))` di sisi Dart.**
Menduplikasi durasi timeout di dua tempat. Kalau salah satu berubah, keduanya
diam-diam tidak sinkron. Timer juga tidak tahu kalau scan berhenti lebih awal
karena error atau `stopScan()` manual — jadi status tetap bisa buntu, hanya
lebih jarang. Ini memperbaiki gejala, bukan penyebab.

**Ditolak: reset status di dalam `build()` UI.**
Menaruh logika state di lapisan tampilan. Membuat mustahil diuji dan pasti
terulang di layar berikutnya.

### Risiko
| Risiko | Mitigasi |
|---|---|
| `isScanning` memancarkan `false` sekali saat awal sebelum scan benar-benar mulai, sehingga langsung dianggap selesai | Abaikan emisi `false` sampai `true` pertama sudah terlihat (jaga bendera `_scanHasStarted`) |
| Langganan bocor kalau `startScan` dipanggil berulang | Batalkan langganan lama di awal `startScan()`, dan di `dispose()` |
| Scan selesai saat pengguna sudah pindah layar | Pengecekan `status == scanning` sebelum menulis status baru |

### Dampak lintas komponen
Firmware: **nihil**. Dashboard: **nihil**. Protokol: **nihil**.
Fitur mobile lain: **nihil** — `startScan` hanya dipanggil dari `connect_screen`.

---

## 3. C2 — Kamus kegagalan menggantikan `e.toString()`

### Tujuan
Setiap kegagalan koneksi punya sebab dalam bahasa manusia, akibat yang
dijelaskan, dan satu aksi yang bisa dilakukan.

### Mengapa diperlukan
`connection_repository.dart:88` menyimpan `errorMessage = e.toString()`.
`connect_screen.dart:113` menampilkannya mentah-mentah. Yang dibaca relawan:

> `Gagal terhubung: PlatformException(connect, device is not connected, null, null)`

Ini kebalikan persis dari "bahasa yang mudah dipahami".

### Berkas & simbol
- **BARU** `mobile/lib/data/models/connection_failure.dart`
  - `enum ConnectionFailureKind`
  - `class ConnectionFailure` — `kind`, `message`, `actionLabel`, `technicalDetail`
  - `factory ConnectionFailure.fromException(Object e)`
- `mobile/lib/data/repositories/connection_repository.dart` — ganti
  `String? errorMessage` menjadi `ConnectionFailure? failure`

### Kamusnya

| Kind | Pesan ke relawan | Aksi |
|---|---|---|
| `bluetoothOff` | "Bluetooth belum menyala." | Nyalakan Bluetooth |
| `permissionDenied` | "POINTRESCUE perlu izin Perangkat di Sekitar untuk menemukan node." | Buka Pengaturan |
| `nodeNotFound` | "Node tidak ditemukan. Pastikan node menyala dan jaraknya di bawah 10 meter." | Cari Lagi |
| `connectTimeout` | "Node tidak merespons. Dekatkan HP ke node, lalu coba lagi." | Coba Lagi |
| `notPointrescueNode` | "Perangkat ini bukan node POINTRESCUE, atau firmware-nya belum mendukung aplikasi." | Pilih Node Lain |
| `connectionLost` | "Koneksi ke node terputus." | Sambungkan Ulang |
| `unknown` | "Terjadi gangguan koneksi." | Coba Lagi |

`technicalDetail` **tetap menyimpan** `e.toString()` — tidak dibuang, hanya
tidak ditampilkan. Nantinya dikonsumsi Live Log Viewer di Fase 6.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Salah mengklasifikasikan exception → pesan menyesatkan | Cocokkan pola secara konservatif; apa pun yang tak dikenal jatuh ke `unknown` dengan pesan netral, bukan tebakan |
| Teks exception `flutter_blue_plus` berubah saat pustaka di-upgrade | Cocokkan berdasarkan tipe (`FlutterBluePlusException`, `TimeoutException`, `StateError`) lebih dulu, string hanya sebagai lapis kedua |

### Dampak lintas komponen
Nihil di luar mobile. Murni pemetaan sisi klien.

### Catatan i18n
Teks di kamus ini ditulis dalam Bahasa Indonesia sebagai literal string.
Ketika infrastruktur i18n masuk di Fase 1, kamus ini adalah **satu-satunya
tempat** yang perlu disentuh untuk seluruh teks kegagalan koneksi — itu
sebabnya ia dipusatkan sejak sekarang.

---

## 4. C3 — Putus sengaja vs tak sengaja, dan sambung ulang otomatis

### Tujuan
Koneksi yang putus tanpa diminta harus mencoba pulih sendiri. Koneksi yang
diputus pengguna harus tetap putus.

### Mengapa diperlukan
Dua masalah bertumpuk di sini.

**Pertama, tidak ada sambung ulang sama sekali.**
`connection_repository.dart:76-81` mendeteksi putusnya koneksi lalu hanya
mengubah variabel. Relawan bisa berjalan 40 menit meyakini timnya terpantau,
padahal aplikasinya sudah buta.

**Kedua — dan ini baru saya sadari saat verifikasi:**
`disconnect()` di baris 98 menulis `status = disconnected`, **dan** pendengar
`_connStateSub` di baris 78 juga menulis `status = disconnected`. Keduanya
menyala saat pengguna menekan tombol putus. Artinya begitu sambung ulang
otomatis ditambahkan **tanpa** membedakan keduanya, aplikasi akan **langsung
menyambung ulang setelah pengguna sengaja memutus** — melawan perintah
penggunanya sendiri.

Ini kelas bug yang lolos dari review dan baru ketahuan di lapangan. Harus
diselesaikan di perubahan yang sama.

### Berkas & simbol
`mobile/lib/data/repositories/connection_repository.dart`:
- Tambah nilai enum: `ConnectionStatus.reconnecting`
- Field baru: `bool _userInitiatedDisconnect`, `int _reconnectAttempt`,
  `Timer? _reconnectTimer`, `BluetoothDevice? _lastDevice`
- Method baru: `_scheduleReconnect()`, `_cancelReconnect()`
- Ubah: `connect()`, `disconnect()`, pendengar `_connStateSub`, `dispose()`

### Alur lama vs baru

**Lama**
```
putus (sebab apa pun) → status = disconnected → BERHENTI
```

**Baru**
```
putus → apakah diminta pengguna?
         ya  → status = disconnected, berhenti, jangan sambung ulang
         tidak → status = reconnecting
               → coba ulang dengan jeda bertambah: 1s, 2s, 4s, 8s, 16s, 30s, 30s...
               → berhasil → status = connected, hitungan direset
               → pengguna memutus manual → batalkan timer, berhenti
```

### Kebijakan mundur (backoff)
`1s → 2s → 4s → 8s → 16s → 30s`, lalu tetap 30s. **Tanpa batas percobaan**
selama aplikasi di depan.

Alasan tanpa batas: relawan yang keluar dari jangkauan lalu kembali harus
tersambung lagi **tanpa menyentuh apa pun**. Batas percobaan akan membuat
aplikasi menyerah diam-diam — persis mode kegagalan yang sedang kita hapus.

Batas atas 30 detik menjaga konsumsi baterai tetap wajar. Perilaku saat
aplikasi di latar belakang ditangani Fase 4 (foreground service); untuk
sekarang Android akan menjeda timer secara alami saat aplikasi tidak aktif.

### Sakelar fitur
```dart
static const bool autoReconnectEnabled = true;
```
Di `ble_constants.dart`. Kalau sambung ulang ternyata bermasalah di perangkat
tertentu, satu baris ini mengembalikan perilaku lama tanpa membalik commit.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Sambung ulang melawan pemutusan sengaja | Bendera `_userInitiatedDisconnect`, diset **sebelum** `ble.disconnect()` dipanggil |
| Beberapa timer sambung ulang berjalan bersamaan | `_cancelReconnect()` dipanggil di awal setiap penjadwalan dan di `dispose()` |
| Sambung ulang tak berujung menguras baterai | Batas atas jeda 30 detik |
| `_lastDevice` menunjuk perangkat yang sudah tidak ada | `connect()` gagal normal → `ConnectionFailure` → jadwalkan lagi |
| Sambung ulang saat pengguna sedang di layar pilih node | Cek status sebelum menulis; `startScan()` membatalkan sambung ulang |
| Kebocoran `_connStateSub` saat sambung ulang berulang | Batalkan langganan lama di awal `connect()` |

### Dampak lintas komponen
Firmware: **nihil** — sambung ulang memakai `device.connect()` yang sudah ada.
Node SAR tidak bisa membedakan sambungan pertama dari sambungan ulang.
Dashboard: **nihil**. Protokol: **nihil**.

Mobile: `ChatRepository` terpengaruh — lihat C4. `NodeRepository` tidak
terpengaruh; ia mendengarkan stream paket, dan stream itu hidup kembali
sendiri setelah sambung ulang.

### Alternatif yang dipertimbangkan

**`device.connect(autoConnect: true)` bawaan flutter_blue_plus.**
Pustaka menyediakan sambung ulang otomatis tingkat sistem.
*Kelebihan:* jauh lebih sedikit kode, ditangani OS, hemat baterai.
*Kekurangan:* pada `flutter_blue_plus`, `autoConnect` diketahui punya batasan —
antara lain tidak dapat dikombinasikan dengan permintaan `mtu:`, sedangkan
`anchorpulse_ble_service.dart:96` **wajib** meminta MTU 247 agar paket JSON
tidak terpotong. Perilakunya juga berbeda antara Android dan iOS dan sulit
diamati, sehingga status "sedang menyambung ulang" jadi sulit ditampilkan
dengan jujur — melanggar prinsip nomor 1.

*Rekomendasi:* pakai sambung ulang manual. Tapi batasan MTU itu perlu
**diverifikasi saat implementasi**, bukan dipercaya begitu saja dari ingatan
saya. Kalau ternyata keduanya bisa digabung, opsi bawaan pustaka layak
ditinjau ulang.

---

## 5. C4 — `myNodeId` dipulihkan setelah sambung ulang

### Tujuan
Setelah sambung ulang otomatis, chat tetap tahu pesan mana milik sendiri.

### Mengapa diperlukan
Ditemukan saat verifikasi. `ChatRepository.myNodeId` **hanya** diisi di satu
tempat di seluruh codebase — `connect_screen.dart:106`, di dalam alur ketuk manual:

```dart
context.read<ChatRepository>().myNodeId = connection.myNodeId;
```

Sambung ulang otomatis tidak melewati layar itu. Jadi setelah sambung ulang,
`ChatRepository.myNodeId` tetap bernilai lama atau `null`, dan
`chat_repository.dart:38` (`isMine: myNodeId != null && id == myNodeId`) akan
salah menilai. Gejalanya: pesan relawan sendiri muncul di sisi kiri seolah
dikirim orang lain.

Ini bug yang **diciptakan oleh C3** kalau tidak ditangani bersamaan.

### Berkas & simbol
- `mobile/lib/presentation/app.dart` — `_AnchorpulseAppState.initState()`
- `mobile/lib/presentation/screens/connect_screen.dart` — hapus baris 106

### Alur lama vs baru
**Lama:** layar menetapkan nilai ke repository lain saat ketukan berhasil.
**Baru:** `app.dart` memasang satu pendengar sekali seumur hidup aplikasi:

```dart
_connectionRepository.addListener(() {
  _chatRepository.myNodeId = _connectionRepository.myNodeId;
});
```

Berlaku untuk sambungan pertama maupun sambung ulang, tanpa layar perlu tahu.

### Alternatif yang ditolak
**Memberi `ChatRepository` ke `ConnectionRepository`.** Membuat dua repository
saling tahu satu sama lain. Perkabelan adalah tugas lapisan komposisi
(`app.dart`), bukan tugas repository.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Pendengar terpanggil sangat sering (tiap `notifyListeners`) | Penetapannya hanya assignment `int?` — biayanya nol |
| Pendengar tidak dilepas | `app.dart` memiliki kedua objek sepanjang umur aplikasi; sudah ada `dispose()` |

---

## 6. C5 — Pembersihan state saat `connect()` gagal separuh jalan

### Tujuan
Kegagalan di tengah proses sambung tidak boleh meninggalkan service dalam
keadaan setengah tersambung.

### Mengapa diperlukan
`anchorpulse_ble_service.dart:99` menetapkan `_device = device` **segera
setelah** `device.connect()` berhasil. Tapi `discoverServices()` di baris 101
dan pencarian service di baris 102 **bisa melempar exception**.

Kalau itu terjadi: `_device` tetap terisi, sehingga `isConnected` mengembalikan
`true` padahal tidak ada characteristic yang terpasang. Percobaan sambung ulang
berikutnya bekerja di atas state kotor.

Tanpa sambung ulang otomatis, bug ini jarang terlihat. **Dengan** C3, ia akan
sering terjadi.

### Berkas & simbol
`mobile/lib/data/ble/anchorpulse_ble_service.dart` → `connect()`

### Alur lama vs baru
**Lama:** `_device` diset lebih awal, tidak ada penanganan bila langkah
berikutnya gagal.
**Baru:** bungkus langkah setelah `device.connect()` dalam `try`; pada
kegagalan, bersihkan semua field dan putuskan perangkat sebelum melempar ulang.
`_device` baru ditetapkan setelah seluruh proses berhasil.

### Risiko
| Risiko | Mitigasi |
|---|---|
| `disconnect()` di dalam penanganan error ikut melempar | Bungkus pembersihan dalam `try/catch` kosong — kegagalan pembersihan tidak boleh menutupi error asli |
| Exception asli tertelan | Selalu `rethrow` setelah pembersihan |

### Dampak lintas komponen
Nihil. Murni internal.

---

## 7. C6 — Konstanta waktu terpusat

### Tujuan
Menghapus angka ajaib yang tersebar; `CLAUDE.md` melarangnya secara eksplisit.

### Berkas & simbol
`mobile/lib/core/constants/ble_constants.dart`:
```dart
static const Duration scanTimeout        = Duration(seconds: 15);
static const Duration connectTimeout     = Duration(seconds: 12);
static const Duration reconnectInitial   = Duration(seconds: 1);
static const Duration reconnectMax       = Duration(seconds: 30);
static const bool     autoReconnectEnabled = true;
```

Nilai `15` dan `12` **tidak diubah** — hanya dipindahkan dari tempatnya
sekarang (`anchorpulse_ble_service.dart:70` dan `:96`). Perilaku identik.

### Risiko
Nihil. Pemindahan murni. Terlihat jelas di diff.

---

## 8. C7 — Perkabelan teks di UI yang sudah ada

### Tujuan
Widget yang ada menampilkan state baru yang jujur. **Tanpa perubahan visual.**

### Yang berubah
- `connect_screen.dart:110-118` — tampilkan `failure.message`, bukan `e.toString()`
- `connect_screen.dart:133` — `isScanning` sekarang menjadi `false` dengan benar
  saat scan berakhir, jadi tombol hidup kembali. **Tidak ada perubahan kode di
  sini** — bug-nya sembuh sendiri karena C1. Dicatat agar reviewer paham.
- `connection_status_bar.dart:14-18` — tambah teks untuk status `reconnecting`:
  "Menyambungkan ulang… (percobaan N)"

### Yang TIDAK berubah
Tanpa pengecualian: tata letak, warna, ukuran huruf, padding, ikon, animasi,
teks tombol. Termasuk animasi denyut 1500ms di `connect_screen.dart:31` —
melanggar aturan animasi yang sudah disepakati, tapi menghapusnya adalah
perubahan UI. **Dijadwalkan untuk Fase 2.**

### ⚠️ Dampak ke test yang sudah ada
`test/widget_test.dart` mengharapkan `find.text('Mulai Pindai')`. Rencana ini
**tidak mengubah teks tombol**, jadi test itu tetap lulus. Kalau saat
implementasi ternyata teks perlu berubah, test harus diperbarui di commit yang
sama — jangan sampai gagal senyap.

---

## 9. Keputusan yang sudah diambil

Alternatif tetap didokumentasikan agar alasannya bisa ditinjau ulang.

### Q1 — Apakah P0 #2 ditutup penuh sekarang atau di Fase 2?

> **✅ Keputusan: Opsi A — tunda ke Fase 2.**
> 0A murni logika. Aturan "tanpa perubahan UI" dipertahankan.
> **Konsekuensi yang harus dicatat:** P0 #2 hanya tertutup **sebagian** setelah
> 0A. Koneksi yang putus akan sembuh sendiri secara otomatis, tapi relawan
> dengan HP di saku belum akan menyadarinya. Penutupan penuh (getar + alarm +
> banner persisten) menjadi **butir wajib Fase 2** dan tidak boleh hilang dari
> daftar.

**Opsi A — Sesuai rencana (logika sekarang, peringatan di Fase 2)**
Sambung ulang bekerja, bar status jujur, tapi belum ada getar/alarm.
*Kelebihan:* mematuhi aturan "tanpa perubahan UI"; diff kecil dan mudah direview.
*Kekurangan:* relawan dengan HP di saku masih bisa melewatkan koneksi yang
putus sampai Fase 2. Itu justru kondisi pemakaian paling umum.

**Opsi B — Tambahkan getar + suara sekarang, tetap tanpa perubahan visual**
Butuh satu paket baru untuk getar. Nol widget baru, nol perubahan tata letak.
*Kelebihan:* P0 #2 benar-benar tertutup; getar terasa walau HP di saku —
justru di situ nilainya paling besar.
*Kekurangan:* satu dependensi baru; bisa diperdebatkan bahwa getar adalah
"UI"; sedikit memperbesar cakupan 0A.

**Opsi C — Jadikan 0D tersendiri setelah 0C**
*Kelebihan:* 0A tetap murni; peringatan mendapat perhatian dan pengujiannya sendiri.
*Kekurangan:* menunda; menambah satu fase lagi.

*Catatan saya:* Opsi B paling sesuai dengan prinsip "Gagal dengan terang", dan
getar bukan hal visual — ia bekerja justru ketika layar tidak dilihat, yang
merupakan seluruh alasan fitur ini ada. Tapi Opsi A yang paling patuh pada
aturan yang kamu tetapkan, dan aku tidak akan melanggarnya tanpa izinmu.

### Q2 — Seberapa jauh pengujian otomatis di 0A?

> **✅ Keputusan: Opsi A — uji bagian murni saja.**
> Uji otomatis hanya untuk `ConnectionFailure.fromException`. Logika sambung
> ulang diuji manual lewat M1–M11 di perangkat sungguhan.
> **Konsekuensi:** abstraksi perangkat agar `ConnectionRepository` bisa diuji
> penuh menjadi kandidat pekerjaan **Fase 1**, dikerjakan tersendiri, bukan
> diselundupkan ke dalam perbaikan bug.

Kendalanya nyata: `ConnectionRepository.connect()` menerima `BluetoothDevice`,
tipe konkret milik `flutter_blue_plus` yang sangat sulit dipalsukan tanpa
merombak arsitektur.

**Opsi A — Uji hanya bagian murni (`ConnectionFailure.fromException`)**
*Kelebihan:* nol perubahan arsitektur, nol dependensi baru, langsung berguna —
kamus kegagalan justru bagian yang paling mudah salah dan paling jarang diuji
manual. Sisanya diuji manual dengan protokol di §10.
*Kekurangan:* logika sambung ulang tidak tercakup uji otomatis.

**Opsi B — Ekstrak abstraksi perangkat sekarang agar semuanya bisa diuji**
*Kelebihan:* cakupan uji penuh, termasuk backoff dan bendera putus-sengaja.
*Kekurangan:* memperbesar 0A secara signifikan; bertentangan dengan
"perubahan sekecil mungkin"; refactor arsitektur di fase yang seharusnya
hanya memperbaiki bug.

**Opsi C — Tambah mocktail dan palsukan sebisanya**
*Kelebihan:* cakupan lebih luas tanpa refactor produksi.
*Kekurangan:* satu dev-dependency baru; tiruan tipe pihak ketiga cenderung
rapuh dan menguji tiruan, bukan perilaku sebenarnya.

*Catatan saya:* Opsi A. Logika sambung ulang paling meyakinkan diuji dengan
node sungguhan yang dimatikan — dan itu justru pengujian yang benar-benar
membuktikan sesuatu. Abstraksi perangkat pantas dikerjakan, tapi sebagai
pekerjaan tersendiri di Fase 1, bukan diselundupkan ke dalam perbaikan bug.

---

## 10. Cara pengujian

### 10.1 Otomatis
`test/data/models/connection_failure_test.dart` — setiap `kind` dipetakan
dengan benar, exception tak dikenal jatuh ke `unknown`, `technicalDetail`
selalu terisi.

`test/widget_test.dart` yang sudah ada harus tetap lulus tanpa diubah.

### 10.2 Manual — wajib dijalankan sebelum fase dinyatakan selesai

Perlu: 1 HP Android, 1 node SAR ber-firmware BLE.

| # | Skenario | Langkah | Hasil yang diharapkan |
|---|---|---|---|
| M1 | **Scan tanpa hasil** | Matikan semua node. Tekan Mulai Pindai. Tunggu 20 detik. | Setelah ~15 detik spinner berhenti, tombol **hidup kembali**, muncul "Node tidak ditemukan…". Bisa langsung pindai lagi. **Ini bug utama yang diperbaiki.** |
| M2 | **Sambung normal** | Nyalakan node. Pindai. Ketuk node. | Tersambung, masuk HomeShell, bar status hijau. Tidak ada regresi. |
| M3 | **Putus tak sengaja** | Saat tersambung, matikan daya node. | Dalam beberapa detik status jadi "Menyambungkan ulang… (percobaan 1)". Angka percobaan bertambah dengan jeda melebar. |
| M4 | **Pulih otomatis** | Lanjutan M3 — nyalakan node lagi. | Tersambung kembali **tanpa sentuhan apa pun**. Bar status hijau. |
| M5 | **Chat setelah sambung ulang** | Lanjutan M4 — kirim pesan chat. | Pesan muncul di sisi **kanan** (milik sendiri). **Ini memverifikasi C4.** |
| M6 | **Putus sengaja** | Saat tersambung, tekan tombol putus. | Kembali ke ConnectScreen. **TIDAK ada sambung ulang otomatis.** Tetap terputus. **Ini memverifikasi bug yang ditemukan di C3.** |
| M7 | **Bluetooth mati** | Matikan Bluetooth HP. Tekan Mulai Pindai. | Pesan "Bluetooth belum menyala." Tanpa teks exception. |
| M8 | **Izin ditolak** | Cabut izin di pengaturan Android. Buka app. Pindai. | Pesan "POINTRESCUE perlu izin Perangkat di Sekitar…" |
| M9 | **Bukan node POINTRESCUE** | Sambung ke perangkat BLE lain (butuh melewati filter sementara) | Pesan "Perangkat ini bukan node POINTRESCUE…", state bersih, bisa coba lagi. **Memverifikasi C5.** |
| M10 | **Pindai berulang** | Tekan Mulai Pindai 5 kali berturut-turut. | Tidak ada penumpukan langganan, tidak ada duplikat di daftar, tidak ada kebocoran memori. |
| M11 | **Regresi peta & node** | Setelah sambung ulang, periksa daftar node dan peta. | Node tetap masuk, posisi diperbarui. `NodeRepository` tidak terganggu. |

### 10.3 Yang TIDAK diuji di fase ini
Perilaku latar belakang (Fase 4 — foreground service). Peringatan getar/suara
(tergantung ❓Q1). Sambung ulang lintas restart aplikasi (butuh penyimpanan
lokal — Fase 2).

---

## 11. Strategi rollback

**Tingkat 1 — sakelar fitur.** Set `autoReconnectEnabled = false` di
`ble_constants.dart`. Menonaktifkan C3 seluruhnya, mempertahankan C1/C2/C5
yang murni perbaikan bug. Satu baris, tanpa git.

**Tingkat 2 — balikkan satu commit.** Tiap perubahan C1–C7 adalah commit
tersendiri dengan pesan bernomor. C2, C4, C5, C6 saling bebas.
C7 bergantung pada C1 dan C2. C3 bergantung pada C6.

Urutan commit yang disarankan: `C6 → C2 → C1 → C5 → C3 → C4 → C7`.
Tiap commit harus meninggalkan aplikasi dalam keadaan bisa dibangun dan dijalankan.

**Tingkat 3 — balikkan seluruh fase.** Semua perubahan ada di satu branch
(`fase-0a-connection-reliability`). Nol perubahan pada firmware, dashboard,
atau protokol berarti pengembalian penuh **tidak mungkin memutus kompatibilitas
apa pun**.

---

## 12. Acceptance Criteria

Fase 0A selesai hanya jika **semuanya** terpenuhi:

**Fungsional**
- [ ] AC1 — Setelah scan berakhir tanpa hasil, tombol pindai hidup kembali dalam ≤2 detik (M1)
- [ ] AC2 — Tidak ada jalur kode yang bisa membuat `status` tetap `scanning` setelah scan berhenti
- [ ] AC3 — Putus tak sengaja memicu sambung ulang otomatis dengan jeda bertambah (M3)
- [ ] AC4 — Sambung ulang berhasil memulihkan koneksi tanpa sentuhan pengguna (M4)
- [ ] AC5 — Putus sengaja **tidak pernah** memicu sambung ulang (M6)
- [ ] AC6 — `ChatRepository.myNodeId` benar setelah sambung ulang (M5)
- [ ] AC7 — `connect()` yang gagal separuh jalan meninggalkan state bersih (M9)

**Kualitas**
- [ ] AC8 — Tidak ada `e.toString()` yang mencapai widget mana pun. Diverifikasi dengan grep.
- [ ] AC9 — Setiap `ConnectionFailure` punya pesan manusia + label aksi
- [ ] AC10 — Nol perubahan visual. Diverifikasi dengan tangkapan layar sebelum/sesudah pada keempat layar.
- [ ] AC11 — Nol perubahan pada `firmware/`, `dashboard/`, `docs/protokol-paket.md`. Diverifikasi dengan `git diff --stat`.
- [ ] AC12 — `flutter analyze` bersih, tanpa peringatan baru
- [ ] AC13 — `test/widget_test.dart` yang ada tetap lulus
- [ ] AC14 — Uji `connection_failure_test.dart` lulus
- [ ] AC15 — Semua skenario manual M1–M11 lulus di perangkat sungguhan

**Proses**
- [ ] AC16 — Tiap perubahan C1–C7 adalah commit tersendiri yang bisa dibangun
- [ ] AC17 — Sakelar `autoReconnectEnabled = false` mengembalikan perilaku lama
- [ ] AC18 — Dokumen handoff diperbarui dengan penyimpangan apa pun dari rencana ini

---

## 13. Yang TIDAK dikerjakan di 0A

Dicatat agar tidak ada yang mengira ini terlupa:

- Getar/alarm/banner saat putus → ❓Q1, kemungkinan Fase 2
- Sambung otomatis lintas restart aplikasi (butuh penyimpanan lokal) → Fase 2
- Alur koneksi nol-ketukan → Fase 2
- Menghapus animasi denyut 1500ms → Fase 2 (perubahan UI)
- Menghapus string-replace ANCHORPULSE→POINTRESCUE → Fase 2 + firmware
- Foreground service → Fase 4
- Perbaikan `NodeRepository` (GATEWAY, seq, Online berbohong) → **0B**
- Perbaikan chat (batas byte, status kirim) → **0C**
- Abstraksi perangkat agar bisa diuji penuh → Fase 1 (kalau ❓Q2 = Opsi A)
