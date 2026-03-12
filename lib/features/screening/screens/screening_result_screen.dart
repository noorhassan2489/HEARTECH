import 'package:flutter/material.dart';

class ScreeningResultScreen extends StatelessWidget {
  final int riskScore;
  final String riskLevel;
  final Map<String, dynamic> sessionData;
  final String role;
  
  const ScreeningResultScreen({
    super.key, 
    required this.riskScore, 
    required this.riskLevel,
    required this.sessionData,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screening Result')),
      body: const Center(child: Text('Screening Result - Coming Soon')),
    );
  }
}
