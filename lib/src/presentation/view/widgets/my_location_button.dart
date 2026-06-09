import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../location_picker_theme.dart';

class MyLocationButton extends StatelessWidget {
  final VoidCallback onTap;
  final LocationPickerTheme theme;

  const MyLocationButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 20,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.cardColor,
            shape: BoxShape.circle,
            boxShadow: [theme.fabShadow],
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/my_location.svg',
              package: 'location_picker',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
