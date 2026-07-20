# Sistem Komponen Mobile — POINTRESCUE

Status: **menunggu persetujuan** · Spesifikasi visual: artifact "sistem-komponen-v4"

Dokumen ini menetapkan kosakata komponen mobile. Ia mengikat Fase 2 dan
seterusnya.

---

## 1. Masalah yang diselesaikan

Prototipe Stitch (21 layar) punya warna yang konsisten tapi **komponen yang
tidak konsisten** — sebab strukturalnya: Stitch menghasilkan tiap layar secara
terpisah, tanpa pustaka komponen bersama. Warna mudah konsisten (sekadar daftar
hex); komponen tidak, karena tiap layar mengarang polanya sendiri.

Bukti terukur dari prototipe:

| Layar | Temuan |
|---|---|
| Node Detail | **5 kartu, 5 tata letak internal berbeda** (grid 2×2, angka+bar, diagram batang, 2 kolom, progress bar). Tidak satu pun diulang. |
| Node Detail | 4 tombol setara diberi **4 bobot visual berbeda** |
| Tactical Map | **6 elemen mengambang** dengan bentuk/radius/ukuran berbeda |
| Lintas layar | Baterai muncul sebagai `92% ▮▮▮▮` di peta, `78%` + bar di detail — **2 bahasa untuk 1 hal** |

Sebaliknya, dashboard laptop terasa solid karena seluruh tampilan informasinya
dibangun dari **empat atom** yang diulang (diverifikasi dari `style.css`):
`stat-card`, `detail-item`, `device-item`, `connection-status`. Panel kanannya
adalah **satu baris yang sama diulang enam kali** (Latitude, Longitude,
Altitude, Speed, Satellites, Last Update).

## 2. Aturan yang mengikat

> Sebuah layar **hanya boleh dirakit dari atom yang sudah disetujui**.
> Butuh pola baru? Ia harus jadi atom baru — dinamai, didefinisikan, dan
> dipakai **minimal di dua tempat**. Kalau hanya dipakai sekali, itu bukan
> komponen; itu dekorasi, dan dibuang.

Konsekuensi praktis saat review: **setiap elemen di layar harus bisa disebut
nama atomnya.** Kalau tidak bisa, elemen itu tidak lolos.

## 3. Delapan atom

| # | Atom | Status | Asal | Kontrak |
|---|---|---|---|---|
| 1 | `DataRow` | **baru (Fase 2)** | `detail-item` | Ubin ikon + label kecil huruf besar + nilai **mono**. Semua data numerik di seluruh aplikasi memakai ini. Tanpa pengecualian. |
| 2 | `StatCard` | **baru (Fase 2)** | `stat-card` | Ikon + angka mono besar + label. Hanya hitungan sekilas. Maks 3 berdampingan. |
| 3 | `NodeRow` | **baru (Fase 2)** | `device-item` | Ubin peran + nama + meta mono + pill + chevron. Satu-satunya cara menampilkan node dalam daftar. |
| 4 | `MeterBar` | **baru (Fase 2)** | — | Satu bahasa untuk semua kuantitas (sinyal, baterai, progres). Menggantikan 3 bahasa bar yang berbeda. |
| 5 | `StatusPill` | ✅ ada (F3a) | `connection-status` | 4 pasangan token: ok · kritikal · peringatan · nonaktif. Warna **hanya** menyampaikan status. |
| 6 | `SurfaceCard` | ✅ ada (F3a) | — | Wadah tunggal. Radius 16, border 1px, tanpa bayangan hitam. |
| 7 | `EmptyState` | ✅ ada (F3a) | — | Ikon + judul + sub + aksi opsional. Bahasa relawan, bukan bahasa mesin. |
| 8 | `FailureCard` | ✅ ada (F3a) | — | Konsumen `ConnectionFailure`: pesan manusia + **satu** aksi. |

Ditambah `SectionHeader` (label kecil huruf besar berspasi) sebagai satu-satunya
pemisah seksi — tanpa garis dekoratif, tanpa ikon judul.

### Varian — bukan atom baru

| Varian | Basis | Perbedaan |
|---|---|---|
| `TimelineRow` | `DataRow` | ubin ikon → titik status; label → waktu mono |
| `ChecklistRow` | `DataRow` | ubin ikon → kotak centang |

Keduanya berasal dari ide bagus di prototipe Stitch. Struktur, tinggi baris, dan
tipografinya identik dengan `DataRow` — inilah bukti disiplin bekerja: ide bagus
bertahan tanpa menambah kosakata.

## 4. Aturan tambahan yang diturunkan

- **Satu tombol primer per layar.** `ActionButton` punya 4 bobot: primer oranye ·
  bahaya bergaris · sekunder · teks. Tinggi 56dp (teks 44dp).
- **Teks di atas oranye selalu navy-deep `#0A1E42`**, tidak pernah putih
  (putih = 2,98:1, gagal WCAG).
- **Data yang belum ada di protokol digambar redup + berlabel fase**, tidak
  pernah diisi angka contoh. Menampilkan angka palsu = melanggar prinsip #1.
- **Elemen mengambang di peta maksimum 2 kelompok**: chip status + tumpukan
  tombol peta.

## 5. Keputusan atas prototipe Stitch

**Diambil (digambar ulang dengan atom kita):**
- Panel LoRa Link (QUAL/SNR/SF) → `DataRow` + `MeterBar`
- Incident Timeline → `TimelineRow`
- Emergency Checklist → `ChecklistRow`

**Dibuang:**

| Elemen | Alasan |
|---|---|
| Login · Registrasi · Recovery Access · Select Role | **Tidak ada server.** Tidak ada akun untuk didaftarkan, tidak ada kata sandi untuk dipulihkan. Empat layar ini mustahil dibangun. |
| 5 tab → 3 tab | Keputusan D1. Dashboard & Nodes hidup sebagai bottom sheet di atas peta. |
| Tombol SOS mengambang | Aplikasi mobile **menerima** SOS; pemicunya tombol fisik node KORBAN (`CLAUDE.md`). |
| Angka penuh (78%, −72 dBm, SF 9) | Belum ada di protokol sampai Fase 5. |
| Ikon "@" di header | Aset pin resmi wajib dipakai (identitas-brand.md §2). |
| Foto laptop sebagai latar peta | Placeholder; nyatanya tile OSM. |

## 6. Peta layar: 21 prototipe → 11 nyata

Prototipe **tidak dibuang** — disesuaikan. Yang gugur hanya yang tidak mungkin
dibangun.

| Prototipe | Jadi | Catatan |
|---|---|---|
| Official Splash | ✅ Splash | wordmark + pin + strip |
| Onboarding ×3 | ✅ Onboarding ×3 | tak butuh server; radar & ilustrasi dipertahankan |
| Operator Registration | ❌ | **tidak ada server** — tak ada akun/kata sandi/sesi |
| Recovery Access | ❌ | idem |
| Secure Login | ❌ | idem |
| Verification Success | ❌ | idem |
| Select Mission Role | ❌ | peran ditentukan **firmware** (ID 0/1xxx/2xxx), bukan pengguna |
| Mission Preparation | ✅ → Izin & kesiapan | diubah jadi pemeriksaan nyata: izin BLE/lokasi, GPS, baterai HP |
| Scanning for Gateways | ✅ Koneksi | jadi nol-ketukan; radar sweep dipertahankan |
| Pairing Device | ✅ Konfirmasi node baru | sekali per node (keputusan D5) |
| Ready for Mission | ❌ digabung | tersambung → langsung peta |
| Mission Control Dashboard | ✅ → sheet posisi penuh | **System Health** & **Recent Activity** diambil utuh |
| Tactical Mission Map | ✅ Peta (rumah) | mengambang 6→2; tombol SOS dibuang |
| Live Tracking | ❌ digabung | sama dengan peta + sheet |
| Node Detail | ✅ Detail node | 5 tata letak → satu DataRow |
| Team & Victim Mgmt | ✅ → sheet + filter peran | segmented jadi filter **SAR/Korban/Gateway** |
| Communication Center | ✅ Chat | + preset satu ketuk |
| Emergency Response & SOS | ✅ Interupsi SOS | checklist & timeline diambil |
| Shader | — | artefak Stitch |

### Konsep "Misi" harus jujur

Prototipe menampilkan `OPERATION NIGHTHAWK`, durasi `04:22:15`, fase
*Sector Alpha*, progres **65%**, dan **T-minus**. Tidak satu pun bisa dihitung:
tidak ada server yang mendefinisikan misi, tidak ada target untuk
dipersentasekan, tidak ada tenggat untuk dihitung mundur.

Yang **bisa** jujur dan karena itu dipakai: waktu sejak tersambung, jumlah node
per peran, umur paket terakhir, status BLE/LoRa/GPS. Sisanya dibuang — bukan
karena jelek, tapi karena menampilkannya berarti berbohong (prinsip #1).

### Diambil utuh dari prototipe

- **System Health** (LoRa · GPS · BLE) — data nyata, sangat berharga
- **Recent Activity** → `TimelineRow`
- **Filter peran** (TEAMS/VICTIMS/RESOURCES → SAR/Korban/Gateway)
- **Emergency Checklist** → `ChecklistRow`
- **Panel LoRa Link** → `DataRow` + `MeterBar`

## 7. Dampak ke rencana

`docs/strategi-ux.md` Fase 2 bertambah satu butir di awal: **tulis 4 atom baru
+ widget test** sebelum layar mana pun dibangun. Urutannya jadi:
komponen → layar, bukan sebaliknya.

Prototipe Stitch turun pangkat dari "cetak biru" menjadi **referensi tata letak
dan ide fitur**. Nilainya tetap nyata — tiga idenya masuk produk.
