import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

TestProfile profile({bool aktif = true}) => TestProfile(
      id: 1,
      nama: 'QA, CCAT-style',
      role: ProfileRole.qa,
      formatTes: TestFormat.ccat,
      aktif: aktif,
      blueprint: ProfileTemplates.blueprint(ProfileRole.qa, TestFormat.ccat),
      dibuat: appNow,
    );

/// Stream profil yang tidak pernah mengeluarkan data (masih memuat).
class NeverRepository extends FakeProfileRepository {
  @override
  Stream<List<TestProfile>> watchAll() =>
      StreamController<List<TestProfile>>().stream;
}

/// Stream profil yang langsung galat.
class BrokenRepository extends FakeProfileRepository {
  @override
  Stream<List<TestProfile>> watchAll() =>
      Stream.error(StateError('database rusak'));
}

void main() {
  group('belum ada profil: semua rute selain onboarding ke S01', () {
    testWidgets('/ membuka S01', (tester) async {
      final app = await pumpApp(tester);
      expect(app.location, '/onboarding/role');
      expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
    });

    for (final path in [
      '/psikotes',
      '/statistik',
      '/buku-kesalahan',
      '/pengaturan',
      '/capture',
      '/sesi/3',
      '/hasil/3',
      '/wawancara',
    ]) {
      testWidgets('$path dialihkan ke S01', (tester) async {
        final app = await pumpApp(tester);
        await app.go(path);
        expect(app.location, '/onboarding/role');
        expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
      });
    }

    for (final path in [
      '/onboarding/role',
      '/onboarding/profil',
      '/onboarding/diagnostik',
    ]) {
      testWidgets('$path tetap terbuka', (tester) async {
        final app = await pumpApp(tester);
        await app.go(path);
        expect(app.location, path);
      });
    }

    testWidgets('sesudah profil pertama tersimpan, rute lain terbuka',
        (tester) async {
      final app = await pumpApp(tester);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/diagnostik');
      await app.go('/psikotes');
      expect(app.location, '/psikotes');
    });
  });

  group('sudah ada profil aktif', () {
    testWidgets('/ tetap di beranda', (tester) async {
      final app =
          await pumpApp(tester, profiles: FakeProfileRepository([profile()]));
      expect(app.location, '/');
    });

    testWidgets('rute onboarding tetap terbuka (profil tambahan, ubah profil)',
        (tester) async {
      final app =
          await pumpApp(tester, profiles: FakeProfileRepository([profile()]));
      await app.go('/onboarding/role');
      expect(app.location, '/onboarding/role');
      expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
    });

    testWidgets('profil ada tetapi tidak ada yang aktif: kembali ke onboarding',
        (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([profile(aktif: false)]),
      );
      expect(app.location, '/onboarding/role');
    });
  });

  group('status profil belum pasti', () {
    testWidgets('masih memuat: tidak dialihkan', (tester) async {
      final app = await pumpApp(tester, profiles: NeverRepository());
      await app.go('/psikotes');
      expect(app.location, '/psikotes');
    });

    testWidgets('galat membaca: tidak dialihkan ke onboarding', (tester) async {
      final app = await pumpApp(tester, profiles: BrokenRepository());
      await app.go('/psikotes');
      expect(app.location, '/psikotes');
    });
  });

  testWidgets('provider profil aktif mengikuti perubahan repository',
      (tester) async {
    final repo = FakeProfileRepository();
    final app = await pumpApp(tester, profiles: repo);
    expect(app.container.read(activeProfileProvider).value, isNull);
    await repo.save(profile());
    await tester.pumpAndSettle();
    expect(app.container.read(activeProfileProvider).value?.nama,
        'QA, CCAT-style');
    expect(app.container.read(profileRepositoryProvider), same(repo));
  });
}
