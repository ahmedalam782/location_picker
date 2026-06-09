import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../location_picker_theme.dart';

class LocationPickerErrorWidget extends StatelessWidget {
  final Exception? message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final LocationPickerTheme theme;

  const LocationPickerErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.onDismiss,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = message != null
        ? message.toString()
        : 'Unexpected error occurred';

    // Check if offline failure
    final isOffline =
        errorMessage.contains('لا يوجد') ||
        errorMessage.toLowerCase().contains('internet') ||
        errorMessage.toLowerCase().contains('offline') ||
        errorMessage.toLowerCase().contains('connection');

    final String? errorLottie = isOffline
        ? theme.noInternetLottieAsset
        : theme.errorLottieAsset;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated concentric rings and glow background
            _AnimatedErrorBackground(
              theme: theme,
              child: errorLottie != null
                  ? Lottie.asset(
                      errorLottie,
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      isOffline
                          ? Icons.wifi_off_rounded
                          : Icons.error_outline_rounded,
                      size: 64,
                      color: theme.primaryColor,
                    ),
            ),
            const SizedBox(height: 24),

            // Error Title
            Text(
              isOffline
                  ? (Localizations.localeOf(context).languageCode == 'ar'
                        ? 'لا يوجد اتصال بالإنترنت'
                        : 'No Internet Connection')
                  : (Localizations.localeOf(context).languageCode == 'ar'
                        ? 'حدث خطأ ما'
                        : 'Something went wrong'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xff0A100B)
                    : Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Error Message
            Text(
              errorMessage
                  .replaceFirst('Exception: ', '')
                  .replaceFirst('Exception', ''),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xff6B7C6E),
              ),
              textAlign: TextAlign.center,
            ),

            // Retry button for non-mobile platforms (web & desktop)
            if ((onRetry != null || onDismiss != null) &&
                (kIsWeb ||
                    (defaultTargetPlatform != TargetPlatform.android &&
                        defaultTargetPlatform != TargetPlatform.iOS))) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry ?? onDismiss,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إعادة المحاولة'
                      : 'Try Again',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final VoidCallback? retryCallback = onRetry ?? onDismiss;

    final bool isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (retryCallback != null && isMobile) {
      return RefreshIndicator(
        color: theme.primaryColor,
        onRefresh: () async {
          retryCallback.call();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [SliverFillRemaining(hasScrollBody: false, child: content)],
        ),
      );
    }

    return content;
  }
}

class _AnimatedErrorBackground extends StatefulWidget {
  final Widget child;
  final LocationPickerTheme theme;
  const _AnimatedErrorBackground({required this.child, required this.theme});

  @override
  State<_AnimatedErrorBackground> createState() =>
      _AnimatedErrorBackgroundState();
}

class _AnimatedErrorBackgroundState extends State<_AnimatedErrorBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer faint ring
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.theme.primaryColor.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.theme.primaryColor.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
            // Glowing background pulse
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.primaryColor.withValues(
                      alpha: 0.1 * _controller.value,
                    ),
                    blurRadius: 50,
                    spreadRadius: 25,
                  ),
                ],
              ),
            ),
            // Floating animation child
            Transform.translate(
              offset: Offset(0, _floatingAnimation.value),
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}
