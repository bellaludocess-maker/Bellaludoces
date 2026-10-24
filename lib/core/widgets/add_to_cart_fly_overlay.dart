import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/bella_colors.dart';

/// Exibe uma animação encantadora do doce "voando em arco" até a sacola
/// acompanhado de corações vetoriais quando o cliente adiciona um item.
class AddToCartFlyOverlay {
  AddToCartFlyOverlay._();

  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FlyingSweetAnimation(
        onCompleted: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _FlyingSweetAnimation extends StatefulWidget {
  final VoidCallback onCompleted;

  const _FlyingSweetAnimation({required this.onCompleted});

  @override
  State<_FlyingSweetAnimation> createState() => _FlyingSweetAnimationState();
}

class _FlyingSweetAnimationState extends State<_FlyingSweetAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final startX = size.width * 0.5;
    final startY = size.height * 0.45;
    final endX = size.width * 0.28;
    final endY = size.height - 64;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          // Trajetória parabólica em arco suave até a barra da sacola
          final currentX = startX + (endX - startX) * t;
          final arcLift = math.sin(t * math.pi) * -125;
          final currentY = startY + (endY - startY) * t + arcLift;

          final scale = t < 0.35
              ? 0.65 + (t / 0.35) * 0.65
              : 1.30 - ((t - 0.35) / 0.65) * 0.60;
          final opacity = t > 0.88 ? (1.0 - t) / 0.12 : 1.0;

          return Stack(
            children: [
              // Corações vetoriais que flutuam suavemente durante o arco
              if (t < 0.80) ...[
                _buildFloatingHeart(
                  startX - 44 * (t * 1.6),
                  startY - 64 * (t * 1.6),
                  1.0 - (t / 0.80),
                  22,
                ),
                _buildFloatingHeart(
                  startX + 48 * (t * 1.6),
                  startY - 52 * (t * 1.6),
                  1.0 - (t / 0.80),
                  18,
                ),
                _buildFloatingHeart(
                  startX + 10 * (t * 1.6),
                  startY - 84 * (t * 1.6),
                  1.0 - (t / 0.80),
                  26,
                ),
              ],

              // Bolha do doce voando para a sacola
              Positioned(
                left: currentX - 28,
                top: currentY - 28,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: BellaColors.promoBannerGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                BellaColors.pinkPrimary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          Text(
                            '+1',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFloatingHeart(
    double left,
    double top,
    double opacity,
    double iconSize,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Icon(
          Icons.favorite_rounded,
          color: BellaColors.pinkPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}
