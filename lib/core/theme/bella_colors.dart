import 'package:flutter/material.dart';

/// Paleta de cores oficial da Bella Lu Doces inspirada no material gráfico.
/// Estilo: Confeitaria artesanal/afetiva (Rosa pastel, Creme, Chocolate).
class BellaColors {
  BellaColors._();

  // Tons principais de Rosa (Identidade Bella Lu)
  static const Color pinkPrimary = Color(0xFFE85D88);
  static const Color pinkDark = Color(0xFFC9406B);
  static const Color pinkLight = Color(0xFFF8B4C8);
  static const Color pinkSoft = Color(0xFFFDEBF1);
  static const Color pinkBorder = Color(0xFFF5CEDB);

  // Fundos e Superfícies (Creme de Confeitaria & Branco)
  static const Color creamBackground = Color(0xFFFFF8FA);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color creamAccent = Color(0xFFFFF0F5);

  // Tons de Chocolate (Tipografia e Contrastes)
  static const Color darkChocolate = Color(0xFF3A1E14);
  static const Color mediumBrown = Color(0xFF6E473B);
  static const Color softCocoa = Color(0xFF9C7A6E);

  // Cores Semânticas e de Ação
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF1DA851);
  static const Color successGreen = Color(0xFF2E9E5B);
  static const Color warningAmber = Color(0xFFE68A00);
  static const Color errorRed = Color(0xFFD9383A);

  // Gradientes decorativos do cabeçalho e banners
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFCE0E8),
      Color(0xFFFFF5F8),
    ],
  );

  static const LinearGradient promoBannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFE85D88),
      Color(0xFFF2789F),
    ],
  );
}
