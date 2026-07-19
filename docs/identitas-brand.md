# Brand Identity Audit — POINTRESCUE

Status: **menunggu persetujuan — belum ada mockup atau UI yang diubah**

Sumber yang dianalisis:
- **Aset resmi** (dinyatakan pemilik sebagai identitas, bukan referensi):
  wordmark POINT RESCUE, logo pin, pattern strip merah-biru
- `POINTRESCUE-PKMKC-DASHBOARD-MAIN-draft/` — `style.css` (2.320 baris),
  `index.html`, `assets/` (logo.png, poster.png, stripe.png, sar-icon.png)
- `mobile/assets/logo.png` — **identik byte-per-byte** dengan pin dashboard
  (70.074 byte, 318×343): pin sudah hidup di kedua permukaan

---

## 1. Apa identitas visual utama POINTRESCUE?

Satu kalimat: **"sinyal yang menemukan"** — pertemuan antara *lokasi*
(pin, gunung, kompas) dan *radio* (gelombang, radar, strip sinyal).
Semua elemen resmi menceritakan kalimat itu:

| Pilar | Wujudnya |
|---|---|
| **Tanda pin-bergelombang** | Pin navy dua-nada berisi gunung, diapit 4 busur gelombang merah→oranye per sisi, titik oranye di ujung jarum. Lokasi + LoRa dalam satu bentuk. |
| **Dwi-warna panas-dingin** | Navy `#153B7A` (institusi, tenang, komando) × merah-oranye `#D32F2F→#F36C21` (darurat, energi, sinyal), dipisah garis putih. Konsisten di pin, wordmark, strip, poster. |
| **Bahasa instrumen** | Poster menggambar brand di atas **mawar kompas + cincin radar**, dengan **garis rute putus-putus**, **matriks titik**, dan **tri-dot navy·merah·oranye**. Ini kanon brand — bukan tambahan desainer UI. Radar-sweep & pulse-dot di dashboard adalah kelanjutan sahnya. |
| **Tagline** | *"Signal Lost, Lives Found"* — terpatri di dalam strip. Aset verbal sekuat aset visual. |
| **Dua atmosfer, satu brand** | Cetak/poster = **terang** (putih + navy/merah). Ruang operasi/dashboard = **gelap taktis** (slate + glow). Keduanya kanon; mobile mewarisi keduanya sebagai tema Terang & Gelap. |

## 2. Yang WAJIB dipertahankan — tidak boleh berubah

1. **Geometri & warna pin** — termasuk detail khasnya: belahan dua-nada
   vertikal, gunung dalam lingkaran putih, dua garis putih (≡), titik
   terpisah di ujung. Tidak digambar ulang, tidak "dirapikan".
2. **Wordmark Aset 1 sebagai gambar** — karakter huruf lompat-lompatnya
   adalah suaranya. Tidak boleh direkonstruksi dengan font + CSS
   (rekonstruksi gradasi di header dashboard sebaiknya kelak diganti
   aset asli juga). Tidak ada teks UI yang meniru gayanya.
3. **Pattern strip** — proporsi garis diagonal merah di atas navy + teks
   tagline putih. Boleh dipotong panjangnya, tidak boleh diubah warnanya.
4. **Bunyi tagline** — *Signal Lost, Lives Found*, tanpa parafrase.
5. **Pasangan navy × oranye** sebagai relasi warna primer brand.
6. **Catatan aturan**: logo dikecualikan dari aturan kontras WCAG
   (logotype exemption) — putih-di-oranye pada wordmark **sah**.
   Pengecualian ini TIDAK menular ke teks UI: tombol dan teks tetap
   tunduk pada uji kontras token.

## 3. Yang boleh dikembangkan tanpa kehilangan identitas

- **Tangga ukuran pin** (wajib dibuat — detail pin lenyap di ukuran kecil):
  | Tingkat | Isi | Pakai di |
  |---|---|---|
  | Penuh | pin + gelombang + titik | splash, hero, empty state |
  | Mark | pin + titik, tanpa gelombang | app icon, header, kartu |
  | Siluet | bentuk pin satu warna | marker peta, tab, chip |
  | Mono | siluet putih flat | ikon notifikasi Android (wajib mono), themed icon |
- **Keluarga marker peta** diturunkan dari siluet pin: isi oranye = SAR,
  merah berdenyut = SOS, navy = posisiku, abu = offline. Satu bentuk
  induk, peran dibedakan warna token.
- **Busur gelombang** diekstrak jadi motif mandiri: indikator memuat,
  animasi mencari, dan kelak indikator kekuatan sinyal.
- **Instrumen poster** (cincin radar, mawar kompas, rute putus-putus,
  matriks titik, tri-dot) sebagai kosakata dekoratif-fungsional.
- **Permukaan gelap slate** dashboard boleh dijadikan lebih tegas
  (lihat §4 — arahan "hindari glassmorphism berlebihan").
- **`sar-icon.png` perlu penyelarasan** ⚠ — helm render lunak
  hijau-putih, satu-satunya aset yang bergaya lain (bukan vektor flat,
  palet asing). Rekomendasi: gambar ulang flat dua-nada navy/oranye,
  atau ganti perannya dengan siluet pin. Menunggu keputusan pemilik.

## 4. Terjemahan ke Design System mobile

Struktur token TIDAK berubah — hanya nilai & perlakuan:

| Lapisan | Keputusan |
|---|---|
| **Warna** | Pemetaan dashboard→token yang sudah disepakati di spek v2, dengan koreksi WCAG tetap berlaku (teks di atas oranye = navy-deep `#0A1E42`, 6,4:1; status digelapkan di tema Terang). Malam-merah tetap (keputusan D4 — dashboard tak punya padanan). |
| **Permukaan** | **"Panel tegas", bukan kaca**: kartu = permukaan solid `#1E293B` + border 1px + sorot-dalam halus. Blur/transparansi HANYA bila tembus-pandangnya fungsional: sheet di atas peta, pelat kompas. Ini koreksi dari spek v2 yang terlalu kaca, sesuai arahan. |
| **Tipografi** | Mobile cukup **2 keluarga**: Inter (UI — sudah dibundel & teruji) + **JetBrains Mono** (data: koordinat, jarak, RSSI — mengikuti dashboard). Poppins & Oswald tidak ikut ke mobile: wordmark adalah gambar, jadi tak ada font yang perlu meniru suara display. 4 keluarga di layar 6" = bising. |
| **Ikonografi** | Material Symbols Rounded — kelanjutan `material-icons-round` dashboard. Ikon brand (pin & turunannya) dari aset, bukan digambar ulang. |
| **Radius** | 16 (kartu/sheet/tombol) & 8 (pill/chip) — subset sah dari 16/12/8 dashboard; mobile tetap 2 nilai demi disiplin. |
| **Gerak** | Hanya yang berfungsi: radar-sweep (= sedang mencari), pulse-dot (= hidup), denyut SOS (= darurat). ≤200ms untuk transisi. Tidak ada dekorasi bergerak lain. |
| **Aset yang perlu diekspor** | Wordmark transparan (belum ada sebagai berkas — dashboard merekonstruksinya dengan CSS), `stripe.png` disalin ke mobile, tangga pin 4 tingkat, app icon adaptif (foreground pin-mark + background navy) + siluet mono. |

## 5. Strip merah-biru: khas tanpa berlebihan

Prinsip: **strip = tanda tangan, bukan wallpaper**. Tanda tangan
ditulis sekali di tempat yang tepat.

**Aturan pakai:**
1. Maksimum **satu strip per layar**.
2. Dua ukuran saja:
   - **Mikro (3–4dp)**: garis aksen tanpa teks — tepi bawah header,
     pembatas seksi penting. Terbaca sebagai "garis brand".
   - **Penuh (20–24dp)** dengan teks tagline terbaca — hanya di momen
     identitas: splash, About, tepi atas banner SOS.
3. **Tidak pernah**: latar penuh, watermark, di belakang teks konten,
   diwarnai ulang, atau dianimasikan berjalan (kecuali satu kali di
   splash — itupun opsional).
4. Peta penempatan: Splash (penuh, kaki layar — persis poster) ·
   Header rumah (mikro) · Banner/layar SOS (penuh, tepi atas — garis
   miring merahnya secara alami berbunyi "darurat") · About (penuh) ·
   Layar lain: **tanpa strip**.

Kekhasan justru lahir dari kelangkaan: pengguna hafal "garis miring
merah-navy itu POINTRESCUE" karena ia hanya muncul di momen bermakna.

## 6. Komponen dashboard yang diwariskan langsung

| Dari dashboard | Jadi di mobile |
|---|---|
| Lockup header (pin + wordmark + subjudul) | Header momen identitas (Connect, About) |
| Chip koneksi + pulse-dot | Chip status BLE di peta (teks jujur 0A-C7 sudah siap) |
| Status pill + titik glow | `StatusPill` (F3a) — tinggal ganti kulit token |
| Stat-card sidebar (nilai besar + label) | Baris ringkasan sheet ("5 node · 1 SOS") |
| Anatomi device-card | `NodeCard` di bottom sheet |
| Radar sweep sidebar | Layar "Mencari node…" |
| Pelat kompas kaca | Pelat kompas navigasi (kaca fungsional) |
| JetBrains Mono untuk data | Gaya `data` |
| Toggle tema | Pengaturan Fase 3 |

## 7. Komponen yang harus menyesuaikan diri di HP

| Dashboard | Kenapa tak bisa langsung | Bentuk mobile-nya |
|---|---|---|
| Sidebar 300px | Tak ada ruang | Bottom tabs (3) + bottom sheet |
| Panel kanan detail 340px | idem | Detail = bottom sheet penuh |
| Header 70px (jam, hitungan device, subjudul) | HP sudah punya jam; tinggi itu mahal | Header ramping: pin-mark + chip koneksi (~56dp); hitungan pindah ke ringkasan sheet |
| Wordmark penuh di header | Terlalu lebar untuk tetap terbaca | Wordmark hanya di momen identitas; header operasional pakai pin-mark |
| Hover states | Tak ada kursor | Pressed state + target 56dp |
| Blur kaca banyak lapis | GPU HP + arahan "jangan berlebihan" | Panel solid tegas; kaca hanya di atas peta |
| Tabel padat multi-kolom | Jempol & lebar layar | Kartu satu kolom, data mono rata |

## 8. Elemen penguat baru (turunan sah dari aset yang ada)

1. **Gelombang = bahasa kekuatan sinyal.** Empat busur pin menjadi
   indikator RSSI brand-native: 4 busur menyala = sinyal kuat, 1 = lemah.
   Elemen paling khas yang bisa dimiliki aplikasi ini — indikator sinyal
   yang merupakan logo itu sendiri. (Datanya menyusul Fase 5; bahasanya
   ditetapkan sekarang.)
2. **Tri-dot navy·merah·oranye** (dari poster) — indikator memuat dan
   pembatas seksi. Kecil, murah, langsung dikenali.
3. **Rute putus-putus oranye** (dari poster) — gaya baku jejak/trail di
   peta. Fungsional sekaligus khas.
4. **Cincin radar + mawar kompas** sebagai latar samar empty-state dan
   layar pencarian — komposisi poster dipakai ulang, bukan motif baru.
5. **App icon**: pin-mark di atas navy (adaptif) + siluet mono untuk
   themed/notification icon — kehadiran brand di homescreen & status bar.
6. **Splash**: komposisi poster diringkas — pin + gelombang menyala
   sekali (fungsional: sedang memuat), tagline, strip di kaki.

---

## Catatan ketegangan yang diselesaikan

**Wordmark ceria vs UI taktis.** Aset 1 bersuara hangat-energik;
ruang operasi bersuara tenang-tegas. Ini bukan konflik — ini pembagian
peran: **wordmark menyapa** (splash, connect, about — momen manusia),
**instrumen bekerja** (peta, sheet, SOS — momen operasi). Poster sendiri
memakai wordmark varian tipografis tegas untuk konteks formal — preseden
bahwa suara boleh menyesuaikan momen selama tanda (pin) dan warna tetap.

## Keputusan pemilik — SEMUA TERJAWAB (19 Jul 2026)

1. ✅ **Tema default instalasi pertama: GELAP** (karakter brand).
   Merevisi keputusan D4 lama (default Terang) — revisi tercatat juga di
   strategi-ux.md. Konsekuensi yang diterima sadar: pemakaian perdana di
   bawah matahari dimulai dari tema tergelap; mitigasi = switch tema
   mudah dijangkau (Fase 3).
2. ✅ **JetBrains Mono dibundel** — dieksekusi (commit `fase-1 F2b`):
   2 berat + lisensi, gaya `data` kini identik dengan dashboard.
3. ✅ **sar-icon.png: digambar ulang flat sesuai brand** — vektor flat
   dua-nada navy/oranye. Ini TUGAS DESAIN ASET di sisi pemilik/desainer
   (di luar kemampuan agen menggambar berkas produksi). Sampai tersedia,
   mobile tidak memakai sar-icon sama sekali; dashboard menyusul Fase 7.
4. ✅ **Wordmark: pemilik menaruh berkas transparan (SVG bila ada) di**
   `POINTRESCUE-PKMKC-DASHBOARD-MAIN-draft/assets/` — saat berkas muncul,
   disalin ke `mobile/assets/brand/` dan placeholder CSS di splash
   diganti. Status saat pemeriksaan terakhir: belum ada.
