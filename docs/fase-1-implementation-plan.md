# Fase 1 — Implementation Plan: Fondasi

Status: **disetujui — keputusan D-F1..D-F4 terkunci; kode belum dimulai,
menunggu go eksplisit (dan hasil uji hardware Fase 0 untuk butir F4/F5)**

Ruang lingkup: lapisan token, tipografi, komponen inti, arsitektur rute,
dan infrastruktur i18n — fondasi yang di atasnya Fase 2 (alur) dan Fase 3
(tema) dibangun. Rujukan keputusan: `docs/strategi-ux.md`.

---

## 0. Hubungan dengan validasi hardware Fase 0 — dibaca dulu

Fase 0 selesai di branch `fase-0-reliability` (13 commit) dan **belum
divalidasi hardware** (M1–M11, N1–N9, P1–P9 dijadwalkan malam ini/besok).

**Analisis dependensi: Fase 1 hampir seluruhnya bebas hardware.**

| Butir Fase 1 | Sentuh BLE/LoRa? | Sentuh berkas Fase 0? |
|---|---|---|
| F1 Token + verifikasi kontras | ❌ | ❌ (berkas baru + `app_theme.dart`) |
| F2 Font | ❌ | ❌ (`pubspec.yaml` + aset) |
| F3 Komponen inti | ❌ | ❌ (berkas baru di `widgets/`) |
| F4 Rute + deep link | ❌ | ⚠️ `app.dart` (lihat bawah) |
| F5 i18n | ❌ | ⚠️ `app.dart` + semua layar (string) |

**Satu-satunya titik singgung: `app.dart`** — Fase 0 (C4) menaruh listener
`myNodeId` di sana; F4/F5 juga mengubahnya (router + localization delegates).
Kalau uji hardware menemukan bug C4, perbaikannya harus mendarat di kode
yang belum tercampur Fase 1.

**Mitigasi proses (bukan pilihan — dijalankan):**
1. Tag `fase-0-rc1` di commit terakhir Fase 0 **sebelum** kode Fase 1
   dimulai. Uji hardware berjalan pada tag itu; hasilnya tidak ambigu.
2. Kode Fase 1 di branch baru `fase-1-fondasi` dari tag tersebut.
3. Urutan pengerjaan Fase 1 diatur agar **berkas-baru dulu** (F1 token,
   F3 komponen, uji kontras — nol risiko konflik), dan **F4/F5 yang
   menyentuh `app.dart` dikerjakan terakhir**, idealnya setelah hasil uji
   hardware masuk.

Tidak ada keputusan arsitektur Fase 1 yang bergantung pada hasil uji
lapangan. Satu-satunya yang menunggu hasil uji adalah *timing* penggabungan,
bukan desain.

---

## 1. Audit fondasi saat ini (angka terukur)

| Metrik | Sekarang | Target Fase 1 |
|---|---|---|
| Referensi warna di `presentation/` | **89** (60 `AppColors.*` + 29 `Colors.*` mentah) | 0 mentah; semua lewat token |
| Konstanta warna semantik | 7, light-only, tanpa varian tema | ~14 token × 4 tema, kontras terverifikasi |
| Ukuran huruf berbeda | **9** (10,11,12,13,14,16,18,24,32) | **6** (skala tetap) |
| Radius berbeda | **6** (4,8,12,16,20,24) | **2** (8 kecil, 16 kartu) |
| `withOpacity` usang | 36 | 0 (migrasi ke token/`withValues`) |
| Font terdaftar | 0 — `fontFamily: 'Inter'` bohong, jatuh ke Roboto | 1 font nyata + varian tabular |
| Tema | 1 (light), switch Settings mati | 4 + switch berfungsi (switch-nya Fase 3) |
| Rute | `MaterialPageRoute` manual, tanpa nama | Router terpusat + deep link |
| i18n | String hardcoded campur ID/EN | Infrastruktur + ID lengkap |

---

## 2. F1 — Lapisan token

### Struktur (dari strategi-ux.md §4.1, dikonkretkan)

Berkas baru `mobile/lib/core/theme/app_tokens.dart`:

```dart
/// Satu tema = satu set nilai untuk SEMUA token. Tidak ada warna lain
/// yang boleh dirujuk layar/widget selain lewat kelas ini.
class AppTokens {
  // Permukaan — 3 tingkat, tidak lebih
  final Color surfaceBase;      // latar layar
  final Color surfaceRaised;    // kartu
  final Color surfaceOverlay;   // sheet/dialog/pill

  // Konten — 3 tingkat, tidak lebih
  final Color contentPrimary;
  final Color contentSecondary;
  final Color contentMuted;

  // Status — HANYA untuk menyampaikan keadaan (aturan Tactical)
  final Color statusCritical;   final Color statusCriticalSurface;
  final Color statusWarning;    final Color statusWarningSurface;
  final Color statusOk;         final Color statusOkSurface;
  final Color statusInactive;   final Color statusInactiveSurface;

  // Aksi utama — satu saja
  final Color accent;           final Color onAccent;
  ...
}
```

Kontrak per token: `statusX` adalah warna teks/ikon dan **wajib lolos 4.5:1**
di atas ketiga surface; `statusXSurface` adalah tint latar pill/badge, dan
pasangan (`statusX` di atas `statusXSurface`) juga wajib 4.5:1. Ini membunuh
pola `color.withOpacity(0.1)` yang sekarang dipakai 36 kali dan tak pernah
diverifikasi kontrasnya.

`AppColors` lama **tidak langsung dihapus** — nasibnya diputuskan di ❓D-F3
(strategi migrasi).

### Nilai awal per tema

Nilai di bawah adalah titik berangkat; **penentu akhirnya adalah uji kontras
otomatis** (§2.3) — kalau sebuah nilai gagal, nilai yang digeser sampai lolos,
bukan ujinya yang dilonggarkan.

| Token | Terang (default) | Gelap | Malam-merah |
|---|---|---|---|
| surfaceBase | `#FFFFFF` | `#0C1118` | `#000000` |
| surfaceRaised | `#F1F4F8` | `#161D27` | `#160404` |
| surfaceOverlay | `#E4E9F0` | `#1F2937` | `#240808` |
| contentPrimary | `#0B1220` | `#E8EDF4` | `#FF6B5E` |
| contentSecondary | `#3D4A5C` | `#ADBACB` | `#D6544A` |
| contentMuted | `#5B6B7F` | `#8494A7` | `#A84640` |
| statusCritical | `#B91C1C` | `#F87171` | *(inversi — lihat bawah)* |
| statusWarning | `#8A5800` | `#FBBF24` | `#FF9E80` |
| statusOk | `#166B3F` | `#4ADE80` | `#FFB4A8` |
| statusInactive | `#64748B` | `#7C8B9D` | `#8F3B36` |
| accent | `#1A4E8A` | `#7FB3E8` | `#FF8A80` |

**Masalah desain Malam-merah yang harus diselesaikan, bukan dihindari:**
di tema serba-merah, merah kehilangan makna "bahaya" — SOS tenggelam.
Solusi: di Malam-merah, `statusCritical` memakai **inversi blok**, bukan
warna: teks nyaris-putih `#FFE4E0` di atas `statusCriticalSurface #7F1D1D`.
Satu-satunya elemen terang di layar = SOS. Justru lebih menonjol daripada
di tema lain. (Ini alasan keputusan D4 melarang filter merah di atas tema
gelap — filter membuat SOS tak terbedakan.)

⚠️ **Ketegangan jujur — ❓D-F4:** WCAG AA (4.5:1) menuntut kecerahan yang
justru merusak adaptasi mata gelap — tujuan keberadaan mode malam. Kontras
dan night-vision bertarung secara fisika, tidak bisa dua-duanya menang penuh.

### Sumber token & dashboard (diputuskan, bukan ❓)

Dart adalah sumber kebenaran (`app_tokens.dart`); mobile adalah permukaan
utama. Derivasi CSS custom property untuk dashboard ditunda ke **Fase 7**
(dashboard belum disentuh sampai itu) — strukturnya sudah dirancang agar
bisa diekspor mekanis (flat, tanpa referensi runtime). Alternatif JSON +
codegen dua arah ditolak untuk sekarang: menambah tooling build pada proyek
dua-permukaan kecil, bisa dipasang belakangan tanpa membongkar apa pun
karena strukturnya sudah flat.

### 2.3 Verifikasi kontras — otomatis, bukan kira-kira

Berkas baru `mobile/test/core/theme/contrast_test.dart`: hitung rasio
kontras WCAG (relative luminance) murni matematika untuk **setiap pasangan
wajib** di **setiap tema**:

- `contentPrimary/Secondary/Muted` × `surfaceBase/Raised/Overlay`
- setiap `statusX` × ketiga surface, dan × `statusXSurface`-nya
- `onAccent` × `accent`

Uji gagal = build merah. Nilai token tidak pernah bisa "kelihatannya cukup".

---

## 3. F2 — Tipografi

Skala 6 tingkat (nama fungsional, bukan ukuran):

| Token | Ukuran/berat | Menggantikan |
|---|---|---|
| `display` | 28 / w800 | 32 (judul connect) |
| `title` | 20 / w700 | 24, 18 |
| `body` | 16 / w500 | 16, 14 |
| `label` | 13 / w600 | 13, 12 |
| `caption` | 11 / w500 | 11, 10 |
| `data` | 15 / w600 **tabular** | angka jarak/koordinat/RSSI — tidak bergoyang saat berubah |

Font itu sendiri = ❓D-F1. Apa pun pilihannya: deklarasi `fontFamily` yang
bohong hari ini dihapus/dijujurkan, dan `data` memakai
`FontFeature.tabularFigures()`.

---

## 4. F3 — Komponen inti

Empat komponen (sesuai butir 11 strategi; SignalMeter/BatteryMeter/NodeCard/
SosBanner menunggu datanya ada — Fase 2/5):

| Komponen | Menggantikan | Kontrak |
|---|---|---|
| `SurfaceCard` | `PremiumCard` + 5 gaya kartu liar | radius 16, surface dari token, TANPA bayangan hardcoded; target sentuh ≥56dp bila interaktif |
| `StatusPill` | 4 gaya badge berbeda (Online/SOS/izin/versi) | pasangan `statusX`+`statusXSurface`, radius 8 |
| `EmptyState` | 5 empty state berbeda gaya | ikon + judul + sub + aksi opsional; bahasa manusia, bukan jargon mesin |
| `FailureCard` | snackbar error + teks kosong campur aduk | konsumen `ConnectionFailure`: pesan + satu tombol aksi |

Komponen dibangun sebagai **berkas baru** dengan widget test masing-masing —
layar lama belum dimigrasi di sub-fase ini (❓D-F3 menentukan kapan).

---

## 5. F4 — Arsitektur rute + deep link

Kebutuhan pendorong (dari keputusan terkunci D3/Fase 5): notifikasi SOS
full-screen harus bisa membuka `detail korban` langsung dari layar terkunci
→ rute harus bisa dialamatkan (`/node/2001`), bukan `MaterialPageRoute`
anonim seperti sekarang.

Pilihan mekanisme = ❓D-F2. Apa pun pilihannya, kontrak yang dikunci:
- Peta rute terpusat di satu berkas (`core/routing/`)
- `ConnectScreen` dan `HomeShell` jadi rute bernama
- Rute detail-node dipesan sejak sekarang (`/node/:id`) walau layarnya
  baru dibangun Fase 2 — supaya Fase 5 tinggal menembak alamat

---

## 6. F5 — i18n

Mekanisme: **gen-l10n resmi Flutter** (flutter_localizations dari SDK + ARB).
Diputuskan tanpa ❓: nol dependensi pihak ketiga, didukung tooling resmi,
dan kebutuhan kita sederhana (dua bahasa, tanpa pluralisasi rumit).

- `app_id.arb` (default) + `app_en.arb`
- Fase 1 memasang infrastruktur + memigrasi string **layar yang ada**
  (~40 string; termasuk membereskan campur bahasa "Granted/Permanently
  Denied" di Settings yang sudah dicatat sejak audit awal)
- Kamus `ConnectionFailure` ikut dimigrasi — sudah terpusat sejak 0A-C2,
  persis untuk momen ini
- Switch bahasa di Settings = Fase 3 (bersama switch tema); Fase 1 hanya
  default ID

---

## 7. Urutan pengerjaan & commit

Diurutkan berkas-baru-dulu (aman terhadap hasil uji hardware yang belum masuk):

| # | Butir | Sentuh kode lama? |
|---|---|---|
| F1a | `app_tokens.dart` + 4 tema + uji kontras | ❌ |
| F3a | `SurfaceCard`, `StatusPill`, `EmptyState`, `FailureCard` + widget test | ❌ |
| F2 | Font (sesuai ❓D-F1) + skala tipe di token | `pubspec.yaml`, `app_theme.dart` |
| F1b | `ThemeData` dibangun dari token (light dulu; 3 tema lain menyusul switch di Fase 3) | `app_theme.dart` |
| **⏸ GERBANG** | **Tunggu hasil uji hardware Fase 0 sebelum menyentuh `app.dart`** | |
| F4 | Router + rute bernama | `app.dart`, layar |
| F5 | gen-l10n + migrasi string | `app.dart`, semua layar |
| F3b | Migrasi layar ke komponen/token (sesuai ❓D-F3) | layar |

Rollback: F1a/F3a murni aditif — revert satu commit tanpa jejak. F4/F5
per-commit seperti Fase 0.

---

## 8. Pengujian

Semuanya otomatis, nol hardware:
- Uji kontras (§2.3) — gerbang nilai token
- Widget test 4 komponen (render, target sentuh ≥56dp, teks pill)
- `flutter analyze` baseline BARU: setelah F1b/F3b, 36 `deprecated_member_use`
  harus turun drastis (migrasi withOpacity) — angka target dicatat saat F3b
- Widget test lama tetap lulus; bila teks berubah karena i18n, uji ikut
  dimigrasi ke kunci l10n **di commit yang sama**

---

## 9. Acceptance Criteria Fase 1

- [ ] F-AC1 — Empat set token lengkap; uji kontras lulus untuk semua pasangan wajib di 4 tema
- [ ] F-AC2 — Nol `Colors.*` mentah baru; jalur menuju nol total tercatat di ❓D-F3
- [ ] F-AC3 — Font nyata terdaftar; tidak ada `fontFamily` yang tidak dimuat
- [ ] F-AC4 — `data` style terbukti tabular (widget test lebar digit)
- [ ] F-AC5 — 4 komponen inti + widget test; `PremiumCard` punya jalur pensiun tercatat
- [ ] F-AC6 — Rute bernama + `/node/:id` terdaftar; navigasi lama tetap berfungsi
- [ ] F-AC7 — App berjalan penuh dalam ID dari ARB; tiada string UI hardcoded di layar yang dimigrasi
- [ ] F-AC8 — `flutter analyze` bersih dari issue BARU; `flutter test` hijau
- [ ] F-AC9 — Tag `fase-0-rc1` dibuat sebelum commit kode Fase 1 pertama
- [ ] F-AC10 — Perubahan `app.dart` (F4/F5) baru dimulai setelah hasil uji hardware Fase 0 masuk, ATAU pemilik proyek eksplisit menerima risiko merge

---

## 10. Keputusan (sudah diambil — alternatif tetap terdokumentasi)

> **✅ D-F1: Opsi A — bundle Inter penuh, 4 berat (w500/w600/w700/w800),**
> dari rilis resmi rsms/inter (SIL OFL). Deklarasi `fontFamily` yang bohong
> dijadikan nyata, `data` style memakai tabular figures Inter.
>
> **✅ D-F2: Opsi A — go_router.** Satu dependensi resmi tim Flutter.
> Guard "belum tersambung → Connect" dan rute `/node/:id` deklaratif.
>
> **✅ D-F3: Opsi A — migrasi per-alur di Fase 2.** F3b DIBATALKAN dari
> urutan §7; `AppColors` & `PremiumCard` hidup sampai layar terakhir yang
> memakainya dirombak di Fase 2, lalu dihapus.
>
> **✅ D-F4: Opsi A — Malam-merah: AA 4.5:1 untuk contentPrimary +
> statusCritical (+ pasangan inversinya), AA-Large 3:1 untuk
> contentSecondary/Muted & status non-kritikal.** Ambang per-tema
> di-hardcode di contrast_test.dart dengan komentar alasan — pengecualian
> beraturan, bukan kelonggaran diam-diam.

### ❓D-F1 — Font

**Opsi A — Bundle Inter (rsms/inter, SIL OFL, gratis).**
Niat asli kode (deklarasi sudah ada, cuma bohong). Tabular figures kelas
atas, rupa profesional netral. Biaya: ~0.9–1.2 MB aset (4 berat), perlu
mengunduh sekali dari rilis resmi GitHub.

**Opsi B — Roboto sistem, dijujurkan.**
Hapus deklarasi bohong, pakai default Android secara sadar. Nol byte, nol
unduhan, tersedia hari ini; Roboto juga punya tabular figures. Biaya:
identitas visual "bawaan Android" — lebih sulit terasa "expensive
professional software" yang jadi tujuanmu.

**Opsi C — Bundle Inter subset (2 berat: regular + bold).**
Kompromi ukuran (~500 KB), w500/w600/w800 disintesis atau dibulatkan ke
berat terdekat. Biaya: hierarki berat yang dirancang di skala tipe jadi
lebih tumpul.

### ❓D-F2 — Mekanisme rute

**Opsi A — `go_router` (dependensi pub resmi Flutter team, gratis).**
Standar de-facto; deep link + full-screen intent Fase 5 jadi jalur yang
sudah dites jutaan app; guard/redirect deklaratif (mis. "belum tersambung →
lempar ke Connect"). Biaya: satu dependensi baru; sedikit kurva belajar.

**Opsi B — `onGenerateRoute` manual, nol dependensi.**
Navigator 1.0 bernama, parsing `/node/:id` ditulis sendiri (~60 baris).
Cukup untuk 5–7 rute kita. Biaya: deep link dari notifikasi & state
restoration ditulis dan diuji sendiri di Fase 5 — persis bagian yang paling
rawan salah.

**Opsi C — Tunda routing ke Fase 2.**
Fase 1 murni token/komponen/i18n. Biaya: Fase 2 membangun layar di atas
navigasi lama lalu memigrasinya — kerja dua kali; deep link makin dekat ke
Fase 5 makin sempit ruang uji.

### ❓D-F3 — Kapan layar lama bermigrasi ke token/komponen

**Opsi A — Per-alur di Fase 2 (sesuai roadmap asli).**
Tiap layar dirombak Fase 2 memakai fondasi baru; layar yang belum dirombak
tetap tampil lama. Paling aman terhadap hasil uji hardware; dua sistem visual
hidup berdampingan beberapa minggu.

**Opsi B — Jembatan mekanis di akhir Fase 1 (F3b).**
`AppColors` di-redirect ke nilai token terang + `PremiumCard` jadi pembungkus
tipis `SurfaceCard`; layar tak diedit, tampilan bergeser minimal (radius
20→16, bayangan→token). Satu sistem sejak awal; Fase 3 tinggal audit satu
sistem. Risiko: perubahan visual kecil menyeluruh terjadi SEBELUM redesign
per-layar — dan menyentuh semua layar tepat saat hasil uji hardware belum
tentu bersih.

### ❓D-F4 — Kontras Malam-merah

**Opsi A — AA ketat (4.5:1) untuk semua token, termasuk Malam-merah.**
Konsisten, satu aturan, uji seragam. Biaya: mode malam jadi lebih terang
dari yang seharusnya — mengorbankan sebagian tujuan night-vision.

**Opsi B — Malam-merah: AA untuk primer + kritикal, AA-Large (3:1) untuk
sekunder/muted.** Jujur pada fisika: mode malam memprioritaskan adaptasi
mata; konten sekunder memang sengaja diredupkan. Uji kontras tetap otomatis,
ambangnya saja yang per-tema. Biaya: satu pengecualian beraturan yang harus
didokumentasikan (dan dipertahankan di review).
