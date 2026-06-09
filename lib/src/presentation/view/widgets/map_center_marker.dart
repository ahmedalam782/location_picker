import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../location_picker_theme.dart';

class MapCenterMarker extends StatelessWidget {
  final bool isMoving;
  final LocationPickerTheme theme;

  const MapCenterMarker({
    super.key,
    required this.isMoving,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: isMoving ? 40 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/location_mark.svg',
              package: 'osm_location_picker',
              width: 45,
              height: 45,
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isMoving ? 16 : 10,
              height: isMoving ? 6 : 4,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(
                  alpha: isDark ? 0.55 : 0.30,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
