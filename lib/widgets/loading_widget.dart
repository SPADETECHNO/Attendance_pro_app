import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double? size;
  final LoadingType type;
  final bool showMessage;
  final EdgeInsetsGeometry? padding;
  final double? opacity;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size,
    this.type = LoadingType.progressiveDots,
    this.showMessage = true,
    this.padding,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveSize = size ?? 50.0;
    final effectiveMessage = message ?? AppStrings.loading;

    Widget loadingAnimation = _buildLoadingAnimation(effectiveColor, effectiveSize);
    
    if (opacity != null) {
      loadingAnimation = Opacity(
        opacity: opacity!,
        child: loadingAnimation,
      );
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSizes.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loadingAnimation,
            if (showMessage && effectiveMessage.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text(
                effectiveMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation(Color color, double size) {
    switch (type) {
      case LoadingType.progressiveDots:
        return LoadingAnimationWidget.progressiveDots(
          color: color,
          size: size,
        );
      case LoadingType.staggeredDotsWave:
        return LoadingAnimationWidget.staggeredDotsWave(
          color: color,
          size: size,
        );
      case LoadingType.inkDrop:
        return LoadingAnimationWidget.inkDrop(
          color: color,
          size: size,
        );
      case LoadingType.twistingDots:
        return LoadingAnimationWidget.twistingDots(
          leftDotColor: color,
          rightDotColor: color.withOpacity(0.7),
          size: size,
        );
      case LoadingType.threeRotatingDots:
        return LoadingAnimationWidget.threeRotatingDots(
          color: color,
          size: size,
        );
      case LoadingType.bouncingBall:
        return LoadingAnimationWidget.bouncingBall(
          color: color,
          size: size,
        );
      case LoadingType.flickr:
        return LoadingAnimationWidget.flickr(
          leftDotColor: color,
          rightDotColor: color.withOpacity(0.7),
          size: size,
        );
      case LoadingType.hexagonDots:
        return LoadingAnimationWidget.hexagonDots(
          color: color,
          size: size,
        );
      case LoadingType.beat:
        return LoadingAnimationWidget.beat(
          color: color,
          size: size,
        );
      case LoadingType.twoRotatingArc:
        return LoadingAnimationWidget.twoRotatingArc(
          color: color,
          size: size,
        );
      case LoadingType.horizontalRotatingDots:
        return LoadingAnimationWidget.horizontalRotatingDots(
          color: color,
          size: size,
        );
      case LoadingType.newtonCradle:
        return LoadingAnimationWidget.newtonCradle(
          color: color,
          size: size,
        );
      case LoadingType.stretchedDots:
        return LoadingAnimationWidget.stretchedDots(
          color: color,
          size: size,
        );
      case LoadingType.halfTriangleDot:
        return LoadingAnimationWidget.halfTriangleDot(
          color: color,
          size: size,
        );
      case LoadingType.dotsTriangle:
        return LoadingAnimationWidget.dotsTriangle(
          color: color,
          size: size,
        );
      case LoadingType.fourRotatingDots:
        return LoadingAnimationWidget.fourRotatingDots(
          color: color,
          size: size,
        );
      case LoadingType.fallingDot:
        return LoadingAnimationWidget.fallingDot(
          color: color,
          size: size,
        );
      case LoadingType.waveDots:
        return LoadingAnimationWidget.waveDots(
          color: color,
          size: size,
        );
      case LoadingType.threeArchedCircle:
        return LoadingAnimationWidget.threeArchedCircle(
          color: color,
          size: size,
        );
      case LoadingType.discreteCircle:
        return LoadingAnimationWidget.discreteCircle(
          color: color,
          size: size,
        );
    }
  }
}

enum LoadingType {
  progressiveDots,
  staggeredDotsWave,
  inkDrop,
  twistingDots,
  threeRotatingDots,
  bouncingBall,
  flickr,
  hexagonDots,
  beat,
  twoRotatingArc,
  horizontalRotatingDots,
  newtonCradle,
  stretchedDots,
  halfTriangleDot,
  dotsTriangle,
  fourRotatingDots,
  fallingDot,
  waveDots,
  threeArchedCircle,
  discreteCircle,
}

// Specialized loading widgets
class FullScreenLoading extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;
  final LoadingType type;

  const FullScreenLoading({
    super.key,
    this.message,
    this.backgroundColor,
    this.type = LoadingType.progressiveDots,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.background,
      body: LoadingWidget(
        message: message,
        type: type,
      ),
    );
  }
}

class OverlayLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? overlayColor;
  final LoadingType type;

  const OverlayLoading({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.overlayColor,
    this.type = LoadingType.progressiveDots,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withOpacity(0.3),
            child: LoadingWidget(
              message: message,
              type: type,
            ),
          ),
      ],
    );
  }
}

class InlineLoading extends StatelessWidget {
  final String? message;
  final Color? color;
  final double? size;
  final LoadingType type;
  final MainAxisAlignment alignment;

  const InlineLoading({
    super.key,
    this.message,
    this.color,
    this.size,
    this.type = LoadingType.staggeredDotsWave,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveSize = size ?? 30.0;

    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        LoadingAnimationWidget.staggeredDotsWave(
          color: effectiveColor,
          size: effectiveSize,
        ),
        if (message != null) ...[
          const SizedBox(width: AppSizes.sm),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class CardLoading extends StatelessWidget {
  final double? height;
  final String? message;
  final LoadingType type;

  const CardLoading({
    super.key,
    this.height,
    this.message,
    this.type = LoadingType.progressiveDots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        height: height ?? 200,
        padding: const EdgeInsets.all(AppSizes.lg),
        child: LoadingWidget(
          message: message,
          type: type,
          showMessage: message != null,
        ),
      ),
    );
  }
}

class ListTileLoading extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry? padding;

  const ListTileLoading({
    super.key,
    this.itemCount = 5,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          child: Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                ),
              ),
              title: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                ),
              ),
              subtitle: Container(
                height: 12,
                width: 150,
                margin: const EdgeInsets.only(top: AppSizes.xs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface.withOpacity(0.3);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSizes.iconXl + 20,
              color: effectiveIconColor,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSizes.lg),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
