import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../location_picker_theme.dart';

class MapAddressHeader extends StatelessWidget {
  final String addressText;
  final LocationPickerTheme theme;
  final VoidCallback? onTap;

  const MapAddressHeader({
    super.key,
    required this.addressText,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.borderColor,
            width: 0.7,
          ),
          boxShadow: [theme.shadowBox],
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/search.svg',
              package: 'location_picker',
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  addressText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: theme.textDarkColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
