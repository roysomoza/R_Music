import 'package:flutter/material.dart';
import '../../../core/platform/equalizer_channel.dart';
import '../../../core/theme/app_theme.dart';

/// Modal bottom sheet for controlling the audio equalizer, bass boost, and 5 frequency bands.
class EqualizerBottomSheet extends StatefulWidget {
  const EqualizerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const EqualizerBottomSheet(),
    );
  }

  @override
  State<EqualizerBottomSheet> createState() => _EqualizerBottomSheetState();
}

class _EqualizerBottomSheetState extends State<EqualizerBottomSheet> {
  bool _isEnabled = true;
  int _selectedPreset = 0;
  List<String> _presets = EqualizerChannel.fallbackPresets;
  int _bassBoostStrength = 250; // 0 to 1000

  final List<String> _bandFrequencies = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];
  final List<int> _bandLevels = [0, 0, 0, 0, 0]; // milliBels: -1000 to +1000 (-10dB to +10dB)

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await EqualizerChannel.getPresets();
    if (mounted) {
      setState(() => _presets = presets);
    }
  }

  void _onToggleEnabled(bool val) {
    setState(() => _isEnabled = val);
    EqualizerChannel.setEnabled(val);
  }

  void _onSelectPreset(int index) {
    setState(() => _selectedPreset = index);
    EqualizerChannel.setPreset(index);
  }

  void _onBassBoostChanged(double val) {
    setState(() => _bassBoostStrength = val.toInt());
    EqualizerChannel.setBassBoost(_bassBoostStrength);
  }

  void _onBandChanged(int bandIndex, double value) {
    final milliBels = value.toInt();
    setState(() => _bandLevels[bandIndex] = milliBels);
    EqualizerChannel.setBandLevel(bandIndex, milliBels);
  }

  String _formatDb(int milliBels) {
    final db = (milliBels / 100).round();
    return db > 0 ? '+$db dB' : '$db dB';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header with switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.equalizer_rounded, color: AppTheme.accentNeonBlue, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Ecualizador & Bass Boost',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isEnabled,
                    activeThumbColor: AppTheme.accentNeonBlue,
                    activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.4),
                    inactiveThumbColor: AppTheme.textMuted,
                    inactiveTrackColor: AppTheme.surfaceHighlight,
                    onChanged: _onToggleEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Presets label
              const Text(
                'Preajustes de Sonido',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Presets horizontal list
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedPreset == index;
                    return ChoiceChip(
                      label: Text(_presets[index]),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: AppTheme.surfaceElevated,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.accentNeonBlue : AppTheme.borderSubtle,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: _isEnabled ? (_) => _onSelectPreset(index) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Bass Boost Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speaker_group_rounded, color: AppTheme.electricCyan, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Refuerzo de Graves (Bass Boost)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(_bassBoostStrength / 10).round()}%',
                    style: const TextStyle(
                      color: AppTheme.accentNeonBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  activeTrackColor: AppTheme.accentNeonBlue,
                  inactiveTrackColor: AppTheme.surfaceHighlight,
                  thumbColor: AppTheme.electricCyan,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  disabledActiveTrackColor: AppTheme.surfaceHighlight,
                  disabledInactiveTrackColor: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                  disabledThumbColor: AppTheme.textMuted,
                ),
                child: Slider(
                  value: _bassBoostStrength.toDouble(),
                  min: 0,
                  max: 1000,
                  onChanged: _isEnabled ? _onBassBoostChanged : null,
                ),
              ),
              const SizedBox(height: 24),

              // Bandas de Ecualización Section
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppTheme.accentNeonBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Bandas de Ecualización',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5 Graphic Equalizer Bands
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_bandFrequencies.length, (index) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // dB Value
                      Text(
                        _formatDb(_bandLevels[index]),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: _isEnabled && _bandLevels[index] != 0
                              ? AppTheme.accentNeonBlue
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Vertical Slider
                      SizedBox(
                        height: 140,
                        width: 36,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              activeTrackColor: AppTheme.accentNeonBlue,
                              inactiveTrackColor: AppTheme.surfaceHighlight,
                              thumbColor: AppTheme.accentNeonBlue,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                              disabledActiveTrackColor: AppTheme.surfaceHighlight,
                              disabledInactiveTrackColor:
                                  AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                              disabledThumbColor: AppTheme.textMuted,
                            ),
                            child: Slider(
                              value: _bandLevels[index].toDouble(),
                              min: -1000,
                              max: 1000,
                              onChanged: _isEnabled
                                  ? (val) => _onBandChanged(index, val)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Frequency Label
                      Text(
                        _bandFrequencies[index],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );
                }),
              ),

              // Bottom padding to ensure zero clipping over system navigation bars
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
