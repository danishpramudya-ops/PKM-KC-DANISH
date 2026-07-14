# Fitur Pengukuran Jarak Antar Node

Fitur ini menghitung dan menampilkan jarak antar node di dashboard. Seluruhnya
**murni front-end** (di `dashboard/script.js`) — tidak mengubah firmware maupun
pipeline serial. Kode inti ada di section `FITUR JARAK ANTAR NODE` pada `script.js`.

---

## 1. Metode: haversine (great-circle)

Jarak dihitung dari koordinat GPS (`latitude`, `longitude`) tiap node memakai
rumus **haversine** dengan radius bumi 6.371.000 m:

```js
haversine(lat1, lng1, lat2, lng2) -> meter
```

Akurasi ~beberapa meter untuk jarak pendek-menengah — memadai untuk skenario SAR.
Format tampilan otomatis: `< 1000 m` → `"850 m"`, `>= 1000 m` → `"1.28 km"`.

> Alternatif estimasi via RSSI (kekuatan sinyal) sengaja **tidak** dipakai:
> perlu ubah firmware, dan hasilnya jauh lebih kasar/tidak stabil dibanding GPS.

---

## 2. Node yang ikut dihitung

- **GATEWAY (base):** tidak punya GPS, jadi ditampilkan sebagai marker **base
  tetap** pada koordinat yang diset di `CONFIG.GATEWAY_BASE` (`script.js`).
  Nilai saat ini: `-7.940706768120514, 112.61834472963696`. Base ikut dalam
  matriks & mode ukur.
- **SAR & KORBAN:** node lapangan ber-GPS yang sedang **online** (ada update
  < 10 detik) dan punya koordinat numerik.

Jadi jarak yang berguna—mis. "SAR-1001 ↔ KORBAN-2001" atau "KORBAN → base"—
selalu terukur.

---

## 3. Dua cara memakai

### a. Panel "Jarak Antar Node" (tabel matriks)
Di kolom kanan. Menampilkan **semua pasangan** node berposisi beserta jaraknya,
di-update tiap siklus fetch (1 detik). Pasangan **terdekat** disorot hijau
(label "Terdekat"). **Klik satu baris** → garis pasangan itu digambar di peta dan
peta otomatis di-fit ke kedua titik.

### b. Mode ukur di peta (klik 2 node)
Tombol **"Ukur Jarak"** di pojok kanan-atas peta.
1. Klik tombol → mode aktif (kursor jadi crosshair, muncul hint).
2. Klik **node pertama** (marker apa pun, termasuk base) → node ditandai lingkaran.
3. Klik **node kedua** → garis putus-putus oranye + label jarak muncul di tengah.
4. Ulangi untuk pasangan lain; tombol **bersihkan** (ikon `layers_clear`) menghapus
   garis.

Saat mode ukur **mati**, klik marker berperilaku normal (membuka panel detail).

---

## 4. Penanda data tidak valid

Node yang mengirim `gps_valid=false` (belum dapat fix GPS → memakai koordinat
*dummy* dari firmware) diberi badge **`EST`** di tabel, dan labelnya di peta diberi
tanda `*`. Artinya jaraknya hanya estimasi, jangan dijadikan patokan operasional
sampai node mendapat fix GPS asli.

---

## 5. Mengubah lokasi base Gateway

Edit di `dashboard/script.js`:

```js
GATEWAY_BASE: {
    id: 'GATEWAY-0',
    label: 'GATEWAY (Base)',
    latitude: -7.940706768120514,
    longitude: 112.61834472963696,
},
```

Ganti `latitude`/`longitude` sesuai posisi posko sebenarnya, lalu muat ulang
halaman.

---

## 6. Batasan

- Jarak adalah **garis lurus great-circle**, bukan jarak tempuh medan (tidak
  memperhitungkan bukit/sungai/jalan).
- Ketinggian (`altitude`) tidak dimasukkan ke perhitungan — selisih elevasi jauh
  lebih kecil dari jarak horizontal pada skenario umum.
- Hanya node **online** yang masuk matriks; node offline tidak dihitung agar tidak
  menampilkan jarak dari posisi basi.
