# Design Decision Document — POINTRESCUE Mobile

Status: **menunggu persetujuan — nol layar diubah**
Sumber kebenaran: Figma `Untitled.zip` (22 berkas) + file `Q2LKg9YqApCFHEdHLGqa6Z`
Peninjau: Lead Product Designer / UX Architect / Design System Owner

---

## 0. Batasan teknis yang mengikat seluruh keputusan

Setiap keputusan di dokumen ini diuji terhadap arsitektur **yang benar-benar
ada**, bukan asumsi. Fakta yang mengikat:

| Kemampuan | Status | Sumber |
|---|---|---|
| Server / backend | **TIDAK ADA** | Tidak ada komponen server di repo; mesh murni peer-to-peer |
| Akun · kata sandi · sesi | **TIDAK ADA** | idem |
| Identitas perangkat | `NODE_ID` di-flash ke firmware (0 / 1xxx / 2xxx) | `CLAUDE.md` |
| Tipe paket | HEARTBEAT · TRACKING · SOS · CHAT — **4, tidak lebih** | `docs/protokol-paket.md` |
| Field paket | `net, id, seq, type, hop, lat, lng, alt, spd, sats, valid, msg` | idem |
| RSSI per node mesh | **TIDAK ADA** (hanya RSSI BLE lokal saat scan) | `mesh_packet.dart` |
| Baterai node | **TIDAK ADA** | idem |
| ACK / bukti terkirim | **TIDAK ADA** | `saran-tindaklanjut.txt` B4 |
| Kanal chat terpisah | **TIDAK ADA** — chat = broadcast ke seluruh mesh | firmware `originateChat()` |
| Lampiran / gambar | **TIDAK ADA** — 100 byte teks | `CHAT_MSG_MAX_LEN` |
| Riwayat historis | Sesi berjalan saja (persistensi = Fase 4) | keputusan proyek |

**Konsekuensi:** setiap elemen desain yang membutuhkan salah satu dari yang
bertanda "TIDAK ADA" **tidak dapat diimplementasikan** — bukan "sulit", tapi
mustahil tanpa membangun infrastruktur baru yang di luar cakupan PKM ini.

---

## 1. Evaluasi keseluruhan

Figma ini adalah **karya visual yang kuat dengan asumsi produk yang keliru.**

Kekuatannya nyata: bahasa taktis konsisten, hierarki tipografi jelas, palet
disiplin, dan beberapa pola operasional (checklist, timeline, system health)
yang menunjukkan pemahaman kerja SAR.

Masalah mendasarnya: desain ini **memodelkan produk yang berbeda** dari yang
sedang dibangun. Ia mengasumsikan sebuah *platform manajemen misi berbasis
cloud dengan akun operator, kanal komunikasi, dan telemetri kaya* —
sementara POINTRESCUE adalah *jembatan tampilan untuk mesh radio peer-to-peer
tanpa server*.

Angka pastinya: dari 19 layar, **7 layar (37%) mustahil dibangun** karena
membutuhkan server yang tidak ada, dan **11 dari ~40 elemen data** di layar
yang tersisa menampilkan nilai yang tidak dibawa protokol.

Ini bukan kegagalan desainer — ini kegagalan *brief*. Desain dibuat tanpa
batasan protokol di tangan.

---

## 2. Kekuatan (dipertahankan)

1. **Bahasa visual taktis yang matang.** Mono untuk data, uppercase berspasi
   untuk label, oranye sebagai satu-satunya aksen. Konsisten lintas layar.
2. **Emergency Checklist** (layar SOS) — mengubah notifikasi jadi alat kerja.
   Ide terbaik di seluruh berkas.
3. **Incident Timeline** — kronologi kejadian, sangat sesuai kerja SAR.
4. **System Health panel** — LoRa/GPS/BLE dalam satu blok; menjawab
   pertanyaan "bagian mana yang bermasalah" dalam satu pandangan.
5. **Onboarding 3 langkah** dengan ilustrasi 3D — menjelaskan konsep mesh
   ke relawan awam. Layak dipertahankan utuh.
6. **Marker pin berlabel** dengan chip nama — terbaca di peta gelap.
7. **Pairing dengan indikator kekuatan sinyal** — RSSI BLE saat scan memang
   tersedia, jadi ini implementable.
8. **Aset brand dipakai benar** di splash & login (wordmark asli, bukan teks).

---

## 3. Kelemahan

1. **Ketergantungan server yang tidak ada** — 7 layar (§9).
2. **Data fiktif tersebar luas.** `78% baterai`, `-72 dBm`, `SNR 8.5`, `SF 9`,
   `QUAL 94%`, `65% progress`, `T-MINUS 04:22:10`, `ETA 3m`, `Pending: 0`,
   `HEALTH GOOD` — semuanya tidak dapat dihitung. Di alat keselamatan jiwa,
   menampilkan angka yang tidak bisa dibuktikan adalah **risiko**, bukan
   kosmetik.
3. **Konsep "Misi" tidak punya dasar.** OPERATION NIGHTHAWK, durasi, fase,
   sektor, progres — tidak ada yang mendefinisikan, memulai, atau mengakhiri
   misi. Tidak ada server, tidak ada input.
4. **Navigasi 5 tab dengan tumpang tindih berat.** Dashboard, Map, Nodes,
   Message, More — tiga tab pertama menampilkan data yang sama dalam bentuk
   berbeda.
5. **Kepadatan berlebih di layar 6".** Layar Management memuat 4 blok berbeda
   di atas lipatan sebelum konten utama muncul.
6. **Aksi destruktif tanpa perlindungan.** `SOS BROADCAST` merah dan
   `SOS REQUEST` berada satu ketukan dari jempol, tanpa konfirmasi.
7. **Bahasa campur.** Onboarding punya varian Indonesia (`LEWATI` /
   `SELANJUTNYA`) dan Inggris (`SKIP` / `NEXT`) di berkas yang sama.
8. **Foto laptop sebagai konten** di layar SOS — placeholder yang terlihat
   seperti fitur.

---

## 4. Inkonsistensi desain

| # | Temuan | Bukti |
|---|---|---|
| D1 | **Dua palet dasar berbeda.** Splash & login memakai navy `#0F1E3D`; layar operasional memakai netral `#121317`. | Group 48 vs 10:1113 |
| D2 | **Radius tidak seragam:** 4 (chip marker), 6 (pin), 8 (panel), 9999 (pill), 12 (nav) | design context 10:1004 |
| D3 | **Tiga bahasa "kekuatan sinyal":** batang 4-bar (marker), diagram batang (LoRa Link), teks dBm (header) | 10:1028 / node detail / comms |
| D4 | **Dua representasi baterai:** `92% ▮▮▮▮` di peta, `78%` + progress bar di detail | 10:1026 vs node detail |
| D5 | **Tiga gaya tombol untuk aksi setara** di Node Detail (biru terisi, abu, accordion) | node detail |
| D6 | **Lima tata letak kartu berbeda** dalam satu layar Node Detail | node detail |
| D7 | **Dua gaya status pill:** kotak radius-4 (ONLINE/STANDBY) vs kapsul (SEARCHING/EMERGENCY) | scanning vs management |
| D8 | **Wordmark dirender 3 cara:** aset asli (splash/login), teks peach `#FFB695` (header), teks merah-biru (registrasi) | Group 48 / 10:1118 / Group 81 |

---

## 5. Inkonsistensi UX

| # | Temuan | Dampak |
|---|---|---|
| U1 | **Peta muncul di 3 layar** (Map, Live Tracking, Management) dengan kontrol berbeda-beda | Relawan harus belajar 3 peta |
| U2 | **Titik masuk SOS ganda:** FAB di peta + `SOS REQUEST` di chat + `SOS BROADCAST` di Management | Tidak jelas mana yang benar; dan ketiganya salah — lihat §9 |
| U3 | **Alur onboarding 10 layar** sebelum relawan melihat satu data pun | Terlalu panjang untuk alat darurat |
| U4 | **Tidak ada keadaan kosong** di satu pun layar | Kondisi paling umum saat pertama dipakai justru tak dirancang |
| U5 | **Tidak ada keadaan gagal/putus** | Padahal koneksi BLE putus adalah kejadian rutin di lapangan |
| U6 | **Tidak ada keadaan memuat** | idem |
| U7 | **"Nodes" tab vs "Management" tab** menampilkan daftar node yang sama | Duplikasi navigasi |
| U8 | **Playback timeline** (Live Tracking) tanpa sumber data historis | Kontrol yang tidak bisa berfungsi |

---

## 6. Masalah aksesibilitas

| # | Temuan | Ukuran |
|---|---|---|
| A1 | **Teks putih di atas oranye** `#F36C21` — tombol utama di hampir semua layar | **2,98:1** — gagal AA (min 4.5:1) |
| A2 | Teks `#8E909B` di atas `#121317` (label sekunder) | ~4,1:1 — gagal AA untuk teks kecil |
| A3 | Chip marker 10px mono di atas peta bertekstur | Ukuran di bawah ambang keterbacaan lapangan |
| A4 | Target sentuh tab nav 5 kolom di lebar 390 | ~64dp lebar tapi tinggi ikon efektif <48dp |
| A5 | Status **hanya** dibedakan warna (hijau/merah/kuning) tanpa ikon atau teks pembeda | Gagal untuk buta warna (8% pria) |
| A6 | Tidak ada perlakuan `prefers-reduced-motion` untuk denyut/animasi | — |
| A7 | Kontras `#434750` sebagai garis pemisah di `#121317` | ~1,9:1 — batas kartu nyaris tak terlihat di bawah matahari |

---

## 7. Keputusan per layar

Legenda: **KEEP** · **MERGE** · **SIMPLIFY** · **REMOVE** · **REDESIGN** · **POSTPONE**

### 7.1 Splash
- **Tujuan:** identitas + tanda sistem sedang siap.
- **Aksi utama:** tidak ada (otomatis lanjut).
- **Kelebihan:** aset brand dipakai benar; strip di dua sisi.
- **Masalah:** "INITIALIZING TACTICAL SYSTEMS" menyiratkan proses yang tidak
  ada; palet navy berbeda dari layar operasional (D1).
- **Keputusan: KEEP + SIMPLIFY.** Pertahankan komposisi; ganti teks jadi
  status nyata (memuat aset / memeriksa izin) atau hilangkan. Palet navy
  **dipertahankan** sebagai pengecualian sadar: splash adalah momen identitas,
  bukan layar operasional.

### 7.2 Onboarding 1–3 (Monitoring · LoRa · Mission Ready)
- **Tujuan:** menjelaskan konsep mesh tanpa internet ke relawan awam.
- **Aksi utama:** Lanjut / Lewati.
- **Kelebihan:** ilustrasi 3D menjelaskan konsep yang sulit diucapkan;
  tidak butuh server sama sekali.
- **Masalah:** bahasa campur ID/EN (U-bahasa); layar 3 "Mission Ready"
  menjanjikan "everything is connected" padahal belum ada koneksi apa pun.
- **Keputusan: KEEP (1 & 2) + MERGE (3).** Layar 3 digabung ke alur koneksi
  — "siap" hanya boleh diklaim setelah node benar-benar tersambung.
  Bahasa diseragamkan ke Indonesia (keputusan i18n proyek).

### 7.3 Operator Registration
- **Tujuan:** membuat akun operator.
- **Keputusan: REMOVE.**
- **Alasan teknis:** tidak ada server yang menyimpan akun, tidak ada basis
  data, tidak ada layanan email untuk verifikasi. Form ini mengumpulkan
  nama, organisasi, telepon, dan kata sandi yang **tidak punya tujuan** —
  dan mengumpulkan data pribadi tanpa penyimpanan yang aman adalah risiko
  privasi, bukan sekadar fitur mubazir.

### 7.4 Secure Login
- **Keputusan: REMOVE.** Sama seperti §7.3. Tambahan: tombol SSO Google/Apple
  memerlukan OAuth client + backend penukar token.

### 7.5 System Recovery (lupa kata sandi)
- **Keputusan: REMOVE.** Memulihkan kredensial yang tidak pernah ada.

### 7.6 Account Verified
- **Keputusan: REMOVE.** Konsekuensi §7.3–7.5.

### 7.7 Select Your Role (Command Center / SAR Team)
- **Keputusan: REMOVE.**
- **Alasan teknis:** peran ditentukan **perangkat keras** — `NODE_ID` 0 =
  GATEWAY, 1xxx = SAR, 2xxx = KORBAN, di-flash sebelum perangkat dibagikan.
  Membiarkan pengguna memilih peran menciptakan kemungkinan aplikasi
  mengklaim peran yang bertentangan dengan node fisiknya.
- **Catatan:** kalau kelak dibutuhkan mode tampilan berbeda (posko vs
  lapangan), itu **preferensi tampilan** di Pengaturan, bukan identitas.

### 7.8 Scanning for Gateways
- **Tujuan:** menemukan & memasangkan node.
- **Aksi utama:** PAIR.
- **Kelebihan:** radar + daftar perangkat + indikator sinyal — **semuanya
  implementable**, karena RSSI BLE tersedia saat scan.
- **Masalah:** `FREQ: 915 MHz LORA` salah — perangkat ini **433 MHz**
  (`CLAUDE.md`), dan lagipula frekuensi LoRa tidak terlihat dari sisi BLE.
  `RANGE: 5KM` dan koordinat di kanvas radar tidak dapat dihitung.
  Nama perangkat `GATEWAY-ALPHA` / `SENSOR-PACK-B` tidak sesuai skema
  penamaan nyata (`ANCHORPULSE-SAR-xxxx`).
- **Keputusan: KEEP + REDESIGN.** Pertahankan radar & daftar; buang
  frekuensi/jangkauan/koordinat; nama perangkat mengikuti advertising BLE
  sungguhan; indikator sinyal dari RSSI nyata.

### 7.9 Pairing Device
- **Keputusan: KEEP + SIMPLIFY.** Sesuai keputusan D5 (auto-connect untuk
  node tersimpan), layar ini hanya muncul **sekali per node baru**.

### 7.10 Mission Ready (link active)
- **Keputusan: MERGE** ke akhir alur koneksi. Pemeriksaan GPS/Gateway/Power
  dipertahankan **hanya untuk yang bisa diukur**: status BLE (bisa),
  izin (bisa), GPS HP sendiri (bisa, setelah paket geolokasi masuk).
  "Power Reserves 98%" = baterai HP — bisa dibaca, tapi nilainya rendah;
  **POSTPONE**.

### 7.11 Mission Control Dashboard
- **Tujuan:** ringkasan operasi.
- **Masalah:** OPERATION NIGHTHAWK / DURATION / PHASE / Sector Alpha —
  seluruh blok teratas fiktif. QUICK ACTIONS: `ADD WAYPOINT` (tidak ada
  penyimpanan waypoint), `BROADCAST` (duplikat chat), `MEASURE` (bisa),
  `SYS CHECK` (tidak jelas artinya).
- **Kelebihan:** SYSTEM HEALTH dan RECENT ACTIVITY sangat berharga.
- **Keputusan: MERGE + SIMPLIFY.** Bukan tab tersendiri — isinya jadi
  **posisi penuh bottom sheet di atas peta**, sehingga peta tak pernah
  hilang. Blok misi dibuang; stat diubah jadi hitungan per peran (nyata);
  System Health & Recent Activity dipertahankan utuh.

### 7.12 Tactical Mission Map
- **Tujuan:** kesadaran situasional — **layar terpenting di produk**.
- **Aksi utama:** melihat posisi; membuka detail node.
- **Masalah:** 6 elemen mengambang berbeda bentuk; layer toggle untuk
  "Sensors" yang tidak ada; koordinat mengambang duplikat dengan detail
  node; **Giant SOS FAB salah arah** (lihat §9).
- **Keputusan: KEEP + REDESIGN.** Jadi **rumah aplikasi**. Elemen
  mengambang dibatasi 2 kelompok. Layer toggle disederhanakan jadi filter
  peran (SAR/Korban/Gateway) di sheet.

### 7.13 Live Tracking (playback)
- **Keputusan: MERGE + POSTPONE.**
- **Alasan teknis:** kontrol playback (⏮ ⏸ 1×) membutuhkan **riwayat
  posisi tersimpan**, yang baru ada setelah persistensi misi (Fase 4).
  Petanya sendiri identik dengan §7.12 — dua layar untuk satu pekerjaan.
- Playback dipertahankan sebagai **kandidat pasca-Fase 4**, bukan dibuang.

### 7.14 Node Detail
- **Tujuan:** seluruh informasi & aksi satu node.
- **Kelebihan:** paling lengkap; konsep "rumah aksi" benar.
- **Masalah:** 5 tata letak kartu berbeda (D6); `POWER 78%`, `EST TIME`,
  `HEALTH GOOD`, `LORA LINK -72dBm/QUAL/SNR/SF`, `SECTOR SEARCH 65%` —
  **semua fiktif**. `FOLLOW LIVE`, `BROADCAST`, `SYS CHECK` tidak punya
  perilaku yang terdefinisi.
- **Keputusan: KEEP + REDESIGN.** Satu pola baris data diulang; data yang
  belum ada digambar **redup berlabel fase**, tidak dihapus (agar rencananya
  terlihat) dan tidak diisi angka contoh (agar tidak berbohong).

### 7.15 Management (Teams / Victims / Resources)
- **Masalah:** MISSION PROGRESS 65% & T-MINUS fiktif; `LEADER ALPHA-1`,
  `LOCATION Sector 4` tidak ada di protokol; `RESOURCES` tidak punya
  sumber data; `SOS BROADCAST` merah tanpa konfirmasi.
- **Kelebihan:** segmented filter adalah ide bagus.
- **Keputusan: MERGE.** Daftar node = bottom sheet peta; segmented
  TEAMS/VICTIMS/RESOURCES → filter **SAR / Korban / Gateway** (peran nyata).
  Tab "Nodes" dan "Management" dihapus sebagai tujuan navigasi terpisah.

### 7.16 Mission Communication Center
- **Kelebihan:** paling dekat dengan kebutuhan nyata; quick action chips
  (`PROCEED` / `HOLD POSITION`) adalah versi lain dari preset kami.
- **Masalah:**
  - **Kanal** (Mission Command / Team Alpha / Team Bravo) — chat LoRa adalah
    **broadcast tunggal**; tidak ada alamat, tidak ada grup.
  - **`DELIVERED` dan `✓ ACK`** — protokol **tidak punya ACK**. Ini
    kebohongan paling berbahaya di seluruh berkas: relawan menyimpulkan
    pesannya sampai padahal tidak ada bukti.
  - **Lampiran** (klip kertas) & **peta di dalam pesan** — 100 byte teks.
  - `Pending: 0`, `LoRa: -72dBm` — tidak terukur.
  - `SOS REQUEST` sebagai chip — lihat §9.
- **Keputusan: KEEP + REDESIGN.** Satu percakapan broadcast; preset satu
  ketuk dipertahankan; **hapus semua penanda terkirim/ACK**; status hanya
  boleh menyatakan apa yang terbukti (*mengirim…* / *gagal terkirim*).

### 7.17 Emergency Response & SOS
- **Kelebihan:** Emergency Checklist & Incident Timeline — dua ide terbaik.
- **Masalah:** `Priority CRITICAL`, `Sector Beta`, `SOS-2025-89`, `ETA 3m`,
  `MEDIC-01 Dispatched`, `ASSIGNED RESOURCES` — tidak ada penugasan sumber
  daya di protokol. Foto laptop sebagai konten.
- **Keputusan: KEEP + REDESIGN.** Jadi **interupsi layar penuh** (bukan tab
  "Emergency"). Checklist = daftar lokal di HP (implementable, tidak butuh
  server). Timeline = kejadian nyata dari paket. Assigned Resources →
  **POSTPONE** sampai tipe paket CLAIM ada (Fase 5).

### 7.18 BottomNavBar (5 tab)
- **Keputusan: REDESIGN → 3 tab.** Dashboard & Nodes diserap peta+sheet;
  More tidak punya isi yang tersisa selain Pengaturan.

### 7.19 Brand strip & Shader
- **Keputusan: KEEP (strip) / REMOVE (shader).** Strip = aset identitas,
  dipakai maksimum satu per layar di momen identitas. Shader adalah artefak
  Stitch, bukan elemen desain.

---

## 8. Komponen yang dipertahankan

| Komponen | Alasan |
|---|---|
| Marker pin berlabel | Terbaca di peta gelap; bentuk khas brand |
| Status pill | Sudah konsisten; tinggal disatukan gayanya (D7) |
| Baris data ikon+label+nilai mono | Pola paling kuat di seluruh berkas |
| Stat card | Ringkasan sekilas |
| Checklist row | Ide terbaik; implementable penuh (lokal) |
| Timeline row | Kronologi nyata dari paket |
| Radar scanner | Menjelaskan "sedang mencari" tanpa teks |
| Chip aksi cepat | Versi lain dari preset chat |
| Ilustrasi onboarding 3D | Menjelaskan konsep mesh |
| Strip brand | Identitas |

## 9. Komponen yang dihapus — dan mengapa

| Komponen | Alasan |
|---|---|
| **Semua tombol SOS di aplikasi** (FAB peta, chip chat, SOS BROADCAST) | **Arah salah.** Aplikasi mobile dipakai **tim SAR**; SOS berasal dari **tombol fisik di node KORBAN** (`CLAUDE.md`: pin 4 → GND). Relawan SAR tidak mengirim SOS — ia menerimanya. Tombol ini akan memancarkan sinyal darurat palsu ke seluruh mesh. |
| Penanda `DELIVERED` / `✓ ACK` | Protokol tanpa ACK tidak bisa membuktikannya |
| Kanal/grup chat | Chat = broadcast tunggal |
| Lampiran & peta dalam pesan | Batas 100 byte teks |
| Blok misi (nama/durasi/fase/progres/T-minus) | Tidak ada yang mendefinisikan misi |
| Assigned Resources | Tidak ada penugasan di protokol |
| Layer toggle "Sensors" | Tidak ada sensor |
| Playback timeline | Butuh riwayat tersimpan (POSTPONE, bukan REMOVE) |
| `ADD WAYPOINT`, `SYS CHECK` | Perilaku tidak terdefinisi & tidak ada penyimpanan |
| 4 layar autentikasi + Select Role | Tidak ada server; peran dari firmware |
| Foto laptop di layar SOS | Placeholder |

## 10. Arsitektur navigasi yang diusulkan

```
Splash
  └─ Onboarding 1–2 (sekali seumur pemasangan, bisa dilewati)
       └─ Koneksi  (izin → pindai → pasangkan → tersambung)
            └─ SHELL — 3 tab
                 ├─ PETA  ◄── rumah
                 │    └─ bottom sheet 3 posisi
                 │         ├─ ringkas   : hitungan per peran
                 │         ├─ separuh   : daftar node + filter peran
                 │         └─ penuh     : + kesehatan sistem + aktivitas
                 │    └─ ketuk node → DETAIL NODE
                 │                      └─ Navigasi kompas   (Fase 5)
                 │                      └─ Saya tangani      (Fase 5)
                 ├─ CHAT  : satu percakapan broadcast + preset
                 └─ PENGATURAN
                      └─ Mode pengembang

INTERUPSI SOS — layar penuh, di atas apa pun, dari paket SOS masuk
```

**Alasan 3 tab:** Dashboard/Nodes/Management semuanya menjawab pertanyaan
spasial yang sama; menempatkannya di atas peta sebagai sheet membuat peta
**tidak pernah hilang** — dan kesadaran situasional adalah pekerjaan utama.

## 11. Arsitektur informasi

Diurut menurut pertanyaan relawan, bukan struktur data:

| Prioritas | Pertanyaan | Ditampilkan di | Sumber data |
|---|---|---|---|
| 1 | "Ada yang butuh tolong?" | Interupsi SOS · marker merah | paket SOS |
| 2 | "Tim saya di mana?" | Peta (rumah) | paket TRACKING |
| 3 | "Apakah saya masih terhubung?" | Chip header · System Health | status BLE + umur paket |
| 4 | "Siapa saja yang ada?" | Sheet separuh | semua paket |
| 5 | "Detail node ini?" | Detail node | TRACKING + heartbeat |
| 6 | "Apa yang sudah terjadi?" | Sheet penuh → Aktivitas | log kejadian sesi |
| 7 | "Kabar untuk tim" | Chat | paket CHAT |

Tiga tingkat kedalaman maksimum: **Peta → Sheet → Detail**. Tidak ada
layar yang butuh lebih dari 2 ketukan dari rumah.

## 12. Keputusan design system

| Aspek | Keputusan | Alasan |
|---|---|---|
| **Tipografi** | 2 keluarga: Inter (UI) + JetBrains Mono (semua angka). Skala 7 tingkat: display 28 / title 20 / body 16 / label 13 / caption 11 / **data 15 mono** / overline 10 uppercase | Figma memakai 4 keluarga (Hanken Grotesk, JetBrains Mono, Poppins, Oswald) — bising di layar 6". Mono untuk angka = warisan dashboard |
| **Spacing** | Skala 4pt: 4 · 8 · 12 · 16 · 24 · 32 | Figma memakai nilai bebas (5, 6, 9, 13, 22) |
| **Grid** | Kolom tunggal, margin 16dp, jarak antar-kartu 8dp | Layar 390dp tidak muat multi-kolom bermakna |
| **Kartu** | Satu gaya: radius 16, permukaan naik, **border 1px**, tanpa bayangan | Bayangan hitam tak terlihat di tema gelap; border memberi batas yang terbaca (memperbaiki A7) |
| **Tombol** | 4 bobot: primer (aksen) · bahaya (garis) · sekunder · teks. Tinggi 56dp. **Satu primer per layar** | Figma punya 3 bobot berbeda untuk aksi setara (D5) |
| **Input** | Sumur permukaan-overlay, radius 16, tinggi 56dp, tanpa garis bawah | Konsisten dengan kartu |
| **Warna status** | 4 pasangan (teks + tint latar): kritikal · peringatan · ok · nonaktif | Menggantikan `warna.withOpacity(0.1)` yang tak terverifikasi |
| **Warna semantik** | Warna **hanya** menyampaikan status. Aksen oranye hanya untuk aksi utama. **Status wajib punya ikon + teks**, bukan warna saja | Memperbaiki A5 (buta warna) |
| **Radius** | **2 nilai**: 8 (pill/chip) · 16 (kartu/sheet/tombol). Pengecualian: 12 untuk sudut bilah nav | Figma memakai 5 nilai (D2) |
| **Elevation** | **Tidak dipakai.** Kedalaman dari perbedaan permukaan + border | Bayangan tak berfungsi di gelap |
| **Border** | 1px `contentMuted` 25% pada semua permukaan naik | Batas terbaca; memperbaiki A7 |
| **Ikon** | Material Symbols Rounded, 3 ukuran: 14 (ubin) · 18 (baris) · 22 (aksi) | Kelanjutan dashboard |
| **Ilustrasi** | Hanya di onboarding & empty state. Gaya 3D isometrik gelap. **Tidak pernah** di layar operasional | Layar kerja tidak boleh dihias |
| **Animasi** | Fungsional saja, ≤200ms. Pengecualian: denyut SOS (menyandikan urgensi) & radar sweep (menyandikan proses). Wajib menghormati `disableAnimations` | Memperbaiki A6 |
| **Loading** | Tidak ada spinner tanpa keterangan. Setiap tunggu punya kalimat: "Mencari node…", "Menyambungkan…" | Prinsip #1 |
| **Empty state** | Ikon + judul + sub + aksi opsional. Bahasa relawan, bukan bahasa mesin | Memperbaiki U4 |
| **Error state** | Sebab manusia + akibat + **satu** tombol aksi. Nol `e.toString()` | Memperbaiki U5 |
| **Kontras** | AA 4.5:1 wajib, diverifikasi uji otomatis. **Teks di atas oranye = navy-deep**, tidak pernah putih | Memperbaiki A1 (2,98:1 → 6,4:1) |
| **Sentuh** | Minimum 56dp permanen, bukan setting | Sarung tangan adalah baseline |

## 13. Prioritas implementasi

### TINGGI — tanpa ini produk tidak dapat dipakai
1. Hapus semua tombol SOS keluar dari aplikasi *(risiko keselamatan: sinyal palsu)*
2. Hapus penanda DELIVERED/ACK *(risiko keselamatan: kepercayaan palsu)*
3. Hapus 4 layar auth + Select Role *(tidak dapat dibangun; risiko privasi)*
4. Peta jadi rumah + navigasi 3 tab
5. Perbaiki kontras teks-di-atas-oranye *(A1 — ada di setiap layar)*
6. Keadaan kosong / memuat / gagal untuk seluruh alur *(U4–U6)*
7. Ganti semua data fiktif jadi redup-berlabel

### SEDANG — kualitas produk
8. Satukan bahasa sinyal & baterai jadi satu meter *(D3, D4)*
9. Satukan gaya kartu & tombol *(D5, D6, D7)*
10. Bottom sheet 3 posisi + filter peran
11. Layar detail node dengan satu pola baris
12. Chat: preset + status jujur
13. Status berikon (buta warna) *(A5)*
14. Seragamkan bahasa ke Indonesia
15. Onboarding 2 layar + gabung "Mission Ready" ke alur koneksi

### RENDAH — setelah fondasi kokoh
16. Interupsi SOS layar penuh *(butuh izin full-screen intent)*
17. Emergency Checklist & Incident Timeline
18. Navigasi kompas *(butuh GPS HP)*
19. Peta offline
20. Playback timeline *(butuh persistensi)*
21. Panel LoRa Link & baterai *(butuh perubahan firmware)*

## 14. Risiko

| # | Risiko | Dampak | Mitigasi |
|---|---|---|---|
| R1 | **Tombol SOS terkirim tak sengaja** | Sinyal darurat palsu membanjiri mesh; tim bergerak ke lokasi salah | Hapus seluruhnya dari aplikasi mobile |
| R2 | **Relawan percaya pesan sampai** karena penanda ACK | Informasi kritis dianggap tersampaikan padahal tidak | Hapus penanda; status hanya menyatakan yang terbukti |
| R3 | **Angka fiktif dianggap nyata** (baterai, sinyal) | Keputusan operasional berdasar data karangan | Redup + label fase; tidak pernah angka contoh |
| R4 | **Ekspektasi fitur tidak terpenuhi** — desain menjanjikan 19 layar, produk mengirim 11 | Kekecewaan pemangku kepentingan / juri | Dokumen ini + peta jalan eksplisit per fase |
| R5 | **Data pribadi dikumpulkan tanpa penyimpanan aman** (form registrasi) | Risiko privasi | Hapus form |
| R6 | **Kontras gagal di bawah matahari** | Layar tidak terbaca justru saat paling dibutuhkan | Uji kontras otomatis sebagai gerbang build |
| R7 | **Palet ganda** (navy splash vs netral operasional) menular ke layar lain | Inkonsistensi merambat | Navy dikunci hanya untuk momen identitas |
| R8 | **Ruang lingkup melar** karena desain terlihat "sudah jadi" | Waktu habis di fitur mustahil | Prioritas §13 sebagai kontrak |

## 15. Rekomendasi akhir

**Terima desain ini sebagai bahasa visual. Tolak sebagian besar asumsi
produknya.**

Konkretnya:

1. **Adopsi penuh** bahasa visualnya — palet, tipografi, kerapatan, nuansa
   taktis. Ini kekuatan nyata dan sudah selaras dengan dashboard.
2. **Adopsi 5 pola operasional**: Checklist, Timeline, System Health,
   filter peran, chip aksi cepat. Semuanya implementable dan bernilai.
3. **Hapus 7 layar** yang membutuhkan server. Ini bukan pengurangan
   ambisi — ini penyesuaian dengan arsitektur yang sudah dipilih (mesh
   tanpa infrastruktur, yang justru merupakan inovasi proyek ini).
4. **Hapus 3 titik masuk SOS.** Ini keputusan keselamatan, bukan desain.
5. **Ganti seluruh data fiktif** dengan keadaan redup-berlabel. Alat SAR
   tidak boleh menampilkan angka yang tidak bisa dibuktikan.
6. **Turunkan 19 layar → 11 layar, 5 tab → 3 tab.** Produk jadi lebih kecil
   dan jauh lebih dapat diandalkan.

Hasil akhirnya bukan produk yang lebih miskin — melainkan produk yang
**setiap pikselnya didukung oleh perangkat keras yang benar-benar ada**.
Itulah yang membedakan prototipe dari alat.

---

**Menunggu persetujuan.** Setelah disetujui, langkah berikutnya adalah
menyelaraskan Figma dengan keputusan ini — bukan mengubah kode terlebih
dahulu.
