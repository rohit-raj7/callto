import 'package:flutter/material.dart';

class RecentChatSkeleton extends StatelessWidget {
  const RecentChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final fg = scheme.surfaceContainerHighest;
    final border = Theme.of(context).dividerColor.withOpacity(0.12);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: DecoratedBox(
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 12, width: MediaQuery.of(context).size.width * 0.5, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 16,
            decoration: BoxDecoration(
              color: fg,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
