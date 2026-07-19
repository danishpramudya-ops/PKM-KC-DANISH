# Strategi UX & Rencana Redesign — POINTRESCUE

Dokumen ini adalah hasil Step 3–5 dari proses desain. Berisi strategi UX,
rencana redesign UI, dan urutan prioritas pengerjaan.

Status: **disetujui — siap masuk Fase 0**

Basis keputusan yang sudah dikunci ada di bagian akhir (Lampiran A).

---

# STEP 3 — STRATEGI UX

## 3.1 Lima prinsip yang mengikat semua keputusan

Setiap usulan desain di dokumen ini harus lolos kelima prinsip berikut.
Kalau bertabrakan, urutan nomor menentukan pemenangnya.

### 1. Jujur tentang keadaan (Truthful State)

Aplikasi tidak boleh menampilkan sesuatu yang lebih baik dari kenyataan.
Node yang mungkin sudah mati tidak boleh tampil "Online". Pesan yang belum
tentu terkirim tidak boleh tampil seperti terkirim. Koneksi yang putus harus
terasa seperti putus.

Ini prinsip nomor satu karena di aplikasi keselamatan jiwa, **kepercayaan palsu
lebih berbahaya daripada ketidaktahuan**. Relawan yang tahu dia buta akan
mencari cara lain; relawan yang dibohongi tidak akan.

### 2. Nol ketukan di jalur normal (Zero-Tap Happy Path)

Pekerjaan yang paling sering dilakukan harus butuh tindakan paling sedikit.
Membuka aplikasi dan melihat posisi tim = nol ketukan. Kalau sebuah alur
normal butuh lebih dari dua ketukan, alur itu salah desain.

### 3. Terbaca dalam tiga detik (Three-Second Glance)

Relawan melihat layar sambil berjalan, di bawah matahari, mungkin sambil
berpegangan. Setiap layar harus menjawab satu pertanyaan utamanya dalam
tiga detik. Kalau butuh membaca, layar itu terlalu padat.

### 4. Gagal dengan terang (Loud Failure)

Kegagalan tidak pernah senyap. Setiap kegagalan wajib punya tiga hal:
penyebab dalam bahasa manusia, akibatnya bagi relawan, dan satu tombol aksi.
Tidak ada `e.toString()` yang boleh sampai ke layar.

### 5. Satu bahasa, dua dialek (One System, Two Dialects)

Mobile dan dashboard berbagi satu sumber token (warna, tipografi, spacing,
radius). Yang boleh berbeda hanya kepadatan dan ukuran sentuh — bukan
identitasnya. Relawan yang pindah dari HP ke layar posko harus merasa
memakai produk yang sama.

## 3.2 Model mental pengguna

Yang perlu dipahami: relawan **tidak berpikir dalam node, paket, atau mesh.**
Dia berpikir dalam pertanyaan.

| Pertanyaan relawan | Terjemahan teknis | Di mana dijawab |
|---|---|---|
| "Tim saya di mana?" | posisi node role 1 | Peta (utama) |
| "Ada yang butuh tolong?" | paket SOS | Interupsi SOS |
| "Ke arah mana korbannya?" | bearing + jarak | Layar navigasi |
| "Apakah saya masih terhubung?" | status BLE + mesh | Indikator status |
| "Siapa yang sudah menangani?" | paket CLAIM | Detail node |
| "Apa yang sudah terjadi?" | riwayat paket | Timeline |

**Konsekuensi desain:** istilah internal (paket, TRACKING, heartbeat, hop, seq)
tidak boleh muncul di UI utama. Tempatnya hanya di Developer Mode.

## 3.3 Tiga alur inti

### Alur A — Mulai misi (target: nol ketukan)

```
Buka app → [otomatis: izin, bluetooth, cari, sambung] → PETA
```

Kegagalan di titik mana pun berhenti pada satu kartu yang menjelaskan
sebab dan satu tombol aksi. Tidak ada jalan buntu tanpa tombol.

### Alur B — Merespons SOS (target: dua ketukan)

```
SOS masuk → [interupsi penuh] → "Navigasi" → layar kompas
                              └→ "Saya tangani" → disiarkan ke mesh
```

Aturan wajib: **interupsi penuh hanya sekali per korban per episode SOS.**
Paket SOS berikutnya dari korban yang sama memperbarui posisi secara diam-diam.
Tanpa aturan ini relawan akan membisukan aplikasi, dan fitur terpenting mati.

### Alur C — Kehilangan kontak (target: tanpa ketukan)

```
Putus → [getar + suara + banner persisten] → auto-reconnect (backoff)
      → pulih: banner hijau 3 detik, hilang sendiri
      → gagal terus: banner tetap, tombol manual
```

Relawan tidak diminta melakukan apa pun. Aplikasi memperbaiki dirinya sendiri
dan hanya melapor.

---

# KEPUTUSAN DESAIN

Butir-butir ini punya trade-off nyata. Semua alternatif sengaja tetap
didokumentasikan beserta kelebihan dan kekurangannya, supaya alasan di balik
tiap keputusan bisa ditinjau ulang kalau kebutuhan berubah.

## D1. Struktur navigasi mobile

### Opsi 1 — Dua tab: Peta + Pengaturan

Chat jadi bottom sheet yang dipanggil dari tombol di peta, dengan lencana
jumlah pesan belum dibaca.

**Kelebihan:** paling fokus; ruang layar maksimum untuk peta; sesuai realita
bahwa chat LoRa jarang dipakai; navigasi 2 tab terasa percaya diri.
**Kekurangan:** chat jadi kurang terlihat; pengguna baru mungkin tidak
menemukannya; lencana harus dirancang menonjol.
**Cocok bila:** peta benar-benar pusat pekerjaan, chat sekunder.

### Opsi 2 — Tiga tab: Peta + Chat + Pengaturan

**Kelebihan:** chat selalu terlihat dan mudah ditemukan; pola paling familiar;
paling murah dikerjakan karena mendekati struktur sekarang.
**Kekurangan:** satu slot navigasi permanen dipakai fitur yang jarang diakses;
peta kehilangan ~56px tinggi permanen.
**Cocok bila:** komunikasi tim ternyata sesering melihat peta.

### Opsi 3 — Tanpa tab: peta layar penuh + tombol mengambang

Semua fungsi lain dipanggil dari tombol mengambang di atas peta.

**Kelebihan:** paling imersif dan paling "taktis"; peta dapat 100% layar;
paling mendekati ATAK.
**Kekurangan:** paling asing bagi pengguna Android awam; tanpa tab, pengguna
kehilangan peta mental tentang isi aplikasi; risiko tertinggi untuk relawan
non-teknis.
**Cocok bila:** penggunanya terlatih dan dilatih memakai alat ini.

**Catatan saya:** Opsi 1 paling seimbang, tapi Opsi 3 paling sesuai dengan
arah visual Tactical yang sudah kamu pilih. Opsi 3 punya risiko nyata untuk
relawan yang tidak dilatih — dan kamu sendiri menekankan "relawan, bukan teknisi".

> **✅ Keputusan: Opsi 2 — tiga tab (Peta · Chat · Pengaturan).**
> Berbeda dari usulan saya, dan itu bisa dipertahankan: familiaritas lebih
> berharga daripada penghematan ruang ketika penggunanya relawan tak terlatih.
> Konsekuensi: daftar node tetap tidak punya tab sendiri (turun dari 4 tab ke 3),
> jadi ia harus hidup di atas peta — lihat D2.

## D2. Cara daftar node muncul di atas peta

### Opsi 1 — Bottom sheet yang bisa ditarik (3 posisi)

Tertutup (hanya gagang + ringkasan "6 node · 1 SOS"), separuh, penuh.

**Kelebihan:** peta dan daftar terlihat bersamaan; ringkasan selalu tampak;
pola standar Google Maps sehingga sudah dikenal; nyaman satu tangan.
**Kekurangan:** menutupi bagian bawah peta; gestur tarik bisa sulit dengan
sarung tangan basah.
**Mitigasi:** sediakan tombol ketuk selain gestur tarik.

### Opsi 2 — Overlay penuh yang dipanggil tombol

**Kelebihan:** peta bersih 100% saat tertutup; tidak butuh gestur presisi;
daftar dapat ruang penuh saat dibuka.
**Kekurangan:** peta dan daftar tidak pernah terlihat bersamaan; butuh
ketukan bolak-balik untuk membandingkan.

### Opsi 3 — Bilah ringkas horizontal di bawah peta

Kartu node yang bisa digeser ke samping.

**Kelebihan:** hemat ruang vertikal; menggeser kartu bisa langsung memusatkan
peta ke node itu — interaksi yang sangat memuaskan.
**Kekurangan:** hanya muat 1–2 node sekaligus; buruk untuk 20 node;
membandingkan status seluruh tim jadi sulit.

**Catatan saya:** Opsi 1 unggul untuk 5–20 node yang jadi skalamu. Opsi 3
menarik tapi gagal di batas atas skalamu.

> **✅ Keputusan: Opsi 1 — bottom sheet tiga posisi.**
> Syarat wajib yang mengikat: setiap posisi harus bisa dicapai dengan
> **ketukan**, bukan hanya gestur tarik. Gestur tetap ada sebagai jalan cepat,
> tapi tidak boleh jadi satu-satunya cara — sarung tangan basah membuat
> gestur tarik tidak dapat diandalkan.

## D3. Bagaimana SOS menembus layar terkunci

### Opsi 1 — Full-screen intent notification (setara panggilan masuk)

**Kelebihan:** benar-benar menembus layar terkunci; berbunyi walau mode senyap;
perlakuan sistem setingkat panggilan darurat; paling andal.
**Kekurangan:** butuh izin `USE_FULL_SCREEN_INTENT`; Android 14+ memperketat
izin ini dan Play Store meminta justifikasi; paling rumit dikerjakan.

### Opsi 2 — Notifikasi prioritas tinggi + alarm audio

**Kelebihan:** jauh lebih sederhana; tidak butuh izin khusus; tetap berbunyi
dan bergetar.
**Kekurangan:** tidak menembus layar terkunci sebagai layar penuh; relawan
harus membuka kunci HP dulu; bisa terlewat kalau HP di saku.

### Opsi 3 — Bertingkat: notifikasi dulu, layar penuh saat app terbuka

**Kelebihan:** kompromi realistis; nol risiko kebijakan Play Store.
**Kekurangan:** perilaku tidak konsisten antara app terbuka dan tertutup —
pengguna tidak bisa memprediksi apa yang akan terjadi, dan itu melanggar
prinsip "Jujur tentang keadaan".

**Catatan saya:** Opsi 1 satu-satunya yang benar-benar memenuhi keputusanmu
"interupsi penuh". Kalau distribusinya lewat Play Store, izin ini perlu
justifikasi — tapi aplikasi SAR adalah salah satu kasus penggunaan yang
memang disetujui Google. Kalau distribusinya APK langsung ke relawan,
tidak ada hambatan sama sekali.

> **✅ Keputusan: Opsi 1 — full-screen intent.**
> Konsekuensi yang harus disiapkan: izin `USE_FULL_SCREEN_INTENT` di manifest,
> penanganan penolakan izin di Android 14+ (dengan jalur mundur ke notifikasi
> prioritas tinggi bila izin tidak diberikan), dan justifikasi Play Store bila
> nanti didistribusikan lewat sana.

## D4. Model tema

### Opsi 1 — Empat pilihan: Terang · Gelap · Malam-merah · Ikuti sistem

**Kelebihan:** melayani semua kondisi lapangan; mode merah menjaga adaptasi
mata di operasi malam — pembeda nyata dari aplikasi biasa.
**Kekurangan:** setiap komponen harus diuji di empat kondisi; mode merah
menuntut palet terpisah, bukan sekadar filter.

### Opsi 2 — Tiga pilihan: Terang · Gelap · Ikuti sistem

**Kelebihan:** standar, mudah dikerjakan, cukup untuk mayoritas kasus.
**Kekurangan:** tidak melayani operasi malam sungguhan.

### Opsi 3 — Terang · Gelap · Ikuti sistem, plus sakelar "Mode Malam" terpisah

Mode merah jadi lapisan di atas tema gelap, bukan tema keempat.

**Kelebihan:** lebih sedikit kombinasi untuk diuji; mode merah bisa
diaktifkan cepat tanpa mengubah preferensi tema utama.
**Kekurangan:** dua konsep pengaturan yang saling terkait bisa membingungkan.

**Pertanyaan tambahan:** tema default saat pertama dipasang — Terang, Gelap,
atau Ikuti sistem? Untuk alat lapangan yang paling sering dipakai siang hari,
default Terang berkontras tinggi lebih aman daripada Gelap, meski Gelap
terlihat lebih "taktis" di screenshot.

> **✅ Keputusan: Opsi 1 — empat tema, default Terang.**
> Terang · Gelap · Malam-merah · Ikuti sistem. Default Terang berkontras tinggi,
> bukan Ikuti sistem — supaya relawan yang HP-nya dark mode tidak mendapat tema
> gelap di bawah matahari.
> Konsekuensi: setiap komponen wajib diverifikasi kontrasnya di **empat** kondisi,
> dan Malam-merah butuh palet tersendiri (bukan filter merah di atas tema gelap,
> karena filter merusak hierarki dan membuat status SOS tak bisa dibedakan).
>
> **⟳ REVISI (19 Jul 2026, pasca Brand Identity Audit): default diubah ke
> GELAP** oleh pemilik — karakter brand dashboard menang atas argumen
> keterbacaan siang. Empat tema tetap; yang berubah hanya default instalasi
> pertama. Konsekuensi yang diterima sadar: pemakaian perdana di bawah
> matahari dimulai dari tema tergelap; mitigasi = switch tema mudah
> dijangkau, tidak terkubur di Pengaturan (wajib Fase 3).

## D5. Seberapa agresif sambung otomatis

### Opsi 1 — Sambung otomatis penuh

Node tersimpan → sambung tanpa bertanya. Satu node baru ditemukan →
sambung tanpa bertanya.

**Kelebihan:** benar-benar nol ketukan; pengalaman terbaik di lapangan.
**Kekurangan:** kalau ada dua tim beroperasi berdekatan, relawan bisa
tersambung ke node tim lain tanpa sadar.

### Opsi 2 — Otomatis hanya untuk node tersimpan

Node baru selalu perlu konfirmasi sekali.

**Kelebihan:** aman dari salah sambung; setelah pairing pertama tetap nol
ketukan selamanya.
**Kekurangan:** pemakaian pertama butuh satu ketukan.

### Opsi 3 — Selalu konfirmasi

**Kelebihan:** paling terkendali dan paling mudah dijelaskan.
**Kekurangan:** melanggar prinsip nol-ketukan; menambah friksi setiap kali
aplikasi dibuka ulang.

**Catatan saya:** Opsi 2 adalah keseimbangan yang tepat. Risiko salah sambung
di Opsi 1 kecil tapi konsekuensinya buruk dan sulit didiagnosis relawan.

> **✅ Keputusan: Opsi 2 — otomatis hanya untuk node tersimpan.**
> Node baru dikonfirmasi sekali, lalu disimpan ke penyimpanan lokal dan
> disambung otomatis selamanya. Pengaturan menyediakan "Lupakan node ini".

## D6. Layar navigasi ke korban

### Opsi 1 — Layar penuh terpisah

Buka dari detail node, keluar dari peta sepenuhnya.

**Kelebihan:** informasi arah dan jarak sangat besar dan terbaca sambil
berjalan; nol gangguan.
**Kekurangan:** relawan kehilangan konteks peta; harus bolak-balik untuk
melihat rintangan.

### Opsi 2 — Lapisan di atas peta

Panah kompas besar mengambang di atas peta yang tetap terlihat.

**Kelebihan:** arah dan konteks medan terlihat bersamaan; tidak ada
perpindahan layar.
**Kekurangan:** lebih padat; panah harus tetap terbaca di atas latar peta
yang ramai — ini masalah kontras yang tidak sepele.

### Opsi 3 — Keduanya, bisa ditukar

Default lapisan; ketuk panah untuk membesar jadi layar penuh.

**Kelebihan:** memenuhi dua kebutuhan berbeda: orientasi dan pendekatan akhir.
**Kekurangan:** paling banyak kerjanya; satu mode lagi untuk diuji.

> **✅ Keputusan: Opsi 2 — lapisan kompas di atas peta.**
> Konsekuensi yang tidak sepele: panah dan angka jarak harus tetap lolos
> kontras WCAG AA di atas latar peta yang ramai, di **empat** tema. Ini
> diselesaikan dengan pelat latar semi-buram di belakang elemen kompas,
> bukan dengan menebalkan garis luar — garis luar gagal di peta bertekstur.

---

# STEP 4 — RENCANA REDESIGN UI

## 4.1 Lapisan token (fondasi, dikerjakan lebih dulu)

Sumber kebenaran tunggal: satu berkas token yang menghasilkan konstanta Dart
**dan** custom property CSS. Tidak ada warna yang boleh ditulis langsung di
layar mana pun.

### Warna — semantik, bukan nama warna

Aturan Tactical: **warna hanya menyampaikan status.** Warna dekoratif dilarang.

| Token | Makna | Catatan |
|---|---|---|
| `status.critical` | SOS aktif | Hanya untuk SOS. Tidak boleh dipakai untuk hal lain. |
| `status.warning` | sinyal lemah, baterai rendah | |
| `status.ok` | online, sehat | |
| `status.inactive` | offline, tidak diketahui | Netral, bukan merah. |
| `surface.*` | latar, kartu, kartu-menonjol | 3 tingkat, tidak lebih |
| `content.*` | teks utama, sekunder, redup | 3 tingkat, tidak lebih |
| `accent` | aksi utama | Satu saja |

Setiap token wajib punya nilai untuk setiap tema, dan wajib lolos kontras
**WCAG AA (4.5:1)** di semua tema. Ini diverifikasi, bukan dikira-kira.

**Masalah yang diselesaikan:** 40+ warna hardcoded yang tersebar
(`Colors.grey[100]`, `Colors.black87`, `Colors.orange`) yang semuanya akan
rusak saat dark mode dinyalakan.

### Tipografi

Perbaiki dulu bug yang ada: `fontFamily: 'Inter'` dideklarasikan tapi font-nya
tidak pernah didaftarkan di `pubspec.yaml`, jadi tidak pernah dimuat.

Skala dibatasi **6 tingkat**, tidak lebih. Angka status (jarak, bearing,
koordinat) memakai varian *tabular* agar tidak bergoyang saat berubah cepat —
detail kecil yang sangat terasa profesional.

### Spacing & radius

Skala 4pt: `4 · 8 · 12 · 16 · 24 · 32`. Radius **dua nilai saja**: `8` untuk
elemen kecil, `16` untuk kartu.

**Masalah yang diselesaikan:** saat ini ada enam gaya kartu berbeda
(radius 12/16/20/24, elevation 0/4, dengan dan tanpa border). Ini penyebab
tunggal terbesar kesan "prototipe".

### Ukuran sentuh

Minimum **56dp** untuk semua target, permanen dan tanpa pengecualian.
Bukan setting.

## 4.2 Komponen inti

`PremiumCard` dihapus dan diganti `SurfaceCard` — nama yang menjelaskan
fungsi, bukan mengklaim kualitas. Bayangan diambil dari token (di tema gelap,
kedalaman disampaikan lewat perbedaan permukaan, bukan bayangan hitam yang
tidak terlihat).

Komponen baru yang dibutuhkan:

| Komponen | Dipakai di |
|---|---|
| `StatusPill` | status node, izin, koneksi — menggantikan 4 gaya badge berbeda |
| `NodeCard` | daftar node, bottom sheet, hasil pencarian |
| `SignalMeter` | kualitas sinyal, RSSI |
| `BatteryMeter` | status baterai node |
| `EmptyState` | 5 layar yang sekarang punya gaya kosong berbeda-beda |
| `FailureCard` | seluruh kegagalan koneksi (kamus error) |
| `SosBanner` | interupsi SOS |

## 4.3 Rencana per layar

| Layar | Tindakan |
|---|---|
| **Koneksi** | Dirombak total. Nol ketukan, mesin status jelas, kamus error, auto-reconnect. Animasi denyut 1500ms dihapus (melanggar aturan animasi ≤200ms). String-replace nama ANCHORPULSE→POINTRESCUE dihapus, diperbaiki di firmware. |
| **Peta** | Jadi layar utama. Tambah: posisi pengguna, marker bisa diketuk berlabel, kontrol peta, penanda SOS menonjol, peta offline. |
| **Detail node** (baru) | Rumah bagi sinyal, baterai, hop, riwayat, "Saya tangani", "Navigasi ke sini". Tanpa layar ini fitur-fitur tersebut tidak punya tempat. |
| **Navigasi/kompas** (baru) | Lihat ❓D6. |
| **Daftar node** | Tidak lagi jadi tab; jadi bottom sheet. Kartu benar-benar bisa diketuk (sekarang `InkWell` memberi efek riak tapi tidak melakukan apa pun). |
| **Chat** | Preset satu ketuk + teks bebas. Status kirim per pesan (mengirim/terkirim/gagal + coba lagi). Batas diubah dari 100 karakter jadi 100 **byte** sesuai firmware. Tambalan `margin bottom: 24` dihapus. |
| **Pengaturan** | Sakelar tema yang benar-benar berfungsi (sekarang `onChanged: (val) {}`). Bahasa. Peta offline. Tentang. |
| **Developer Mode** | 12 menu placeholder dihapus. Diganti 4 tool yang benar-benar bekerja. |

## 4.4 Gerak

Durasi: `100ms` mikro, `200ms` transisi. Tidak ada yang lebih lama.
Animasi hanya dipakai untuk: perubahan status, kedatangan data, menjaga
orientasi saat berpindah layar. Tidak ada animasi dekoratif, tidak ada
animasi berulang tanpa henti.

Pengecualian tunggal: **denyut SOS**, karena di situ gerakan menyampaikan
urgensi dan itu fungsional.

Semua gerak menghormati `prefers-reduced-motion` / pengaturan aksesibilitas
sistem.

---

# STEP 5 — URUTAN PENGERJAAN

Satu fitur per waktu, menunggu persetujuan di tiap fase.

## Fase 0 — Perbaikan P0 (tanpa perubahan visual)

Tujuan: aplikasi berhenti berbohong dan berhenti macet.

1. Kunci tombol scan — status kembali ke `idle` saat scan selesai
2. Deteksi & auto-reconnect saat koneksi putus + peringatan nyata
3. Kamus error menggantikan `e.toString()`
4. Node GATEWAY bisa muncul (heartbeat boleh membuat node baru)
5. Node yang restart tidak lagi jadi hantu (perbaiki logika `seq`)
6. Status Online berhenti berbohong (timer peluruhan)
7. Batas chat 100 byte, bukan 100 karakter
8. Status kirim chat (mengirim/terkirim/gagal)

**Catatan:** setelah fase ini aplikasi terlihat sama persis, tapi menjadi
bisa dipercaya. Ini fase paling penting di seluruh dokumen.

## Fase 1 — Fondasi

9. Lapisan token + verifikasi kontras
10. Pendaftaran font (memperbaiki Inter yang tidak pernah dimuat)
11. Komponen inti (`SurfaceCard`, `StatusPill`, `EmptyState`, `FailureCard`)
12. Arsitektur rute + deep link (prasyarat notifikasi SOS)
13. Infrastruktur i18n (ID default, EN opsional)

## Fase 2 — Alur

14. **[UTANG DARI 0A]** Peringatan koneksi putus: getar + alarm + banner
    persisten. Fase 0A memperbaiki logikanya tapi sengaja tidak menambah
    peringatan apa pun demi mematuhi aturan "tanpa perubahan UI di Fase 0".
    **Sampai butir ini selesai, P0 #2 belum benar-benar tertutup** — relawan
    dengan HP di saku masih bisa melewatkan koneksi yang putus.
15. Layar koneksi baru (nol ketukan)
16. Peta jadi rumah + posisi pengguna + marker interaktif
17. Bottom sheet daftar node
18. Layar detail node
19. Chat: preset + status kirim

## Fase 3 — Tema

20. Terang · Gelap · Malam-merah · Ikuti sistem (default: **Gelap** —
    revisi pasca-audit brand; switch tema wajib mudah dijangkau)
21. Audit kontras setiap layar di keempat tema

## Fase 4 — Keandalan lapangan

22. Foreground service
23. Peta offline (pre-download)
24. Persistensi misi
25. Auto-reconnect lanjutan

## Fase 5 — Fitur

26. SOS interupsi penuh (+ aturan sekali per korban per episode)
27. Kompas navigasi
28. "Saya tangani" (tipe paket baru — butuh perubahan firmware)
29. Kualitas sinyal & kesehatan mesh
30. Status baterai node (field `bat` — butuh perubahan firmware)
31. Mission Timeline
32. Ekspor PDF/GPX

## Fase 6 — Developer Mode

33. Live Log Viewer
34. Raw Packet Inspector
35. Mock Data Generator
36. BLE & Link Diagnostics

## Fase 7 — Dashboard web

37. **[UTANG DARI 0B]** Pindahkan dua perbaikan 0B ke `dashboard/serial_listener.py`:
    heartbeat boleh membuat node baru (baris 223-233), dan deteksi reboot
    menggantikan `seq <= prev` (baris 248-252). Sampai ini dikerjakan, mobile
    dan dashboard **tidak sepakat** tentang node mana yang ada — HP menampilkan
    GATEWAY, dashboard tidak. Perbedaan itu diharapkan, bukan regresi.
38. Terapkan token yang sama ke `dashboard/style.css`
39. Selaraskan komponen dan bahasa

---

# LAMPIRAN A — Keputusan yang sudah dikunci

| Topik | Keputusan |
|---|---|
| Nama produk | POINTRESCUE untuk semuanya; ANCHORPULSE dipensiunkan |
| Permukaan | Mobile (relawan SAR) + Dashboard (posko), satu design system |
| Arah visual | Tactical-Utilitarian |
| Animasi | Fungsional saja, ≤200ms |
| Bahasa | Dwibahasa, default Indonesia |
| Ergonomi | 56dp permanen, bukan setting |
| Skala | 5–20 node |
| Data | Riwayat misi tersimpan |
| Firmware | Bebas diubah, semua node bisa di-flash |
| SOS | Interupsi penuh, sekali per korban per episode |
| Navigasi ke korban | Kompas bearing + jarak |
| Chat | Preset + teks bebas |
| Developer Mode | 4 tool berfungsi, placeholder dihapus |
| Navigasi (D1) | 3 tab: Peta · Chat · Pengaturan |
| Daftar node (D2) | Bottom sheet 3 posisi, wajib bisa dicapai lewat ketukan |
| SOS (D3) | Full-screen intent, dengan jalur mundur bila izin ditolak |
| Tema (D4) | 4 tema, default Terang |
| Auto-connect (D5) | Otomatis hanya untuk node tersimpan |
| Kompas (D6) | Lapisan di atas peta |

# LAMPIRAN B — Yang ditolak dari brief awal

Heatmap, Route Prediction, Mission Playback, Geofence, Weather Overlay,
Task Assignment, Resource Allocation, Emergency Broadcast, Checkpoint Manager,
Node Analytics, Victim Priority, Medical Information, Elevation Profile,
dan sekitar 15 lainnya.

Alasan: aplikasi 2.000 baris dengan 28 fitur setengah jadi akan terasa
**lebih murah**, bukan lebih profesional. Kesan mahal datang dari sedikit
hal yang tuntas, bukan dari kelengkapan.

Butir-butir ini tidak dibuang selamanya — hanya ditunda sampai fondasinya
kokoh dan fitur inti benar-benar selesai.
