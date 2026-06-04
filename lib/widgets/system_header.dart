



import 'package:flutter/material.dart';
import '../theme.dart';

class SystemHeader extends StatelessWidget {
  final bool isApiConnected;
  final bool isCameraConnected;
  final VoidCallback? onSettingsTap;

  const SystemHeader({
    super.key,
    required this.isApiConnected,
    this.isCameraConnected = true,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = isApiConnected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inspection System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'PCB Quality Control',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SystemStatusBadge(isRunning: isRunning),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusIndicator(label: 'API', isOk: isApiConnected),
                const SizedBox(width: 8),
                _StatusIndicator(label: 'CAM', isOk: isCameraConnected),
                if (onSettingsTap != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onSettingsTap,
                    child: const Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SystemStatusBadge extends StatefulWidget {
  final bool isRunning;
  const _SystemStatusBadge({required this.isRunning});

  @override
  State<_SystemStatusBadge> createState() => _SystemStatusBadgeState();
}

class _SystemStatusBadgeState extends State<_SystemStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isRunning) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_SystemStatusBadge old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isRunning && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isRunning ? AppTheme.passGreen : AppTheme.failRed;
    final bgColor = widget.isRunning ? AppTheme.passBgLight : AppTheme.failBgLight;
    final borderColor = color.withValues(alpha: 0.3);
    final label = widget.isRunning ? 'RUNNING' : 'STOPPED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: widget.isRunning ? _pulse.value : 1.0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool isOk;

  const _StatusIndicator({required this.label, required this.isOk});

  @override
  Widget build(BuildContext context) {
    final color = isOk ? AppTheme.passGreen : AppTheme.failRed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
