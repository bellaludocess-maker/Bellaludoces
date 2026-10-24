import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../theme/bella_colors.dart';
import 'whatsapp_logo_icon.dart';

/// Selo oficial e Cartão de Visita Digital da desenvolvedora **Sunflower Development**.
/// Exibe a logomarca oficial no rodapé do site, tela de login do APK e painel gestor.
/// Ao tocar no selo, abre um modal elegante com os 3 números de WhatsApp comerciais.
class SunflowerDeveloperBadge extends StatelessWidget {
  final String labelPrefix;
  final String actionHint;
  final bool compact;

  const SunflowerDeveloperBadge({
    super.key,
    this.labelPrefix = 'Desenvolvido por',
    this.actionHint = 'Toque para contato',
    this.compact = false,
  });

  Future<void> _openWhatsAppContact(String cleanPhone) async {
    final text = Uri.encodeComponent(
      'Olá! Vi o sistema da ${AppConstants.storeName} desenvolvido pela ${AppConstants.developerName} e gostaria de conversar.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDeveloperContactDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF3D27A),
                        width: 1.2,
                      ),
                    ),
                    child: Image.asset(
                      AppConstants.developerLogoAssetPath,
                      height: 92,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.wb_sunny_rounded,
                        size: 54,
                        color: Color(0xFFE6A800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    AppConstants.developerName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF421C0C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    AppConstants.developerTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: BellaColors.mediumBrown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Escolha um WhatsApp para falar conosco:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BellaColors.darkChocolate,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...AppConstants.developerWhatsAppContacts.map((contact) {
                    final display = contact['display'] ?? '';
                    final clean = contact['clean'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: ValueKey('sunflower_whatsapp_$clean'),
                          onPressed: () => _openWhatsAppContact(clean),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BellaColors.whatsappGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const WhatsAppLogoIcon(size: 18),
                          label: Text(
                            'WhatsApp: $display',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Fechar',
                      style: TextStyle(
                        color: BellaColors.mediumBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('sunflower_developer_badge'),
        onTap: () => _showDeveloperContactDialog(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFEED38A),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  AppConstants.developerLogoAssetPath,
                  height: compact ? 32 : 38,
                  width: compact ? 42 : 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.wb_sunny_rounded,
                    size: 24,
                    color: Color(0xFFE6A800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$labelPrefix ${AppConstants.developerName}',
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF421C0C),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WhatsAppLogoIcon(size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            actionHint,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 10.5 : 11,
                              fontWeight: FontWeight.w600,
                              color: BellaColors.mediumBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
