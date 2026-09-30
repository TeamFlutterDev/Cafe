import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'web_layout.dart';

/// ✕ button that closes a side panel or drawer on web.
class PanelCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const PanelCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(
        Icons.close_rounded,
        size: 20,
        color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
      ),
    );
  }
}

/// Which window edge a [PanelReopenTab] hugs.
enum PanelEdge { left, right }

/// Small tab stuck to a window edge that brings a closed side panel back —
/// e.g. the POS cart after its ✕ was pressed. Shows an optional count badge
/// so a hidden, non-empty cart is never forgotten.
class PanelReopenTab extends StatelessWidget {
  final PanelEdge edge;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onPressed;

  const PanelReopenTab({
    super.key,
    required this.edge,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(12);
    final isRight = edge == PanelEdge.right;

    return Tooltip(
      message: 'Show $label',
      child: Material(
        color: AppColors.primaryOrange,
        elevation: 4,
        borderRadius: isRight
            ? const BorderRadius.horizontal(left: radius)
            : const BorderRadius.horizontal(right: radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: isRight
              ? const BorderRadius.horizontal(left: radius)
              : const BorderRadius.horizontal(right: radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WebTokens.gap,
              vertical: WebTokens.gap * 1.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                if (count > 0) ...[
                  const SizedBox(height: WebTokens.gap / 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WebTokens.gap / 2 + 2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: WebTokens.gap / 2),
                RotatedBox(
                  quarterTurns: isRight ? 3 : 1,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
