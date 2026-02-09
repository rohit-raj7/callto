import 'package:flutter/material.dart';

class ListenerCardSkeleton extends StatelessWidget {
  const ListenerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final fill = scheme.surfaceContainerHighest;
    final border = Theme.of(context).dividerColor.withOpacity(0.12);
    
    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    // Responsive sizing
    final avatarSize = isSmallScreen ? 48.0 : 56.0;
    final buttonWidth = isSmallScreen ? 90.0 : 110.0;
    final horizontalPadding = isSmallScreen ? 8.0 : 12.0;
    final spacing = isSmallScreen ? 6.0 : 8.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: isSmallScreen ? 10 : 12,
                  height: isSmallScreen ? 10 : 12,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(color: bg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: horizontalPadding),
          
          // Content area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name and verified icon
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: isSmallScreen ? 14 : 16,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                
                // Language/specialty
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        height: isSmallScreen ? 10 : 12,
                        constraints: const BoxConstraints(maxWidth: 120),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing + 2),
                
                // Tags/pills - responsive widths
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _flexiblePill(fill, flex: 3, height: isSmallScreen ? 20 : 24),
                    _flexiblePill(fill, flex: 2, height: isSmallScreen ? 20 : 24),
                    _flexiblePill(fill, flex: 2, height: isSmallScreen ? 20 : 24),
                  ],
                ),
                SizedBox(height: spacing + 2),
                
                // Bottom info row
                Row(
                  children: [
                    Flexible(
                      child: _flexiblePill(fill, flex: 2, height: isSmallScreen ? 20 : 22),
                    ),
                    SizedBox(width: spacing),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isSmallScreen ? 16 : 20,
                            height: isSmallScreen ? 16 : 20,
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              height: isSmallScreen ? 20 : 22,
                              constraints: const BoxConstraints(maxWidth: 60),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: spacing),
          
          // Call button
          Container(
            width: buttonWidth,
            height: isSmallScreen ? 34 : 38,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flexiblePill(Color color, {required int flex, required double height}) {
    return FractionallySizedBox(
      widthFactor: flex / 10,
      child: Container(
        height: height,
        constraints: BoxConstraints(
          minWidth: height * 2,
          maxWidth: flex == 3 ? 90 : (flex == 2 ? 60 : 50),
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
