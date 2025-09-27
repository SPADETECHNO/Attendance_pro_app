import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isText;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final MainAxisSize mainAxisSize;
  final bool enabled;
  final double elevation;
  final TextStyle? textStyle;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isText = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.mainAxisSize = MainAxisSize.max,
    this.enabled = true,
    this.elevation = 2.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine if button is effectively disabled
    final isDisabled = !enabled || isLoading || onPressed == null;
    
    // Calculate colors based on button type and state
    Color finalBackgroundColor;
    Color finalTextColor;
    Color? finalBorderColor;
    
    if (isText) {
      finalBackgroundColor = Colors.transparent;
      finalTextColor = isDisabled 
          ? colorScheme.onSurface.withOpacity(0.38)
          : textColor ?? colorScheme.primary;
      finalBorderColor = Colors.transparent;
    } else if (isOutlined) {
      finalBackgroundColor = Colors.transparent;
      finalTextColor = isDisabled
          ? colorScheme.onSurface.withOpacity(0.38)
          : textColor ?? colorScheme.primary;
      finalBorderColor = isDisabled
          ? colorScheme.onSurface.withOpacity(0.12)
          : borderColor ?? colorScheme.outline;
    } else {
      // Filled button (default)
      finalBackgroundColor = isDisabled
          ? colorScheme.onSurface.withOpacity(0.12)
          : backgroundColor ?? colorScheme.primary;
      finalTextColor = isDisabled
          ? colorScheme.onSurface.withOpacity(0.38)
          : textColor ?? colorScheme.onPrimary;
      finalBorderColor = null;
    }
    
    final buttonStyle = isText
        ? TextButton.styleFrom(
            foregroundColor: finalTextColor,
            backgroundColor: finalBackgroundColor,
            minimumSize: Size(
              width ?? (mainAxisSize == MainAxisSize.min ? 0 : 0),
              height ?? AppSizes.buttonHeightMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? AppSizes.radiusLg),
            ),
            padding: padding ?? const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            textStyle: textStyle ?? theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        : isOutlined
            ? OutlinedButton.styleFrom(
                foregroundColor: finalTextColor,
                backgroundColor: finalBackgroundColor,
                side: BorderSide(
                  color: finalBorderColor!,
                  width: 1.5,
                ),
                minimumSize: Size(
                  width ?? (mainAxisSize == MainAxisSize.min ? 0 : double.infinity),
                  height ?? AppSizes.buttonHeightLg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius ?? AppSizes.radiusLg),
                ),
                padding: padding ?? const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                textStyle: textStyle ?? theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : ElevatedButton.styleFrom(
                foregroundColor: finalTextColor,
                backgroundColor: finalBackgroundColor,
                elevation: isDisabled ? 0 : elevation,
                shadowColor: colorScheme.shadow,
                minimumSize: Size(
                  width ?? (mainAxisSize == MainAxisSize.min ? 0 : double.infinity),
                  height ?? AppSizes.buttonHeightLg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius ?? AppSizes.radiusLg),
                ),
                padding: padding ?? const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                textStyle: textStyle ?? theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              );

    Widget buttonChild = _buildButtonContent(finalTextColor);

    if (isText) {
      return TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: buttonChild,
      );
    } else if (isOutlined) {
      return OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: buttonChild,
      );
    } else {
      return ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: buttonChild,
      );
    }
  }

  Widget _buildButtonContent(Color textColor) {
    if (isLoading) {
      return Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: textColor,
              size: AppSizes.iconSm,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text('Loading...'),
        ],
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppSizes.iconSm,
            color: textColor,
          ),
          const SizedBox(width: AppSizes.sm),
          Flexible(child: Text(text)),
        ],
      );
    }

    return Text(text);
  }
}

// Specialized button variants
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      width: width,
      height: height,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      isOutlined: true,
      width: width,
      height: height,
    );
  }
}

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const DangerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      width: width,
      height: height,
    );
  }
}

class SuccessButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const SuccessButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: AppColors.success,
      textColor: AppColors.onSuccess,
      width: width,
      height: height,
    );
  }
}

class FloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool mini;
  final bool isLoading;

  const FloatingButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.mini = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
      mini: mini,
      backgroundColor: backgroundColor ?? colorScheme.primary,
      foregroundColor: foregroundColor ?? colorScheme.onPrimary,
      child: isLoading
          ? SizedBox(
              width: AppSizes.iconSm,
              height: AppSizes.iconSm,
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: foregroundColor ?? colorScheme.onPrimary,
                size: AppSizes.iconSm,
              ),
            )
          : Icon(icon),
    );
  }
}

// Icon button variant
class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double? size;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size,
    this.iconSize,
    this.padding,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (backgroundColor != null) {
      return Container(
        width: size ?? AppSizes.buttonHeightMd,
        height: size ?? AppSizes.buttonHeightMd,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: IconButton(
          onPressed: isLoading ? null : onPressed,
          tooltip: tooltip,
          icon: isLoading
              ? SizedBox(
                  width: iconSize ?? AppSizes.iconSm,
                  height: iconSize ?? AppSizes.iconSm,
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: color ?? theme.iconTheme.color ?? theme.colorScheme.onSurface,
                    size: iconSize ?? AppSizes.iconSm,
                  ),
                )
              : Icon(
                  icon,
                  color: color,
                  size: iconSize ?? AppSizes.iconMd,
                ),
          padding: padding ?? const EdgeInsets.all(AppSizes.sm),
        ),
      );
    }

    return IconButton(
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
      icon: isLoading
          ? SizedBox(
              width: iconSize ?? AppSizes.iconSm,
              height: iconSize ?? AppSizes.iconSm,
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: color ?? theme.iconTheme.color ?? theme.colorScheme.onSurface,
                size: iconSize ?? AppSizes.iconSm,
              ),
            )
          : Icon(
              icon,
              color: color,
              size: iconSize ?? AppSizes.iconMd,
            ),
      padding: padding ?? const EdgeInsets.all(AppSizes.sm),
    );
  }
}
