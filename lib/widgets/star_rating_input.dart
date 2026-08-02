import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var rating = 1; rating <= 5; rating++)
              _RatingOption(
                rating: rating,
                label: _ratingLabel(rating),
                isSelected: rating <= value,
                onTap: () => onChanged(rating),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 16,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 17 / 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RatingOption extends StatelessWidget {
  const _RatingOption({
    required this.rating,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final int rating;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSelected
                  ? const Color(0xFFEAB308)
                  : const Color(0xFFD8D8DE),
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? AppColors.deepBlue : AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 15 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ratingLabel(int rating) {
  return switch (rating) {
    1 => 'Rất tệ',
    2 => 'Tệ',
    3 => 'Bình thường',
    4 => 'Tốt',
    _ => 'Rất tốt',
  };
}
