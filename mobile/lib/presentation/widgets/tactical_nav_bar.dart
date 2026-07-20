import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool badge;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = false,
  });
}

/// Bilah navigasi bawah bergaya Figma: tab aktif jadi **pill oranye penuh**
/// berisi ikon + label (bukan indикator tipis bawaan Material), sudut atas
/// membulat, dan garis pemisah tipis di atasnya.
///
/// Teks di dalam pill memakai `onAccent` (navy-deep) — bukan putih; putih
/// di atas oranye hanya 2,98:1 dan gagal WCAG.
class TacticalNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;

  const TacticalNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
        border: Border(
          top: BorderSide(color: tokens.contentMuted.withValues(alpha: 0.28)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                _tab(context, tokens, i, items[i]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
      BuildContext context, AppTokens tokens, int index, NavItem item) {
    final selected = index == selectedIndex;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minWidth: 78,
            minHeight: AppTouch.minTarget,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.sm),
          decoration: BoxDecoration(
            color: selected ? tokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 21,
                    color: selected ? tokens.onAccent : tokens.contentMuted,
                  ),
                  if (item.badge && !selected)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.statusCritical,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.surfaceRaised),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: AppType.overline.copyWith(
                  letterSpacing: 1.1,
                  color: selected ? tokens.onAccent : tokens.contentMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
