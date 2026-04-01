import 'package:flutter/material.dart';
import 'package:inspection_app/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Tout à zéro — sera rempli par MQTT réel
  int _pass = 0, _fail = 0;
  final List<double> _pitches = [];
  final List<_PieceResult> _feed = [];
  bool _connected = false;   // rouge jusqu'à connexion MQTT

  static const double _ucl    = 1.25;
  static const double _lcl    = 1.15;
  static const double _target = 1.20;

  double get _rate {
    final total = _pass + _fail;
    return total == 0 ? 0.0 : _pass / total;
  }

  bool get _driftDetected {
    if (_pitches.length < 7) return false;
    final last = _pitches.sublist(_pitches.length - 7);
    bool allUp = true, allDn = true;
    for (int i = 1; i < last.length; i++) {
      if (last[i] < last[i - 1]) allUp = false;
      if (last[i] > last[i - 1]) allDn = false;
    }
    return allUp || allDn;
  }

  @override
  Widget build(BuildContext context) {
    final ratePct = _pass + _fail == 0
        ? '—'
        : '${(_rate * 100).toStringAsFixed(1)}%';

    final Color rateColor = _pass + _fail == 0
        ? AppTheme.textSecondary
        : _rate >= 0.95
            ? AppTheme.passGreen
            : _rate >= 0.88
                ? AppTheme.warnAmber
                : AppTheme.failRed;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildMetrics(),
              const SizedBox(height: 14),
              _buildRateBar(ratePct, rateColor),
              const SizedBox(height: 14),
              _buildSpcChart(),
              const SizedBox(height: 14),
              _buildFeed(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inspection',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                )),
            SizedBox(height: 2),
            Text('POSTE 1 — LOT L2024-087',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                )),
          ],
        ),
        _MqttBadge(connected: _connected),
      ],
    );
  }

  // ── Métriques ────────────────────────────────────────────
  Widget _buildMetrics() {
    return Row(children: [
      Expanded(child: _MetricCard(
        label: 'PASS',
        value: _pass,
        valueColor: AppTheme.passGreen,
        bgColor: const Color(0xFF071A0E),
        borderColor: const Color(0xFF0F3D1E),
        sub: _pass + _fail == 0 ? '— %' : '${(_rate * 100).toStringAsFixed(1)}% conform.',
        isEmpty: _pass + _fail == 0,
      )),
      const SizedBox(width: 10),
      Expanded(child: _MetricCard(
        label: 'FAIL',
        value: _fail,
        valueColor: AppTheme.failRed,
        bgColor: const Color(0xFF1A0707),
        borderColor: const Color(0xFF3D0F0F),
        sub: _pass + _fail == 0 ? '— %' : '${(100 - _rate * 100).toStringAsFixed(1)}% rebut',
        isEmpty: _pass + _fail == 0,
      )),
    ]);
  }

  // ── Barre conformité ─────────────────────────────────────
  Widget _buildRateBar(String ratePct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TAUX CONFORMITÉ',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.06,
                )),
            Text(ratePct,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _pass + _fail == 0 ? 0.0 : _rate,
            minHeight: 6,
            backgroundColor: const Color(0xFF1A1D24),
            valueColor: AlwaysStoppedAnimation<Color>(
              _pass + _fail == 0 ? const Color(0xFF1A1D24) : color,
            ),
          ),
        ),
      ],
    );
  }

  // ── Graphique SPC ────────────────────────────────────────
  Widget _buildSpcChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('CARTE SPC — PITCH (mm)',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                )),
            if (_driftDetected)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1400),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: const Color(0xFF3D2E00), width: 0.5),
                ),
                child: const Text('DÉRIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.warnAmber,
                    )),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF080A0E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A1D24), width: 0.5),
          ),
          child: _pitches.length < 2
              ? Center(
                  child: Text(
                    _connected
                        ? 'En attente de données...'
                        : 'Non connecté au broker MQTT',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _SpcPainter(
                      pitches: List.from(_pitches),
                      ucl: _ucl,
                      lcl: _lcl,
                      target: _target,
                    ),
                    size: Size.infinite,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Flux live ────────────────────────────────────────────
  Widget _buildFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FLUX EN DIRECT',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            )),
        const SizedBox(height: 8),
        if (_feed.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF1A1D24), width: 0.5),
            ),
            child: Text(
              _connected
                  ? 'En attente de la première pièce...'
                  : 'Connectez-vous au broker MQTT\npour recevoir les résultats.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          )
        else
          ..._feed.map((f) => _FeedItem(piece: f)),
      ],
    );
  }
}

// ── Badge MQTT ─────────────────────────────────────────────
class _MqttBadge extends StatefulWidget {
  final bool connected;
  const _MqttBadge({required this.connected});
  @override
  State<_MqttBadge> createState() => _MqttBadgeState();
}

class _MqttBadgeState extends State<_MqttBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.connected
        ? AppTheme.passGreen
        : AppTheme.failRed;
    final bgColor = widget.connected
        ? const Color(0xFF0F1A12)
        : const Color(0xFF1A0707);
    final borderColor = widget.connected
        ? const Color(0xFF1A3D22)
        : const Color(0xFF3D0F0F);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(children: [
        // Clignote si connecté, fixe rouge si déconnecté
        widget.connected
            ? FadeTransition(
                opacity: _anim,
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
              )
            : Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: 5),
        Text(
          widget.connected ? 'LIVE' : 'OFF',
          style: TextStyle(fontSize: 10, color: color),
        ),
      ]),
    );
  }
}

// ── Carte métrique ─────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final Color valueColor, bgColor, borderColor;
  final String sub;
  final bool isEmpty;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bgColor,
    required this.borderColor,
    required this.sub,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: valueColor.withOpacity(0.6),
                letterSpacing: 0.08,
              )),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '—' : '$value',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isEmpty
                  ? AppTheme.textSecondary
                  : valueColor,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                fontSize: 10,
                color: valueColor.withOpacity(0.5),
              )),
        ],
      ),
    );
  }
}

// ── Ligne flux ─────────────────────────────────────────────
class _FeedItem extends StatelessWidget {
  final _PieceResult piece;
  const _FeedItem({required this.piece});

  @override
  Widget build(BuildContext context) {
    final isPass = piece.status == 'PASS';
    final color  = isPass ? AppTheme.passGreen : AppTheme.failRed;
    final bg     = isPass
        ? const Color(0xFF071A0E)
        : const Color(0xFF1A0707);
    final border = isPass
        ? const Color(0xFF0F3D1E)
        : const Color(0xFF3D0F0F);
    final ts =
        '${piece.time.hour.toString().padLeft(2, '0')}:'
        '${piece.time.minute.toString().padLeft(2, '0')}:'
        '${piece.time.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF1A1D24), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Text(piece.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(piece.id,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  )),
              Text('pitch ${piece.pitch.toStringAsFixed(3)} mm',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  )),
            ],
          ),
        ),
        Text(ts,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            )),
      ]),
    );
  }
}

// ── Modèle pièce ───────────────────────────────────────────
class _PieceResult {
  final String id;
  final String status;
  final double pitch;
  final DateTime time;
  const _PieceResult({
    required this.id,
    required this.status,
    required this.pitch,
    required this.time,
  });
}

// ── Painter SPC ────────────────────────────────────────────
class _SpcPainter extends CustomPainter {
  final List<double> pitches;
  final double ucl, lcl, target;

  const _SpcPainter({
    required this.pitches,
    required this.ucl,
    required this.lcl,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double minV  = 1.10;
    const double maxV  = 1.30;
    const double range = maxV - minV;

    double py(double v) =>
        size.height - 6 - ((v - minV) / range) * (size.height - 12);

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1D24)
      ..strokeWidth = 0.5;

    for (final v in [ucl, target, lcl]) {
      canvas.drawLine(
          Offset(0, py(v)), Offset(size.width, py(v)), gridPaint);
    }

    void drawLabel(String text, double v, Color color) {
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(fontSize: 9, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(3, py(v) - 11));
    }

    drawLabel('UCL', ucl, const Color(0xFF2A6640));
    drawLabel('LCL', lcl, const Color(0xFF2A6640));

    if (pitches.length < 2) return;

    final path = Path();
    final step = size.width / (pitches.length - 1);

    for (int i = 0; i < pitches.length; i++) {
      final x = i * step;
      final y = py(pitches[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    for (int i = 0; i < pitches.length; i++) {
      final outOfCtrl = pitches[i] > ucl || pitches[i] < lcl;
      canvas.drawCircle(
        Offset(i * step, py(pitches[i])),
        outOfCtrl ? 3.5 : 2.0,
        Paint()
          ..color = outOfCtrl
              ? const Color(0xFFF87171)
              : const Color(0xFF378ADD),
      );
    }
  }

  @override
  bool shouldRepaint(_SpcPainter old) =>
      old.pitches.length != pitches.length;
}