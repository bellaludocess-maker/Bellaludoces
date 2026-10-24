import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/bella_colors.dart';
import '../../../../core/widgets/bella_brand_logo.dart';
import '../../../external/cloudinary/cloudinary_service.dart';
import '../../models/product_model.dart';

/// Renderiza a foto do produto (via URL Cloudinary/Web, Data URI Base64 ou Ilustração
/// confeiteira fiel ao folder da Bella Lu Doces).
class ProductIllustrationBanner extends StatelessWidget {
  final ProductModel product;
  final double height;

  const ProductIllustrationBanner({
    super.key,
    required this.product,
    this.height = 175,
  });

  bool get _isNetworkImage =>
      product.imageUrl.startsWith('http://') ||
      product.imageUrl.startsWith('https://');

  bool get _isDataUriImage => product.imageUrl.startsWith('data:image/');

  bool get _isAssetImage => product.imageUrl.startsWith('assets/images/');

  String? get _resolvedAssetPath {
    if (_isAssetImage) return product.imageUrl;
    switch (product.id) {
      case 'pipoca-gourmet':
        return 'assets/images/pipoca_gourmet.jpg';
      case 'pipoca-gourmet-creme':
        return 'assets/images/pipoca_creme.jpg';
      case 'bolo-caseiro':
        return 'assets/images/bolo_caseiro.jpg';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDataUriImage) {
      try {
        final commaIndex = product.imageUrl.indexOf(',');
        if (commaIndex > 0) {
          final bytes =
              base64Decode(product.imageUrl.substring(commaIndex + 1));
          return SizedBox(
            height: height,
            width: double.infinity,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              errorBuilder: (_, _, _) => _buildFallbackIllustration(),
            ),
          );
        }
      } catch (_) {
        return _buildFallbackIllustration();
      }
    }

    if (_isNetworkImage) {
      final optimizedUrl =
          CloudinaryService.optimizeCloudinaryUrl(product.imageUrl);
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Image.network(
          optimizedUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (_, _, _) => _buildFallbackIllustration(),
        ),
      );
    }

    final assetPath = _resolvedAssetPath;
    if (assetPath != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (_, _, _) => _buildFallbackIllustration(),
        ),
      );
    }

    return _buildFallbackIllustration();
  }

  Widget _buildFallbackIllustration() {
    switch (product.id) {
      case 'pipoca-gourmet':
        return _buildKraftBagsIllustration();
      case 'pipoca-gourmet-creme':
        return _buildCreamPotsIllustration();
      case 'bolo-caseiro':
        return _buildHomemadeCakesIllustration();
      default:
        return _buildGenericSweetIllustration();
    }
  }

  /// Ilustração dos 3 pacotes Kraft com selo rosa da Pipoca Gourmet
  Widget _buildKraftBagsIllustration() {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3F7), Color(0xFFFCE4EC)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _KraftBagWidget(
                popcornColor: const Color(0xFF4A3B39), // Oreo
                accentColor: Colors.white70,
                height: height * 0.78,
              ),
              const SizedBox(width: 10),
              _KraftBagWidget(
                popcornColor: const Color(0xFFFFF3D1), // Ninho
                accentColor: const Color(0xFFE6C885),
                height: height * 0.84,
              ),
              const SizedBox(width: 10),
              _KraftBagWidget(
                popcornColor: const Color(0xFFFFEAB5), // Ninho
                accentColor: const Color(0xFFD9B66C),
                height: height * 0.78,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ilustração dos 2 potes de Pipoca Gourmet com Creme (Ninho c/ Nutella e Ninho)
  Widget _buildCreamPotsIllustration() {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6F9), Color(0xFFFCE6EE)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CreamPotWidget(
            topSwirlColor: const Color(0xFF4E2718), // Nutella
            baseCreamColor: const Color(0xFFFFF5DC), // Ninho
            height: height * 0.78,
          ),
          const SizedBox(width: 16),
          _CreamPotWidget(
            topSwirlColor: const Color(0xFFFFECB8), // Creme Ninho
            baseCreamColor: const Color(0xFFFFFBF0),
            height: height * 0.78,
          ),
        ],
      ),
    );
  }

  /// Ilustração dos 3 Bolos Caseiros na embalagem transparente com selo Bella Lu
  Widget _buildHomemadeCakesIllustration() {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF5F8), Color(0xFFFADCE6)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CakeBoxWidget(
            cakeColor: const Color(0xFF422114),
            toppingColor: const Color(0xFF2B130A),
            size: height * 0.56,
          ),
          const SizedBox(width: 10),
          _CakeBoxWidget(
            cakeColor: const Color(0xFFFFF3CC),
            toppingColor: const Color(0xFFF2DC9B),
            size: height * 0.60,
          ),
          const SizedBox(width: 10),
          _CakeBoxWidget(
            cakeColor: const Color(0xFF4A2516),
            toppingColor: const Color(0xFF33170C),
            size: height * 0.56,
          ),
        ],
      ),
    );
  }

  Widget _buildGenericSweetIllustration() {
    return Container(
      height: height,
      color: BellaColors.pinkSoft,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BellaBrandLogo(size: 68),
          SizedBox(height: 8),
          Icon(Icons.cake_rounded, color: BellaColors.pinkPrimary, size: 32),
        ],
      ),
    );
  }
}

class _KraftBagWidget extends StatelessWidget {
  final Color popcornColor;
  final Color accentColor;
  final double height;

  const _KraftBagWidget({
    required this.popcornColor,
    required this.accentColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * 0.54;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD7A97C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB88657), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 8,
            margin: const EdgeInsets.only(top: 4, left: 4, right: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC49264),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const BellaBrandLogo(size: 36),
          Container(
            height: height * 0.34,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: popcornColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: Center(
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: List.generate(
                  6,
                  (_) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _CreamPotWidget extends StatelessWidget {
  final Color topSwirlColor;
  final Color baseCreamColor;
  final double height;

  const _CreamPotWidget({
    required this.topSwirlColor,
    required this.baseCreamColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * 0.78;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseCreamColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(14),
          bottom: Radius.circular(24),
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: height * 0.28,
            decoration: BoxDecoration(
              color: topSwirlColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          const BellaBrandLogo(size: 42),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _CakeBoxWidget extends StatelessWidget {
  final Color cakeColor;
  final Color toppingColor;
  final double size;

  const _CakeBoxWidget({
    required this.cakeColor,
    required this.toppingColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cakeColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: toppingColor, width: 3),
        ),
        child: const Center(
          child: BellaBrandLogo(size: 36),
        ),
      ),
    );
  }
}
