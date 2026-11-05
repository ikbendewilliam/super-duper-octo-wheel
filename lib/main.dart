import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_crazy_fortune_wheel/flutter_crazy_fortune_wheel.dart';

void main() {
  runApp(const RandomSelectorApp());
}

/// The choices in the wheel type dropdown.
enum WheelOption {
  normal('Normal', WheelType.normal),
  sliced('Sliced', WheelType.sliced),
  disappearing('Disappearing', WheelType.disappearing),

  /// Uses a different wheel type than the previous one on every spin.
  random('Random', null);

  const WheelOption(this.label, this.wheelType);

  final String label;

  /// The fixed wheel type, or `null` for [random].
  final WheelType? wheelType;
}

class RandomSelectorApp extends StatelessWidget {
  const RandomSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Selector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const RandomSelectorPage(),
    );
  }
}

class RandomSelectorPage extends StatefulWidget {
  const RandomSelectorPage({super.key});

  @override
  State<RandomSelectorPage> createState() => _RandomSelectorPageState();
}

class _RandomSelectorPageState extends State<RandomSelectorPage> with SingleTickerProviderStateMixin {
  static const _minNames = 2;

  final _random = Random.secure();
  final _namesController = TextEditingController(text: 'Alice\nBob\nCharlie\nWilliam');
  late final _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  late final _spinAnimation = _spinController.drive(CurveTween(curve: FortuneWheelCurve()));
  final _confettiController = ConfettiController(duration: const Duration(seconds: 2));

  late List<String> _names = _parseNames(_namesController.text);
  WheelOption _wheelOption = WheelOption.normal;

  /// The wheel type currently shown. Follows [_wheelOption], except in
  /// random mode where it changes to a different type on every spin.
  WheelType _wheelType = WheelType.normal;
  int _winnerIndex = 0;
  int _previousWinnerIndex = 0;
  bool _isSpinning = false;
  String? _winner;

  @override
  void dispose() {
    _namesController.dispose();
    _spinController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  List<String> _parseNames(String text) =>
      text.split('\n').map((name) => name.trim()).where((name) => name.isNotEmpty).toList();

  bool get _canSpin => !_isSpinning && _names.length >= _minNames;

  /// Resets the wheel to its initial position (e.g. after the names change).
  void _resetWheel() {
    _spinController.reset();
    _winnerIndex = 0;
    _previousWinnerIndex = 0;
    _winner = null;
  }

  void _onNamesChanged(String text) {
    setState(() {
      _names = _parseNames(text);
      _resetWheel();
    });
  }

  void _onWheelOptionChanged(WheelOption? option) {
    if (option == null || option == _wheelOption) return;
    setState(() {
      _wheelOption = option;
      final type = option.wheelType;
      if (type != null && type != _wheelType) {
        _wheelType = type;
        _resetWheel();
      }
    });
  }

  WheelType _randomDifferentWheelType() {
    final others = WheelType.values.where((t) => t != _wheelType).toList();
    return others[_random.nextInt(others.length)];
  }

  Future<void> _spin() async {
    if (!_canSpin) return;
    setState(() {
      // Start from where the wheel stopped last time.
      _previousWinnerIndex = _spinController.value == 0 ? 0 : _winnerIndex;
      _winnerIndex = _random.nextInt(_names.length);
      if (_wheelOption == WheelOption.random) {
        _wheelType = _randomDifferentWheelType();
      }
      _winner = null;
      _isSpinning = true;
    });
    _spinController.reset();
    await _spinController.forward();
    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _winner = _names[_winnerIndex];
    });
    _confettiController.play();
  }

  Future<void> _spinWithoutWinner() async {
    if (_isSpinning || _winner == null) return;
    final remaining = List.of(_names)..removeAt(_winnerIndex);
    if (remaining.length < _minNames) return;
    _namesController.text = remaining.join('\n');
    setState(() {
      _names = remaining;
      _resetWheel();
    });
    await _spin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                final namesPanel = _NamesPanel(
                  controller: _namesController,
                  enabled: !_isSpinning,
                  count: _names.length,
                  onChanged: _onNamesChanged,
                );
                final wheelPanel = _buildWheelPanel(context);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 320, child: namesPanel),
                      const VerticalDivider(width: 1),
                      Expanded(child: wheelPanel),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.85, child: wheelPanel),
                      const Divider(height: 1),
                      SizedBox(height: 360, child: namesPanel),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: _WheelTypeDropdown(value: _wheelOption, enabled: !_isSpinning, onChanged: _onWheelOptionChanged),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              emissionFrequency: 0.05,
              maxBlastForce: 40,
              minBlastForce: 10,
              gravity: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child:
                  _names.length < _minNames
                      ? Text(
                        'Add at least $_minNames names to spin the wheel',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      )
                      : Padding(
                        // Leave room for the arrow on the right side.
                        padding: const EdgeInsets.only(right: 48),
                        child: RandomWheel(
                          key: ValueKey(_wheelType),
                          animation: _spinAnimation,
                          wheelType: _wheelType,
                          winnerIndex: _winnerIndex,
                          previousWinnerIndex: _previousWinnerIndex,
                          children: [
                            for (final name in _names)
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 112,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child:
                  _winner == null
                      ? Center(
                        key: const ValueKey('spin'),
                        child: FilledButton.icon(
                          onPressed: _canSpin ? _spin : null,
                          icon: const Icon(Icons.casino),
                          label: Text(_isSpinning ? 'Spinning…' : 'Spin'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                            textStyle: theme.textTheme.titleLarge,
                          ),
                        ),
                      )
                      : Column(
                        key: ValueKey('winner-$_winner'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🎉 $_winner 🎉',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _canSpin ? _spin : null,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Spin again'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _canSpin && _names.length > _minNames ? _spinWithoutWinner : null,
                                icon: const Icon(Icons.person_remove),
                                label: const Text('Spin again without winner'),
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamesPanel extends StatelessWidget {
  const _NamesPanel({required this.controller, required this.enabled, required this.count, required this.onChanged});

  final TextEditingController controller;
  final bool enabled;
  final int count;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Names', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('One name per line · $count ${count == 1 ? 'name' : 'names'}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Alice\nBob\nCharlie'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelTypeDropdown extends StatelessWidget {
  const _WheelTypeDropdown({required this.value, required this.enabled, required this.onChanged});

  final WheelOption value;
  final bool enabled;
  final ValueChanged<WheelOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Tooltip(
      message: 'Wheel type',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WheelOption>(
          value: value,
          isDense: true,
          iconSize: 16,
          iconEnabledColor: muted,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          onChanged: enabled ? onChanged : null,
          items: [for (final option in WheelOption.values) DropdownMenuItem(value: option, child: Text(option.label))],
        ),
      ),
    );
  }
}
