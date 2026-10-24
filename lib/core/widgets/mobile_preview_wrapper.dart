import 'package:flutter/material.dart';
import '../theme/bella_colors.dart';

/// Moldura animada que simula a tela de um Smartphone (Cardápio Digital Mobile)
/// quando ativada pelo usuário no PC, permitindo visualizar exatamente a
/// experiência mobile com 1 clique.
class MobilePreviewWrapper extends StatelessWidget {
  final bool isMobilePreviewEnabled;
  final VoidCallback onTogglePreview;
  final Widget child;

  const MobilePreviewWrapper({
    super.key,
    required this.isMobilePreviewEnabled,
    required this.onTogglePreview,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Se a tela real já for de celular (< 520px), não precisa de moldura externa
    if (!isMobilePreviewEnabled || screenSize.width < 520) {
      return child;
    }

    const mobileWidth = 392.0;
    final mobileHeight = (screenSize.height - 48).clamp(620.0, 844.0);

    return Scaffold(
      backgroundColor: const Color(0xFF2B1912),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de status da simulação acima do celular
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.smartphone_rounded,
                          color: BellaColors.pinkLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Simulador Cardápio Digital (Visão do Cliente no Celular)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: onTogglePreview,
                          style: TextButton.styleFrom(
                            backgroundColor: BellaColors.pinkPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(
                            Icons.desktop_windows_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'Voltar para Tela Cheia (PC)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Moldura física do Smartphone
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    width: mobileWidth + 24,
                    height: mobileHeight + 28,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0F0A),
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(
                        color: BellaColors.pinkLight.withValues(alpha: 0.45),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 36,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: Size(mobileWidth, mobileHeight),
                        ),
                        child: SizedBox(
                          width: mobileWidth,
                          height: mobileHeight,
                          child: child,
                        ),
                      ),
                    ),
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
