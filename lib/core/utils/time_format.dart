/// Format waktu untuk layar: timer sesi dan durasi per soal.
library;

/// "mm:ss" untuk sisa waktu atau durasi sesi; menit tidak dibatasi 59 (sesi
/// paling lama 180 menit).
String formatClock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Kalimat untuk pembaca layar: "14 menit 32 detik".
String spokenDuration(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  if (m == 0) return '$s detik';
  if (s == 0) return '$m menit';
  return '$m menit $s detik';
}

/// Detik per soal untuk teks "Waktumu 31 dtk": dibulatkan, paling sedikit 1.
int secondsOf(int milliseconds) =>
    (milliseconds / 1000).round().clamp(1, 1 << 30);
