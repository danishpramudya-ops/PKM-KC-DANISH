# ANCHORPULSE — Penataan Kode + Dashboard + Fitur Jarak (Design Spec)

**Tanggal:** 2026-07-07
**Status:** Disetujui (brainstorming) → siap implementasi

## Tujuan

Menata implementasi referensi yang sudah berfungsi menjadi struktur proyek yang
bersih, memastikan dashboard web lokal berjalan, dan menambahkan **fitur
pengukuran jarak antar node**. Disertai dokumentasi & README lengkap.

Prioritas (dari CLAUDE.md): Reliability > Simplicity > Low Power > Memory > Maintainability > Readability.

## Keputusan yang sudah disepakati

1. **Firmware** — dirapikan & didokumentasikan saja. Logika routing (controlled
   flooding) dan format paket JSON **tidak diubah** (CLAUDE.md: jangan redesign).
2. **Fitur jarak** — model "klik 2 node + tabel matriks live".
3. **Metode jarak** — GPS haversine (great-circle). Tidak ada perubahan firmware
   maupun pipeline serial.
4. **Struktur** — layout bersih baru; `refrence/` menjadi arsip.
5. **Simulator** — sertakan `simulate.py` untuk demo/tes tanpa hardware.
6. **Gateway** — tidak punya GPS, ditampilkan di lokasi base tetap
   `-7.940706768120514, 112.61834472963696` (dikonfigurasi di dashboard).

## Struktur folder target

```
firmware/point_rescue_{GATEWAY,SAR,KORBAN}/*.ino   # dari refrence, dirapikan
firmware/README.md                                  # library, wiring, config, upload
dashboard/index.html · style.css · script.js
dashboard/server.py · serial_listener.py · simulate.py
dashboard/gps.json · dashboard/assets/{logo,poster,stripe}.png
docs/arsitektur-sistem.md · docs/protokol-paket.md · docs/fitur-jarak.md
README.md                                           # panduan end-to-end
refrence/                                           # arsip (tak disentuh)
```

## Fitur jarak — rincian

- `haversine(lat1,lng1,lat2,lng2) -> meter`. Format label: `<1000` → "850 m";
  `>=1000` → "1.28 km".
- **Panel "Jarak Antar Node"** di kolom kanan: tabel semua pasangan node ber-posisi,
  update tiap siklus fetch (1 dtk). Pasangan terdekat disorot. Baris diklik → garis
  pasangan tsb tergambar di peta + peta di-fit.
- **Mode ukur di peta**: tombol toggle. Aktif → klik node A lalu node B → polyline
  putus-putus + label pil jarak di titik tengah. Tombol "bersihkan". Mode mati →
  klik node = buka detail (perilaku lama dipertahankan).
- **Gateway base**: konstanta `GATEWAY_BASE = {lat,lng}` di `script.js`. Gateway
  selalu tampil sebagai marker khusus (ikon berbeda) di titik itu, ikut dihitung
  dalam matriks & mode ukur.
- **Validitas**: node dengan `gps_valid=false` (koordinat dummy) ditandai; jaraknya
  diberi penanda "estimasi" agar tidak disalahartikan.

## Simulator

`simulate.py` menulis node dummy bergerak (beberapa SAR + KORBAN) ke `gps.json`
persis format `serial_listener.py` (`device_id, latitude, longitude, altitude,
speed, satellites, gps_valid, role, seq, is_sos`). Opsi CLI: jumlah node, interval,
trigger SOS. Ditandai jelas sebagai alat pengembangan.

## Pipeline (tidak berubah)

ESP32 (LoRa mesh) → GATEWAY via USB serial → `serial_listener.py` → `gps.json`
→ `server.py` (HTTP no-cache) → browser (`index.html` fetch `gps.json` tiap 1 dtk).

## Testing

- Tanpa hardware: `server.py` + `simulate.py` → buka `http://localhost:8000`,
  verifikasi marker, matriks jarak, mode ukur, banner SOS.
- Verifikasi otomatis: `gps.json` valid JSON, server merespons 200, haversine
  cocok dengan nilai referensi yang diketahui.

## Risiko & mitigasi

- **Regresi dashboard lama** → fitur jarak ditambah sebagai modul terpisah di
  `script.js`; perilaku klik lama tetap saat mode ukur mati.
- **Salah tafsir jarak dummy** → penanda `gps_valid=false`.
- **Duplikasi refrence/ vs firmware/,dashboard/** → disengaja; refrence = arsip.
