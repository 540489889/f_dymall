import 'dart:math';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class Waves extends StatefulWidget {
  const Waves({
  super.key,
  this.waveColor = Colors.white,
  this.waveCount = 30,
});

// 波浪颜色
final Color waveColor;
// 波浪数量
final int waveCount;

@override
State<Waves> createState() => _WavesState();
}

class _WavesState extends State<Waves> with TickerProviderStateMixin {
late AnimationController _waveController;
late AnimationController _amplitudeController;

List<double> _waveHeights = [];
final double _maxWaveHeight = 12.0;
final double _minWaveHeight = 1.0;

@override
void initState() {
  super.initState();
  _waveHeights = List.generate(widget.waveCount, (index) => _minWaveHeight);
  
  _waveController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..repeat();
  
  _amplitudeController = AnimationController(
  duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  
  _waveController.addListener(_updateWaveHeights);
}

void _updateWaveHeights() {
  final random = Random();
  setState(() {
    for (int i = 0; i < widget.waveCount; i++) {
      // 基础波动 + 随机波动
      double baseHeight = (_maxWaveHeight - _minWaveHeight) * (0.5 + 0.5 * math.sin(_waveController.value * 2 * math.pi + i));
      
      // 添加随机性使波浪更自然
      double randomFactor = 0.3 * random.nextDouble() * _amplitudeController.value;
      
      _waveHeights[i] = baseHeight + randomFactor * (_maxWaveHeight - _minWaveHeight);
    }
  });
  }

  @override
  void dispose() {
   _waveController.dispose();
   _amplitudeController.dispose();
  super.dispose();
 }

@override
Widget build(BuildContext context) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(widget.waveCount, (index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 2.0,
      height: _waveHeights[index],
      margin: EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: widget.waveColor,
        borderRadius: BorderRadius.circular(5.0),
      ),
    );
    }),
    );
  }
}
