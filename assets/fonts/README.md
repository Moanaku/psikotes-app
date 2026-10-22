# Font

Instrument Sans (lisensi OFL, lihat `OFL.txt`), dibundel agar aplikasi tidak mengunduh apa pun saat jalan.
Terdaftar di `pubspec.yaml` dengan nama keluarga `InstrumentSans` (sama dengan `AppType.family`).

| Berkas | Bobot |
|---|---|
| `InstrumentSans-Regular.ttf` | 400 |
| `InstrumentSans-Medium.ttf` | 500 |
| `InstrumentSans-SemiBold.ttf` | 600 |
| `InstrumentSans-Bold.ttf` | 700 |

Asal: repo Google Fonts (`ofl/instrumentsans`) hanya menyediakan font variabel `InstrumentSans[wdth,wght].ttf`.
Keempat berkas statis dibuat darinya dengan `fontTools.varLib.instancer` (wdth 100; wght 400, 500, 600, 700).
Tidak ada perubahan pada glyph. Nama keluarga di tabel `name` disetel ke "Instrument Sans".
