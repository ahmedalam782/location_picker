import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../utils/nominatim_service.dart';
import '../../location_picker_theme.dart';
import '../../location_picker_strings.dart';

class LocationSearchBottomSheet extends StatefulWidget {
  final LocationPickerTheme theme;
  final LocationPickerStrings strings;
  final Function(LatLng, String) onLocationSelected;

  const LocationSearchBottomSheet({
    super.key,
    required this.theme,
    required this.strings,
    required this.onLocationSelected,
  });

  @override
  State<LocationSearchBottomSheet> createState() => _LocationSearchBottomSheetState();
}

class _LocationSearchBottomSheetState extends State<LocationSearchBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final NominatimService _searchService = NominatimService(Dio());
  List<NominatimSearchResult> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {}); // Redraw suffix clear button
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final results = await _searchService.search(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: widget.theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  style: TextStyle(color: widget.theme.textDarkColor),
                  decoration: InputDecoration(
                    hintText: widget.strings.searchHint,
                    hintStyle: TextStyle(color: widget.theme.textDarkColor.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: widget.theme.primaryColor),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: widget.theme.textDarkColor.withValues(alpha: 0.6)),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xff121212) : const Color(0xfff5f5f5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Loading Indicator
              if (_isLoading)
                LinearProgressIndicator(
                  color: widget.theme.primaryColor,
                  backgroundColor: widget.theme.primaryColor.withValues(alpha: 0.2),
                ),

              // Results List
              Expanded(
                child: _results.isEmpty && !_isLoading
                    ? ListView(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Center(
                              child: Text(
                                _controller.text.isEmpty
                                    ? ''
                                    : widget.strings.noResults,
                                style: TextStyle(
                                  color: widget.theme.textDarkColor.withValues(alpha: 0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.theme.primaryColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: widget.theme.primaryColor,
                              ),
                            ),
                            title: Text(
                              item.displayName,
                              style: TextStyle(
                                color: widget.theme.textDarkColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              widget.onLocationSelected(
                                LatLng(item.lat, item.lon),
                                item.displayName,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
