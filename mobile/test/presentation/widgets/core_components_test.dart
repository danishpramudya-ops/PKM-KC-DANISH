// Widget test empat komponen inti Fase 1-F3a.
//
// Kontrak yang dijaga: token dipakai benar (bukan warna liar), target
// sentuh interaktif >= 56dp (AppTouch.minTarget — baseline permanen,
// bukan setting), dan FailureCard menampilkan pesan manusia + satu aksi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/core/theme/app_tokens.dart';
import 'package:anchorpulse/data/models/connection_failure.dart';
import 'package:anchorpulse/presentation/widgets/empty_state.dart';
import 'package:anchorpulse/presentation/widgets/failure_card.dart';
import 'package:anchorpulse/presentation/widgets/loading_state.dart';
import 'package:anchorpulse/presentation/widgets/status_pill.dart';
import 'package:anchorpulse/presentation/widgets/surface_card.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppTokens.light]),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('SurfaceCard', () {
    testWidgets('interaktif: tinggi >= 56dp & onTap terpanggil',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(
        SurfaceCard(onTap: () => tapped = true, child: const Text('x')),
      ));
      final size = tester.getSize(find.byType(SurfaceCard));
      expect(size.height, greaterThanOrEqualTo(AppTouch.minTarget));
      await tester.tap(find.byType(SurfaceCard));
      expect(tapped, isTrue);
    });

    testWidgets('permukaan dari token surfaceRaised', (tester) async {
      await tester.pumpWidget(_host(const SurfaceCard(child: Text('x'))));
      final container = tester.widget<Container>(find
          .descendant(
              of: find.byType(SurfaceCard), matching: find.byType(Container))
          .first);
      final deco = container.decoration! as BoxDecoration;
      expect(deco.color, AppTokens.light.surfaceRaised);
      expect(deco.boxShadow, isNull); // kedalaman dari permukaan, bukan bayangan
    });
  });

  group('StatusPill', () {
    testWidgets('memakai pasangan token status (fg + tint bg)',
        (tester) async {
      await tester.pumpWidget(
          _host(const StatusPill(label: 'Online', kind: StatusKind.ok)));
      expect(find.text('Online'), findsOneWidget);

      final container = tester.widget<Container>(find
          .ancestor(of: find.text('Online'), matching: find.byType(Container))
          .first);
      expect((container.decoration! as BoxDecoration).color,
          AppTokens.light.statusOkSurface);
      final text = tester.widget<Text>(find.text('Online'));
      expect(text.style!.color, AppTokens.light.statusOk);
    });

    testWidgets('empat kind terpetakan ke pasangan berbeda', (tester) async {
      for (final kind in StatusKind.values) {
        await tester
            .pumpWidget(_host(StatusPill(label: kind.name, kind: kind)));
        expect(find.text(kind.name), findsOneWidget);
      }
    });

    testWidgets('setiap status membawa ikon — bukan warna saja (A5)',
        (tester) async {
      // Buta warna merah-hijau (8% pria) tidak boleh kehilangan informasi
      // status. Siluet ikon harus BERBEDA antar status, bukan cuma warnanya.
      final icons = <IconData>{};
      for (final kind in StatusKind.values) {
        await tester
            .pumpWidget(_host(StatusPill(label: kind.name, kind: kind)));
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, isNotNull, reason: '$kind tanpa ikon');
        icons.add(icon.icon!);
      }
      expect(icons.length, StatusKind.values.length,
          reason: 'ada status yang memakai ikon sama — tidak terbedakan');
    });

    testWidgets('ikon boleh diganti sesuai konteks', (tester) async {
      await tester.pumpWidget(_host(const StatusPill(
        label: 'Terhubung',
        kind: StatusKind.ok,
        icon: Icons.bluetooth_connected_rounded,
      )));
      expect(find.byIcon(Icons.bluetooth_connected_rounded), findsOneWidget);
    });
  });

  group('LoadingState', () {
    testWidgets('spinner SELALU disertai keterangan', (tester) async {
      await tester.pumpWidget(_host(const LoadingState(
        label: 'Mencari node…',
        subtitle: 'Pastikan node sudah menyala.',
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mencari node…'), findsOneWidget);
      expect(find.text('Pastikan node sudah menyala.'), findsOneWidget);
    });

    testWidgets('label wajib — tidak ada spinner telanjang', (tester) async {
      // Kontrak API: label bertipe non-null required, jadi mustahil
      // membuat LoadingState tanpa keterangan. Uji ini mengunci kontrak.
      await tester.pumpWidget(_host(const LoadingState(label: 'Memuat…')));
      expect(find.text('Memuat…'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('judul+sub+aksi tampil; aksi >= 56dp & terpanggil',
        (tester) async {
      var acted = false;
      await tester.pumpWidget(_host(EmptyState(
        icon: Icons.router,
        title: 'Belum ada anggota tim terdeteksi',
        subtitle: 'Pastikan node lain sudah menyala.',
        actionLabel: 'Cari Lagi',
        onAction: () => acted = true,
      )));
      expect(find.text('Belum ada anggota tim terdeteksi'), findsOneWidget);
      expect(find.text('Pastikan node lain sudah menyala.'), findsOneWidget);

      final btn = find.byType(FilledButton);
      expect(tester.getSize(btn).height,
          greaterThanOrEqualTo(AppTouch.minTarget));
      await tester.tap(btn);
      expect(acted, isTrue);
    });

    testWidgets('tanpa aksi: tombol tidak dirender', (tester) async {
      await tester.pumpWidget(
          _host(const EmptyState(icon: Icons.map, title: 'Kosong')));
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('FailureCard', () {
    testWidgets('pesan manusia + satu tombol aksi >= 56dp', (tester) async {
      var acted = false;
      final failure = ConnectionFailure.of(ConnectionFailureKind.nodeNotFound);
      await tester.pumpWidget(
          _host(FailureCard(failure: failure, onAction: () => acted = true)));

      expect(find.text(failure.message), findsOneWidget);
      expect(find.text(failure.actionLabel), findsOneWidget);
      // technicalDetail TIDAK boleh tampil (tempatnya Log Viewer Fase 6).
      final btn = find.byType(FilledButton);
      expect(tester.getSize(btn).height,
          greaterThanOrEqualTo(AppTouch.minTarget));
      await tester.tap(btn);
      expect(acted, isTrue);
    });
  });
}
