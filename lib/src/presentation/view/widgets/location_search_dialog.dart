import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../utils/nominatim_service.dart';
import '../../location_picker_theme.dart';
import '../../location_picker_strings.dart';

class LocationSearchDialog extends StatefulWidget {
  final LocationPickerTheme theme;
  final LocationPickerStrings strings;
  final Function(LatLng, String) onLocationSelected;

  const LocationSearchDialog({
    super.key,
    required this.theme,
    required this.strings,
    required this.onLocationSelected,
  });

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
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

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: widget.theme.cardColor,
            child: Column(
            children: [
              // Dialog Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.strings.searchHint.replaceFirst('...', ''),
                      style: TextStyle(
                        color: widget.theme.textDarkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: widget.theme.textDarkColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  style: TextStyle(color: widget.theme.textDarkColor),
                  decoration: InputDecoration(
                    hintText: widget.strings.searchHint,
                    hintStyle: TextStyle(
                      color: widget.theme.textDarkColor.withValues(alpha: 0.5),
                    ),
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
              const SizedBox(height: 8),

              // Loading Indicator
              if (_isLoading)
                LinearProgressIndicator(
                  color: widget.theme.primaryColor,
                  backgroundColor: widget.theme.primaryColor.withValues(alpha: 0.2),
                ),

              // Results List
              Expanded(
                child: _results.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          _controller.text.isEmpty ? '' : widget.strings.noResults,
                          style: TextStyle(
                            color: widget.theme.textDarkColor.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.separated(
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
        ),
      ),
      ),
    );
  }
}
