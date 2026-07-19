# Fase 0B — Implementation Plan: Truthful Node State

Status: **menunggu persetujuan — belum ada kode yang diubah**

Ruang lingkup: `NodeRepository` dan `NodeStatus` berhenti memberi informasi
palsu tentang node mesh. Tidak ada perubahan protokol, tidak ada perubahan
tampilan.

Batasan keras sama persis dengan Fase 0A — lihat `docs/fase-0-handoff.md` §4.

---

## 1. Ringkasan perubahan

| # | Perubahan | Berkas | Ukuran |
|---|---|---|---|
| B4 | Konstanta terpusat | `ble_constants` | Kecil |
| B1 | Node GATEWAY bisa muncul | `node_repository` | Kecil |
| B2 | Node yang restart tidak lagi jadi hantu | `node_repository`, `ble_constants` | Sedang |
| B3 | Status "Online" meluruh sesuai waktu | `node_repository` | Sedang |

Urutan commit: `B4 → B1 → B2 → B3`

---

## 2. B1 — Node GATEWAY bisa muncul

### Tujuan
Node yang hanya mengirim heartbeat harus tetap terlihat oleh relawan.

### Mengapa diperlukan
`node_repository.dart:57-63`:

```dart
if (packet.isHeartbeat) {
  if (existing != null) {
    existing.touch();
    notifyListeners();
  }
  return;                    // ← node baru dibuang
}
```

Heartbeat hanya me-*refresh* node yang **sudah pernah terlihat**. Kalau node
belum pernah dikenal, paketnya dibuang diam-diam.

Tapi `CLAUDE.md` menyatakan GATEWAY **tidak pernah** menyiarkan lokasi — ia
hanya mengirim heartbeat tiap 10 detik. Maka GATEWAY secara struktural
**mustahil** muncul di daftar node. Node paling penting di jaringan tidak
terlihat sama sekali oleh relawan.

Hal yang sama berlaku untuk node SAR atau KORBAN yang belum mendapat fix GPS —
mereka tetap mengirim heartbeat, tapi tidak akan terlihat sampai GPS terkunci.
Relawan tidak punya cara tahu bahwa rekannya menyala tapi belum dapat sinyal
satelit.

### Verifikasi firmware
Diperiksa langsung, bukan diasumsikan: `point_rescue_SAR.ino:450` memanggil
`bleNotifyMeshPacket(raw)` untuk **semua** tipe paket, termasuk heartbeat.
Jadi paket heartbeat memang sudah sampai ke HP. Perbaikannya murni di sisi
aplikasi — **nol perubahan firmware**.

### Berkas & simbol
`mobile/lib/data/repositories/node_repository.dart` → `_onRawPacket()`

### Alur lama vs baru

**Lama**
```
heartbeat masuk → node sudah dikenal?  ya → refresh presence
                                       tidak → BUANG
```

**Baru**
```
heartbeat masuk → node sudah dikenal?  ya → refresh presence
                                       tidak → BUAT node (tanpa posisi)
```

Node yang dibuat dari heartbeat punya `lat`/`lng` bernilai `null`, sehingga:
- **Tidak muncul di peta** — `positionedNodes` menyaring `hasPosition`. Benar,
  karena kita memang tidak tahu di mana ia berada.
- **Muncul di daftar node** dengan teks "Belum ada data lokasi". Benar, karena
  kita tahu ia hidup.

### Detail penting: heartbeat tidak boleh menyentuh `seq`

`touch()` hanya memperbarui `lastSeen`, **tidak** menulis `seq`. Perilaku ini
harus **dipertahankan**.

Alasannya: firmware memakai satu `seqCounter` untuk semua tipe paket. Kalau
heartbeat ikut menaikkan `seq` tersimpan, paket TRACKING yang datang belakangan
lewat jalur multi-hop yang lebih lambat bisa punya `seq` lebih kecil dan akan
ditolak sebagai duplikat — posisi node jadi berhenti diperbarui.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Node yang terdengar sekali lalu hilang akan menetap sebagai entri offline | Ini **jujur** — kita memang pernah mendengarnya. B3 akan menandainya offline. Pembersihan entri lama masuk Fase 2. |
| Daftar node jadi lebih panjang dari sebelumnya | Memang itu tujuannya. Skala 5–20 node, tidak ada masalah performa. |
| Node dengan role tak dikenal ikut muncul | `roleNameFromId` sudah mengembalikan "UNKNOWN". Filter `net` di baris 51 sudah menolak jaringan lain. |

### ⚠️ Divergensi dengan dashboard
`dashboard/serial_listener.py:223-233` punya bug yang **sama persis** —
heartbeat dari node yang belum dikenal diabaikan (`[DEBUG-SKIP] heartbeat …
belum pernah ada posisi, diabaikan`). Jadi GATEWAY juga tidak terlihat di
dashboard command center.

Setelah B1, **mobile dan dashboard akan berbeda**: HP menampilkan GATEWAY,
dashboard tidak. Lihat `docs/fase-0-handoff.md` §11 untuk keputusan soal ini.

---

## 3. B2 — Node yang restart tidak lagi jadi hantu

### Tujuan
Node yang menyala kembali setelah reboot harus langsung terlihat hidup.

### Mengapa diperlukan
`node_repository.dart:65-67`:

```dart
if (existing != null && packet.seq <= existing.seq) {
  return;
}
```

Firmware memulai `seqCounter` dari 0 setiap kali boot. Setelah node reboot —
karena baterai dilepas, watchdog, atau crash — semua paketnya punya `seq` kecil
dan **ditolak seluruhnya** sampai `seq` menyusul nilai lama yang tersimpan.

Node yang menyala, mengirim posisi, dan berfungsi normal akan tampil **"Offline"
berjam-jam**. Relawan menyimpulkan rekannya masih hilang padahal perangkatnya
baru saja pulih. Ini persis kebalikan dari yang dibutuhkan.

Masalah ini sudah dikenali di `saran-tindaklanjut.txt` butir B2, dengan solusi
yang benar: field `epoch` (boot counter) di paket. **Itu perubahan protokol,
dilarang di Fase 0.** Maka 0B memakai heuristik sisi aplikasi.

### Berkas & simbol
- `mobile/lib/data/repositories/node_repository.dart` → `_onRawPacket()`
- `mobile/lib/core/constants/ble_constants.dart` → `rebootSeqGap`, `rebootSilence`

### Alur lama vs baru

**Lama**
```
seq <= seq tersimpan → BUANG (selalu)
```

**Baru**
```
seq <= seq tersimpan → apakah ini terlihat seperti reboot?
    gap = seq_tersimpan − seq_paket
    silence = sekarang − lastSeen

    gap >= rebootSeqGap (5)          → ya, reboot → terima, reset baseline
    silence > rebootSilence (2 menit) → ya, reboot → terima, reset baseline
    selain itu                        → duplikat asli → BUANG
```

### Mengapa dua syarat, bukan satu
Syarat **gap** menangkap kasus umum: node berjalan lama (`seq` sudah puluhan
atau ratusan) lalu reboot ke 0. Selisihnya besar dan jelas.

Syarat **silence** menangkap kasus sulit: node reboot saat `seq` masih kecil,
misalnya `seq` tersimpan 3 lalu reboot ke 0. Gap-nya hanya 3, di bawah ambang.
Tanpa syarat kedua, empat paket pertama akan tetap dibuang.

### Batas yang diketahui dan diterima
Kalau node reboot dengan `seq` tersimpan yang kecil **dan** jeda diamnya
singkat, beberapa paket pertama tetap terbuang sampai `seq` melewati nilai
lama. Penundaannya terbatas — maksimum `rebootSeqGap` paket, sekitar 20 detik
pada laju TRACKING 5 detik. Ini **jauh lebih baik** dari kondisi sekarang
(berjam-jam) dan diterima sebagai batas heuristik. Perbaikan menyeluruh butuh
field `epoch` di firmware.

### Nilai konstanta
```dart
static const int      rebootSeqGap  = 5;
static const Duration rebootSilence = Duration(minutes: 2);
```

`rebootSeqGap = 5` dipilih karena duplikat multi-hop yang sah biasanya
tertinggal 1–3 nomor (hop limit maksimum adalah 5). Ambang 5 memberi ruang
aman tanpa membuka celah bagi duplikat asli.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Duplikat asli lolos dan mengembalikan posisi lama | Ambang 5 di atas hop limit terbesar; posisi lama yang lolos akan langsung ditimpa paket berikutnya dalam 5 detik |
| Paket rusak dengan `seq` acak dianggap reboot | `net` sudah difilter; JSON rusak sudah ditolak di baris 44. Dampaknya paling buruk satu posisi salah yang segera terkoreksi. |
| Reboot tidak terdeteksi saat `seq` kecil dan jeda singkat | Diterima. Terbatas ~5 paket, didokumentasikan di atas. |

### Alternatif yang ditolak
**Buang dedup untuk paket mundur seluruhnya.** Setiap `seq` lebih kecil
dianggap reboot.
*Ditolak:* mematikan deteksi duplikat, yang merupakan inti controlled flooding.
Setiap paket relay akan diproses ulang.

**Dedup berbasis jendela waktu, bukan `seq`.** Simpan `(id, seq)` yang pernah
dilihat dalam N detik terakhir.
*Ditolak untuk Fase 0:* lebih benar secara teori, tapi mengganti mekanisme
dedup sepenuhnya — terlalu besar untuk fase perbaikan bug, dan menyimpang jauh
dari `serial_listener.py`. Kandidat Fase 2.

### ⚠️ Divergensi dengan dashboard
`dashboard/serial_listener.py:248-252` punya bug identik
(`seq <= prev seq → dianggap paket lama/duplikat`). Lihat §11 handoff.

---

## 4. B3 — Status "Online" meluruh sesuai waktu

### Tujuan
Badge "Online" harus berubah jadi "Offline" ketika node benar-benar berhenti
terdengar, tanpa menunggu paket lain masuk.

### Mengapa diperlukan
`node_status.dart:37-38`:

```dart
bool get isOnline =>
    DateTime.now().difference(lastSeen) < BleConstants.offlineTimeout;
```

Nilainya dihitung dari `DateTime.now()` **saat widget dibangun**. Tapi tidak
ada apa pun yang memicu pembangunan ulang saat waktu berlalu — `notifyListeners()`
hanya dipanggil ketika paket masuk.

Skenario nyata: seluruh mesh mati serentak, misalnya relawan berjalan keluar
jangkauan. Tidak ada paket lagi yang masuk, jadi tidak ada `notifyListeners()`,
jadi UI membeku pada keadaan terakhir. Semua node tetap menampilkan badge hijau
**"Online"** dan **"baru saja"** — selamanya.

Aplikasi memberi tahu relawan bahwa seluruh timnya baik-baik saja, tepat pada
saat ia kehilangan kontak dengan semuanya. Ini pelanggaran paling langsung
terhadap prinsip "Jujur tentang keadaan".

### Berkas & simbol
- `mobile/lib/data/repositories/node_repository.dart` → field `Timer? _presenceTimer`,
  konstruktor, `dispose()`
- `mobile/lib/core/constants/ble_constants.dart` → `presenceTick`

### Alur lama vs baru

**Lama**
```
paket masuk → notifyListeners() → UI segar
tidak ada paket → UI membeku pada keadaan terakhir selamanya
```

**Baru**
```
paket masuk → notifyListeners() → UI segar
tiap presenceTick (5 detik) → ada node? → notifyListeners() → isOnline &
                                          teks waktu relatif dihitung ulang
```

### Implementasi
```dart
NodeRepository(this.ble) {
  _sub = ble.meshPacketStream.listen(_onRawPacket);
  _presenceTimer = Timer.periodic(BleConstants.presenceTick, (_) {
    if (_nodes.isEmpty) return;
    notifyListeners();
  });
}
```

`_presenceTimer?.cancel()` wajib ada di `dispose()`.

### Kenapa 5 detik
`offlineTimeout` adalah 60 detik. Tick 5 detik berarti transisi Online→Offline
terlihat paling lambat 5 detik setelah ambang terlampaui — cukup responsif
tanpa berlebihan. Teks waktu relatif ("12 dtk lalu") juga ikut segar.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Membangun ulang UI tiap 5 detik memboroskan baterai | Daftar 5–20 kartu sederhana. Biayanya tak berarti dibanding radio BLE yang menyala terus. |
| Timer tetap jalan setelah repository dibuang | `cancel()` di `dispose()`; `app.dart` sudah memanggil `dispose()` |
| Timer memicu rebuild saat tidak ada node | Guard `if (_nodes.isEmpty) return;` |

### Alternatif yang ditolak
**Hanya beri tahu ketika ada node yang benar-benar berpindah status.**
*Kelebihan:* rebuild lebih sedikit.
*Ditolak:* teks waktu relatif ("2 mnt lalu") juga perlu disegarkan dan tidak
terikat pada perpindahan status, jadi tetap butuh tick periodik. Menambah
logika pembanding tanpa menghapus timer — lebih rumit, tanpa manfaat nyata.

**Jadikan `isOnline` sebuah stream.**
*Ditolak:* mengubah bentuk model dan setiap pemakainya. Terlalu besar untuk
Fase 0.

---

## 5. B4 — Konstanta terpusat

```dart
static const int      rebootSeqGap  = 5;
static const Duration rebootSilence = Duration(minutes: 2);
static const Duration presenceTick  = Duration(seconds: 5);
```

`offlineTimeout` yang sudah ada **tidak diubah** (tetap 60 detik, sama dengan
`CONFIG.OFFLINE_TIMEOUT` di `dashboard/script.js`).

---

## 6. Dampak lintas komponen

| Komponen | Dampak |
|---|---|
| Firmware | **Nihil.** Diverifikasi: heartbeat sudah dikirim ke HP. |
| Protokol / JSON | **Nihil.** |
| Dashboard | **Nihil secara kode.** Tapi menimbulkan divergensi perilaku — lihat §11 handoff. |
| `MapScreen` | GATEWAY tidak akan muncul di peta (tidak punya posisi). Benar dan disengaja. |
| `NodeListScreen` | Akan menampilkan lebih banyak node. Tidak ada perubahan kode. |
| Fase 0A | Tidak ada tumpang tindih berkas. Aman dikerjakan berdampingan. |
| Fase 0C | Tidak ada tumpang tindih berkas. |

---

## 7. Pengujian

### Otomatis
Tidak ada. Sama dengan keputusan Q2 di Fase 0A: `NodeRepository` bergantung
pada stream BLE dan `DateTime.now()`, sehingga pengujiannya menuntut abstraksi
waktu dan transport — refactor arsitektur yang tidak boleh masuk fase
perbaikan bug. Dijadwalkan Fase 1.

### Manual — butuh 1 HP, 1 node SAR, 1 node GATEWAY, 1 node KORBAN

| # | Skenario | Langkah | Hasil yang diharapkan |
|---|---|---|---|
| N1 | **GATEWAY terlihat** | Nyalakan GATEWAY + SAR. Sambungkan HP. Tunggu 15 detik. | GATEWAY muncul di daftar node dengan "Belum ada data lokasi". **Bug utama B1.** |
| N2 | **GATEWAY tidak di peta** | Buka tab Peta. | GATEWAY **tidak** muncul sebagai marker. Benar — posisinya memang tidak diketahui. |
| N3 | **Node tanpa fix GPS** | Nyalakan KORBAN di dalam ruangan (tanpa fix). | Muncul di daftar dalam ~10 detik lewat heartbeat, bukan menunggu GPS terkunci. |
| N4 | **Node restart** | Node KORBAN aktif dan terlihat. Cabut daya, tunggu 5 detik, nyalakan lagi. | Dalam ~10 detik node kembali "Online" dan posisinya diperbarui. **Bug utama B2.** Tanpa perbaikan ini node akan tetap "Offline" berjam-jam. |
| N5 | **Duplikat tetap ditolak** | Jalankan 3 node agar terjadi relay multi-hop. Amati Serial Monitor. | Tidak ada posisi yang melompat mundur. Dedup masih bekerja. |
| N6 | **Peluruhan Online** | Semua node terlihat Online. Matikan **semua** node sekaligus. Jangan sentuh HP. | Dalam 60–65 detik semua badge berubah jadi "Offline" **tanpa interaksi**. **Bug utama B3.** |
| N7 | **Waktu relatif segar** | Lanjutan N6 — amati kolom waktu. | Teks berjalan sendiri: "baru saja" → "12 dtk lalu" → "1 mnt lalu". |
| N8 | **Pulih kembali** | Lanjutan N6 — nyalakan satu node. | Node itu kembali "Online" dalam ~10 detik. |
| N9 | **Regresi 0A** | Putuskan dan sambungkan ulang koneksi BLE. | Daftar node terisi kembali. Timer presence tidak bocor atau ganda. |

---

## 8. Rollback

Empat commit terpisah, saling bebas:
- `B1` — kembalikan satu commit; heartbeat kembali diabaikan
- `B2` — kembalikan satu commit; kembali ke `seq <=` yang ketat
- `B3` — kembalikan satu commit; timer hilang
- `B4` — hanya konstanta; aman

Nol perubahan pada firmware, protokol, atau dashboard berarti pengembalian
penuh tidak mungkin memutus kompatibilitas apa pun.

---

## 9. Acceptance Criteria

- [ ] AC-B1 — Node GATEWAY muncul di daftar node dalam 15 detik (N1)
- [ ] AC-B2 — GATEWAY **tidak** muncul di peta (N2)
- [ ] AC-B3 — Node tanpa fix GPS tetap muncul lewat heartbeat (N3)
- [ ] AC-B4 — Heartbeat **tidak** mengubah `seq` tersimpan (tinjauan kode)
- [ ] AC-B5 — Node yang restart pulih dalam ≤20 detik (N4)
- [ ] AC-B6 — Deteksi duplikat masih menolak relay multi-hop (N5)
- [ ] AC-B7 — Semua node jadi "Offline" dalam ≤65 detik tanpa interaksi (N6)
- [ ] AC-B8 — Teks waktu relatif menyegar sendiri (N7)
- [ ] AC-B9 — `_presenceTimer` dibatalkan di `dispose()` (tinjauan kode)
- [ ] AC-B10 — Nol perubahan visual
- [ ] AC-B11 — Nol perubahan di `firmware/`, `dashboard/`, `docs/protokol-paket.md`
- [ ] AC-B12 — `flutter analyze` bersih
- [ ] AC-B13 — Divergensi dashboard tercatat di §11 handoff
