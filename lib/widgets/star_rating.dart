import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Read-only star row for an average rating (e.g. 4.3) - renders full,
/// half, and empty stars rather than rounding to the nearest whole star,
/// since "4.3" and "4.8" both rounding to "★★★★★" would be misleading.
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;

  const StarRatingDisplay({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final threshold = i + 1;
        IconData icon;
        if (rating >= threshold) {
          icon = Icons.star;
        } else if (rating >= threshold - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: AppColors.gold);
      }),
    );
  }
}

/// Interactive 1-5 star picker for submitting a rating - tapping a star
/// sets the rating to that star's position.
class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
            size: size,
            color: AppColors.gold,
          ),
          tooltip: '$starValue star${starValue == 1 ? '' : 's'}',
          onPressed: () => onChanged(starValue),
        );
      }),
    );
  }
}
