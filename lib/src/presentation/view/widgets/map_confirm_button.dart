import 'package:flutter/material.dart';
import '../../location_picker_theme.dart';

class MapConfirmButton extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final LocationPickerTheme theme;

  const MapConfirmButton({
    super.key,
    required this.onTap,
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a beautiful gradient using the theme's primary color
    final primary = theme.primaryColor;
    final darkerPrimary = Color.lerp(primary, Colors.black, 0.25) ?? primary;

    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, darkerPrimary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textLightColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
