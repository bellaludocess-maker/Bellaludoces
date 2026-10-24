import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/bella_colors.dart';

/// Logomarca oficial da "Bella Lu Doces" utilizando a imagem oficial enviada.
/// Aplica recorte circular (ClipOval) com leve zoom para remover as bordas pretas
/// externas do arquivo original e destacar o selo rendado rosa e branco.
class BellaBrandLogo extends StatelessWidget {
  final double size;

  const BellaBrandLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: BellaColors.pinkPrimary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.04,
          child: Image.asset(
            AppConstants.logoAssetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            errorBuilder: (_, _, _) => _buildVectorFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildVectorFallback() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: BellaColors.pinkSoft,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
                children: [
                  TextSpan(
                    text: 'Bella ',
                    style: TextStyle(color: BellaColors.darkChocolate),
                  ),
                  TextSpan(
                    text: 'Lu',
                    style: TextStyle(color: BellaColors.pinkPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Doces',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: BellaColors.mediumBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
