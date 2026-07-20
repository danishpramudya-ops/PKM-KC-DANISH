// Widget test empat atom data + SectionHeader (prasyarat Fase 2,
// docs/sistem-komponen.md).
//
// Kontrak yang dijaga: token dipakai lewat pasangan DataTone, nilai selalu
// bergaya mono (JetBrainsMono), target sentuh interaktif >= 56dp, dan
// MeterBar tidak pernah mengarang isi untuk data yang tidak diketahui.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/core/theme/app_tokens.dart';
import 'package:anchorpulse/core/theme/app_type.dart';
import 'package:anchorpulse/presentation/widgets/data_tone.dart';
import 'package:anchorpulse/presentation/widgets/detail_row.dart';
import 'package:anchorpulse/presentation/widgets/meter_bar.dart';
import 'package:anchorpulse/presentation/widgets/node_row.dart';
import 'package:anchorpulse/presentation/widgets/section_header.dart';
import 'package:anchorpulse/presentation/widgets/stat_card.dart';
import 'package:anchorpulse/presentation/widgets/status_pill.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppTokens.light]),
      home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
    );

void main() {
  group('DetailRow', () {
    testWidgets('label huruf besar + nilai mono + tinggi >= 56', (t) async {
      await t.pumpWidget(_host(const DetailRow(
        icon: Icons.place,
        label: 'Latitude',
        value: '-7.953850',
      )));
      expect(find.text('LATITUDE'), findsOneWidget); // di-uppercase otomatis
      final val = t.widget<Text>(find.text('-7.953850'));
      expect(val.style!.fontFamily, 'JetBrainsMono');
      expect(t.getSize(find.byType(DetailRow)).height,
          greaterThanOrEqualTo(AppTouch.minTarget));
    });

    testWidgets('onTap terpanggil', (t) async {
      var tapped = false;
      await t.pumpWidget(_host(DetailRow(
        icon: Icons.speed,
        label: 'Kecepatan',
        value: '0,4 m/s',
        onTap: () => tapped = true,
      )));
      await t.tap(find.byType(DetailRow));
      expect(tapped, isTrue);
    });

    testWidgets('dimmed = redup 50% untuk data yang belum ada', (t) async {
      await t.pumpWidget(_host(const DetailRow(
        icon: Icons.battery_unknown,
        label: 'Baterai',
        value: '—',
        dimmed: true,
      )));
      final op = t.widget<Opacity>(find
          .ancestor(of: find.text('—'), matching: find.byType(Opacity))
          .first);
      expect(op.opacity, 0.5);
    });
  });

  group('StatCard', () {
    testWidgets('angka mono besar + label huruf besar + tone', (t) async {
      await t.pumpWidget(_host(const StatCard(
        icon: Icons.sos,
        value: '1',
        label: 'SOS',
        tone: DataTone.critical,
      )));
      final val = t.widget<Text>(find.text('1'));
      expect(val.style!.fontFamily, 'JetBrainsMono');
      expect(val.style!.fontWeight, FontWeight.w800);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('tiga berdampingan muat di lebar HP', (t) async {
      await t.pumpWidget(_host(const Row(children: [
        Expanded(child: StatCard(icon: Icons.hub, value: '5', label: 'Node')),
        SizedBox(width: 8),
        Expanded(
            child: StatCard(
                icon: Icons.check, value: '4', label: 'Online',
                tone: DataTone.ok)),
        SizedBox(width: 8),
        Expanded(
            child: StatCard(
                icon: Icons.sos, value: '1', label: 'SOS',
                tone: DataTone.critical)),
      ])));
      expect(t.takeException(), isNull); // tanpa overflow
      expect(find.byType(StatCard), findsNWidgets(3));
    });
  });

  group('NodeRow', () {
    testWidgets('nama + meta mono + pill + chevron + tap >= 56dp', (t) async {
      var tapped = false;
      await t.pumpWidget(_host(NodeRow(
        icon: Icons.person_pin_circle,
        name: 'KORBAN-2001',
        meta: '320 m · TL · 5 dtk',
        tone: DataTone.critical,
        trailing: const StatusPill(label: 'SOS', kind: StatusKind.critical),
        onTap: () => tapped = true,
      )));
      expect(find.text('KORBAN-2001'), findsOneWidget);
      final meta = t.widget<Text>(find.text('320 m · TL · 5 dtk'));
      expect(meta.style!.fontFamily, 'JetBrainsMono');
      expect(find.text('SOS'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(t.getSize(find.byType(NodeRow)).height,
          greaterThanOrEqualTo(AppTouch.minTarget));
      await t.tap(find.byType(NodeRow));
      expect(tapped, isTrue);
    });

    testWidgets('tanpa onTap: chevron tidak dirender', (t) async {
      await t.pumpWidget(_host(const NodeRow(
        icon: Icons.router,
        name: 'GATEWAY-0',
        meta: 'Tanpa data lokasi · 8 dtk',
      )));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('MeterBar', () {
    testWidgets('fraction mengisi track sesuai nilai + warna tone', (t) async {
      await t.pumpWidget(_host(const MeterBar(
        label: 'Kualitas link',
        valueText: '78%',
        fraction: 0.78,
        tone: DataTone.ok,
      )));
      final box = t.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox));
      expect(box.widthFactor, closeTo(0.78, 0.001));
      expect(find.text('78%'), findsOneWidget);
    });

    testWidgets('fraction null = track kosong, tidak mengarang isi',
        (t) async {
      await t.pumpWidget(_host(const MeterBar(
        label: 'Baterai node',
        valueText: '—',
        fraction: null,
      )));
      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('huruf besar + gaya overline', (t) async {
      await t.pumpWidget(_host(const SectionHeader('Posisi')));
      final txt = t.widget<Text>(find.text('POSISI'));
      expect(txt.style!.fontSize, AppType.overline.fontSize);
      expect(txt.style!.fontWeight, FontWeight.w800);
    });
  });
}
