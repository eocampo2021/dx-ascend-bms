import 'package:flutter/material.dart';

class EboRibbonBar extends StatelessWidget {
  const EboRibbonBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFC0C0C0), width: 1),
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.dashboard_customize, size: 24),
          SizedBox(width: 12),
          Text(
            'DX-Ascend-Workstation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
