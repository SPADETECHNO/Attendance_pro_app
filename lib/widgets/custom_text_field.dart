import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_pro_app/utils/constants.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? initialValue;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final Function()? onTap;
  final Function(String)? onSubmitted;
  final Function()? onEditingComplete;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final double? height;
  final IconData? prefixIcon;
  final Widget? prefix;
  final IconData? suffixIcon;
  final Widget? suffix;
  final VoidCallback? onSuffixIconTap;
  final VoidCallback? onPrefixIconTap;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? helperStyle;
  final TextStyle? errorStyle;
  final bool isDense;
  final bool filled;
  final String? counterText;
  final bool showCounter;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.initialValue,
    this.controller,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.onEditingComplete,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.height,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.onSuffixIconTap,
    this.onPrefixIconTap,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.borderRadius,
    this.contentPadding,
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.helperStyle,
    this.errorStyle,
    this.isDense = false,
    this.filled = true,
    this.counterText,
    this.showCounter = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
    if (widget.onSuffixIconTap != null) {
      widget.onSuffixIconTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate colors
    final effectiveFillColor = widget.fillColor ?? 
        (widget.filled ? colorScheme.surfaceVariant.withOpacity(0.5) : Colors.transparent);
    
    final effectiveBorderColor = widget.borderColor ?? colorScheme.outline.withOpacity(0.5);
    final effectiveFocusedBorderColor = widget.focusedBorderColor ?? colorScheme.primary;
    final effectiveErrorBorderColor = widget.errorBorderColor ?? colorScheme.error;

    // Build prefix widget
    Widget? prefixWidget;
    if (widget.prefix != null) {
      prefixWidget = widget.prefix;
    } else if (widget.prefixIcon != null) {
      prefixWidget = InkWell(
        onTap: widget.onPrefixIconTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.xs),
          child: Icon(
            widget.prefixIcon,
            size: AppSizes.iconSm,
            color: _isFocused 
                ? colorScheme.primary 
                : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    // Build suffix widget
    Widget? suffixWidget;
    if (widget.suffix != null) {
      suffixWidget = widget.suffix;
    } else if (widget.obscureText) {
      // Auto password visibility toggle
      suffixWidget = InkWell(
        onTap: _toggleObscureText,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.xs),
          child: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
            size: AppSizes.iconSm,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    } else if (widget.suffixIcon != null) {
      suffixWidget = InkWell(
        onTap: widget.onSuffixIconTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.xs),
          child: Icon(
            widget.suffixIcon,
            size: AppSizes.iconSm,
            color: _isFocused 
                ? colorScheme.primary 
                : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: widget.labelStyle ?? theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
        ],
        
        // Text Field
        SizedBox(
          height: widget.height,
          child: TextFormField(
            initialValue: widget.controller == null ? widget.initialValue : null,
            controller: widget.controller,
            focusNode: _focusNode,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            onFieldSubmitted: widget.onSubmitted,
            onEditingComplete: widget.onEditingComplete,
            obscureText: _obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.showCounter ? widget.maxLength : null,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            style: widget.textStyle ?? theme.textTheme.bodyMedium?.copyWith(
              color: widget.enabled 
                  ? colorScheme.onSurface 
                  : colorScheme.onSurface.withOpacity(0.38),
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              counterText: widget.counterText ?? (widget.showCounter ? null : ''),
              filled: widget.filled,
              fillColor: widget.enabled ? effectiveFillColor : effectiveFillColor.withOpacity(0.5),
              isDense: widget.isDense,
              
              // Prefix & Suffix
              prefixIcon: prefixWidget,
              suffixIcon: suffixWidget,
              
              // Content padding
              contentPadding: widget.contentPadding ?? EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: widget.maxLines > 1 ? AppSizes.md : AppSizes.sm,
              ),
              
              // Borders
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: effectiveBorderColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: effectiveBorderColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: effectiveFocusedBorderColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: effectiveErrorBorderColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: effectiveErrorBorderColor,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withOpacity(0.12),
                  width: 1,
                ),
              ),
              
              // Text styles
              hintStyle: widget.hintStyle ?? theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              helperStyle: widget.helperStyle ?? theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              errorStyle: widget.errorStyle ?? theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Specialized text field variants
class EmailTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;

  const EmailTextField({
    super.key,
    this.label = 'Email',
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      hint: hint ?? 'Enter your email address',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.email_outlined,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class PasswordTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;
  final bool showStrengthIndicator;

  const PasswordTextField({
    super.key,
    this.label = 'Password',
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.showStrengthIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      hint: hint ?? 'Enter your password',
      controller: controller,
      obscureText: true,
      prefixIcon: Icons.lock_outline,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      helperText: showStrengthIndicator ? 'Password must be at least 6 characters' : null,
    );
  }
}

class PhoneTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;

  const PhoneTextField({
    super.key,
    this.label = 'Phone',
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      hint: hint ?? 'Enter your phone number',
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.phone_outlined,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class SearchTextField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;

  const SearchTextField({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: '',
      hint: hint ?? 'Search...',
      controller: controller,
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true ? Icons.clear : null,
      onSuffixIconTap: () {
        controller?.clear();
        if (onClear != null) onClear!();
        if (onChanged != null) onChanged!('');
      },
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      textInputAction: TextInputAction.search,
    );
  }
}

class NumberTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;
  final int? maxLength;
  final bool allowDecimal;

  const NumberTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: allowDecimal 
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: allowDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      prefixIcon: Icons.numbers,
    );
  }
}
