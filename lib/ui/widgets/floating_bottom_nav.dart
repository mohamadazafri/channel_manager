import 'package:flutter/material.dart';

class FloatingBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.calendar_month,
              label: 'Calendar',
              index: 0,
              isSelected: currentIndex == 0,
            ),
            _buildNavItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              index: 1,
              isSelected: currentIndex == 1,
            ),
            _buildNavItem(
              icon: Icons.settings,
              label: 'Settings',
              index: 2,
              isSelected: currentIndex == 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? _getSelectedColor(index) : Colors.grey[500],
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? _getSelectedColor(index) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSelectedColor(int index) {
    switch (index) {
      case 0:
        return Colors.blue[600]!;
      case 1:
        return Colors.green[600]!;
      case 2:
        return Colors.purple[600]!;
      default:
        return Colors.blue[600]!;
    }
  }
}
