import 'package:flutter/material.dart';
import '../theme/bella_colors.dart';

/// Ícone vetorial oficial no estilo do WhatsApp (balão verde com telefone branco interno).
class WhatsAppLogoIcon extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const WhatsAppLogoIcon({
    super.key,
    this.size = 20,
    this.backgroundColor = BellaColors.whatsappGreen,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppLogoPainter(
          backgroundColor: backgroundColor,
          iconColor: iconColor,
        ),
      ),
    );
  }
}

class _WhatsAppLogoPainter extends CustomPainter {
  final Color backgroundColor;
  final Color iconColor;

  const _WhatsAppLogoPainter({
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.48);
    final radius = w * 0.44;

    final bubblePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Cauda inferior esquerda do balão do WhatsApp
    final tailPath = Path()
      ..moveTo(w * 0.06, h * 0.94)
      ..lineTo(w * 0.16, h * 0.68)
      ..lineTo(w * 0.34, h * 0.84)
      ..close();
    canvas.drawPath(tailPath, bubblePaint);

    // 2. Círculo principal do balão do WhatsApp
    canvas.drawCircle(center, radius, bubblePaint);

    // 3. Monofone branco clássico inclinado no centro do balão
    final phonePaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final phoneFillPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Curva do monofone
    final arcPath = Path()
      ..moveTo(w * 0.34, h * 0.33)
      ..quadraticBezierTo(w * 0.33, h * 0.57, w * 0.65, h * 0.63);
    canvas.drawPath(arcPath, phonePaint);

    // Pontas mais gordinhas do monofone (auricular superior e microfone inferior)
    canvas.drawCircle(Offset(w * 0.36, h * 0.33), w * 0.08, phoneFillPaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.61), w * 0.08, phoneFillPaint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppLogoPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.iconColor != iconColor;
  }
}
