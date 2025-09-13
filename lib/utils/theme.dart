import 'package:flutter/material.dart';
import 'package:attendance_pro_app/utils/constants.dart';

class AppTheme {
  // ================== COLOR SCHEMES ==================
  
  static ColorScheme get _lightColorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    background: AppColors.background,
    onBackground: AppColors.onBackground,
    error: AppColors.error,
    onError: AppColors.onError,
  );
  
  static ColorScheme get _darkColorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    surface: AppColors.gray800,
    onSurface: AppColors.white,
    background: AppColors.gray900,
    onBackground: AppColors.white,
    error: AppColors.error,
    onError: AppColors.onError,
  );
  
  // ================== TEXT THEMES ==================
  
  static TextTheme get _textTheme => const TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.22,
    ),
    
    // Headline styles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.33,
    ),
    
    // Title styles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    
    // Label styles
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.45,
    ),
    
    // Body styles
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.33,
    ),
  );
  
  // ================== COMPONENT THEMES ==================
  
  static AppBarTheme get _appBarTheme => const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
    ),
    iconTheme: IconThemeData(
      size: AppSizes.iconMd,
    ),
  );
  
  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: AppConfig.defaultElevation,
      minimumSize: const Size(double.infinity, AppSizes.buttonHeightLg),
      maximumSize: const Size(double.infinity, AppSizes.buttonHeightLg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      textStyle: const TextStyle(
        fontSize: AppTextSizes.md,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
    ),
  );
  
  static OutlinedButtonThemeData get _outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, AppSizes.buttonHeightLg),
      maximumSize: const Size(double.infinity, AppSizes.buttonHeightLg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      side: const BorderSide(width: 1),
      textStyle: const TextStyle(
        fontSize: AppTextSizes.md,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
    ),
  );
  
  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, AppSizes.buttonHeightMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      textStyle: const TextStyle(
        fontSize: AppTextSizes.md,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
    ),
  );
  
  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSizes.md,
      vertical: AppSizes.md,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      borderSide: const BorderSide(color: AppColors.gray300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      borderSide: const BorderSide(color: AppColors.gray300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    labelStyle: const TextStyle(
      fontSize: AppTextSizes.md,
      fontWeight: FontWeight.w400,
    ),
    hintStyle: TextStyle(
      fontSize: AppTextSizes.md,
      color: AppColors.gray500,
    ),
    errorStyle: const TextStyle(
      fontSize: AppTextSizes.sm,
      color: AppColors.error,
    ),
    helperStyle: TextStyle(
      fontSize: AppTextSizes.sm,
      color: AppColors.gray600,
    ),
    prefixIconColor: AppColors.gray500,
    suffixIconColor: AppColors.gray500,
  );
  
  // ✅ FIXED: Changed from CardTheme to CardThemeData
  static CardThemeData get _cardTheme => CardThemeData(
    elevation: AppConfig.defaultElevation,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
    ),
    margin: const EdgeInsets.all(AppSizes.sm),
    clipBehavior: Clip.antiAlias,
  );
  
  static ListTileThemeData get _listTileTheme => const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSizes.md,
      vertical: AppSizes.sm,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusMd)),
    ),
    titleTextStyle: TextStyle(
      fontSize: AppTextSizes.md,
      fontWeight: FontWeight.w500,
    ),
    subtitleTextStyle: TextStyle(
      fontSize: AppTextSizes.sm,
    ),
    leadingAndTrailingTextStyle: TextStyle(
      fontSize: AppTextSizes.sm,
      fontWeight: FontWeight.w500,
    ),
  );
  
  static ChipThemeData get _chipTheme => ChipThemeData(
    backgroundColor: AppColors.gray100,
    selectedColor: AppColors.primary.withOpacity(0.12),
    secondarySelectedColor: AppColors.secondary.withOpacity(0.12),
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
    labelStyle: const TextStyle(fontSize: AppTextSizes.sm),
    secondaryLabelStyle: const TextStyle(fontSize: AppTextSizes.sm),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusRound),
    ),
    side: const BorderSide(color: AppColors.transparent),
  );
  
  // ✅ FIXED: Changed from TabBarTheme to TabBarThemeData
  static TabBarThemeData get _tabBarTheme => const TabBarThemeData(
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.gray600,
    indicatorColor: AppColors.primary,
    indicatorSize: TabBarIndicatorSize.label,
    labelStyle: TextStyle(
      fontSize: AppTextSizes.sm,
      fontWeight: FontWeight.w500,
    ),
    unselectedLabelStyle: TextStyle(
      fontSize: AppTextSizes.sm,
      fontWeight: FontWeight.w400,
    ),
  );
  
  static BottomNavigationBarThemeData get _bottomNavTheme => const BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.gray500,
    selectedLabelStyle: TextStyle(
      fontSize: AppTextSizes.xs,
      fontWeight: FontWeight.w500,
    ),
    unselectedLabelStyle: TextStyle(
      fontSize: AppTextSizes.xs,
      fontWeight: FontWeight.w400,
    ),
    elevation: 8,
  );
  
  static FloatingActionButtonThemeData get _fabTheme => FloatingActionButtonThemeData(
    elevation: 6,
    focusElevation: 8,
    hoverElevation: 8,
    highlightElevation: 12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusXl),
    ),
  );
  
  static DialogThemeData get _dialogTheme => DialogThemeData(
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusXl),
    ),
    titleTextStyle: const TextStyle(
      fontSize: AppTextSizes.xl,
      color: AppColors.black,
      fontWeight: FontWeight.w500,
    ),
    contentTextStyle: const TextStyle(
      fontSize: AppTextSizes.md,
      color: AppColors.black,
    ),
  );
  
  static BottomSheetThemeData get _bottomSheetTheme => const BottomSheetThemeData(
    elevation: 16,
    modalElevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
    ),
    clipBehavior: Clip.antiAlias,
  );
  
  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
    ),
    behavior: SnackBarBehavior.floating,
    contentTextStyle: const TextStyle(
      fontSize: AppTextSizes.md,
      fontWeight: FontWeight.w400,
    ),
  );
  
  // ================== MAIN THEMES ==================
  
  /// Light theme configuration
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    
    // Typography
    fontFamily: 'Inter',
    
    // Component themes
    appBarTheme: _appBarTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
    cardTheme: _cardTheme,
    listTileTheme: _listTileTheme,
    chipTheme: _chipTheme,
    tabBarTheme: _tabBarTheme,
    bottomNavigationBarTheme: _bottomNavTheme,
    floatingActionButtonTheme: _fabTheme,
    dialogTheme: _dialogTheme,
    bottomSheetTheme: _bottomSheetTheme,
    snackBarTheme: _snackBarTheme,
    
    // Visual density
    visualDensity: VisualDensity.adaptivePlatformDensity,
    
    // Material properties
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    
    // Page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    
    // Splash color
    splashColor: AppColors.primary.withOpacity(0.1),
    highlightColor: AppColors.primary.withOpacity(0.05),
    
    // Focus color
    focusColor: AppColors.primary.withOpacity(0.12),
    hoverColor: AppColors.primary.withOpacity(0.04),
    
    // Divider
    dividerColor: AppColors.gray200,
    
    // Icon theme
    iconTheme: const IconThemeData(
      size: AppSizes.iconMd,
      color: AppColors.gray700,
    ),
    primaryIconTheme: const IconThemeData(
      size: AppSizes.iconMd,
      color: AppColors.onPrimary,
    ),
    
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.gray400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary.withOpacity(0.5);
        }
        return AppColors.gray300;
      }),
    ),
    
    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.gray400),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
    ),
    
    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.gray400;
      }),
    ),
    
    // Slider theme
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.primary.withOpacity(0.3),
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withOpacity(0.12),
      valueIndicatorColor: AppColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: AppColors.onPrimary,
        fontSize: AppTextSizes.sm,
      ),
    ),
    
    // Progress indicator theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.gray200,
      circularTrackColor: AppColors.gray200,
    ),
  );
  
  /// Dark theme configuration
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    textTheme: _textTheme.apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    ),
    
    // Typography
    fontFamily: 'Inter',
    
    // Component themes (adapted for dark mode)
    appBarTheme: _appBarTheme.copyWith(
      backgroundColor: AppColors.gray800,
      foregroundColor: AppColors.white,
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    inputDecorationTheme: _inputDecorationTheme.copyWith(
      fillColor: AppColors.gray700,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        borderSide: const BorderSide(color: AppColors.gray600),
      ),
    ),
    cardTheme: _cardTheme.copyWith(
      color: AppColors.gray800,
    ),
    listTileTheme: _listTileTheme,
    chipTheme: _chipTheme.copyWith(
      backgroundColor: AppColors.gray700,
    ),
    tabBarTheme: _tabBarTheme.copyWith(
      unselectedLabelColor: AppColors.gray400,
    ),
    bottomNavigationBarTheme: _bottomNavTheme.copyWith(
      backgroundColor: AppColors.gray800,
      unselectedItemColor: AppColors.gray400,
    ),
    floatingActionButtonTheme: _fabTheme,
    dialogTheme: _dialogTheme.copyWith(
      backgroundColor: AppColors.gray800,
    ),
    bottomSheetTheme: _bottomSheetTheme.copyWith(
      backgroundColor: AppColors.gray800,
    ),
    snackBarTheme: _snackBarTheme.copyWith(
      backgroundColor: AppColors.gray700,
      contentTextStyle: const TextStyle(
        fontSize: AppTextSizes.md,
        color: AppColors.white,
      ),
    ),
    
    // Visual density
    visualDensity: VisualDensity.adaptivePlatformDensity,
    
    // Material properties
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    
    // Page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    
    // Colors
    scaffoldBackgroundColor: AppColors.gray900,
    canvasColor: AppColors.gray800,
    cardColor: AppColors.gray800,
    dividerColor: AppColors.gray600,
    
    // Splash color
    splashColor: AppColors.primary.withOpacity(0.1),
    highlightColor: AppColors.primary.withOpacity(0.05),
    
    // Focus color
    focusColor: AppColors.primary.withOpacity(0.12),
    hoverColor: AppColors.primary.withOpacity(0.04),
    
    // Icon theme
    iconTheme: const IconThemeData(
      size: AppSizes.iconMd,
      color: AppColors.white,
    ),
    primaryIconTheme: const IconThemeData(
      size: AppSizes.iconMd,
      color: AppColors.onPrimary,
    ),
    
    // Component themes for dark mode
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.gray500;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary.withOpacity(0.5);
        }
        return AppColors.gray600;
      }),
    ),
    
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.gray500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
    ),
    
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.gray500;
      }),
    ),
    
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.primary.withOpacity(0.3),
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withOpacity(0.12),
      valueIndicatorColor: AppColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: AppColors.onPrimary,
        fontSize: AppTextSizes.sm,
      ),
    ),
    
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.gray600,
      circularTrackColor: AppColors.gray600,
    ),
  );
}

// Custom theme extensions for additional properties
@immutable
class AttendanceThemeExtension extends ThemeExtension<AttendanceThemeExtension> {
  final Color successColor;
  final Color warningColor;
  final Color infoColor;
  final Color presentColor;
  final Color absentColor;
  final Color pendingColor;
  final Color liveSessionColor;
  final Color upcomingSessionColor;
  final Color endedSessionColor;

  const AttendanceThemeExtension({
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.presentColor,
    required this.absentColor,
    required this.pendingColor,
    required this.liveSessionColor,
    required this.upcomingSessionColor,
    required this.endedSessionColor,
  });

  @override
  AttendanceThemeExtension copyWith({
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    Color? presentColor,
    Color? absentColor,
    Color? pendingColor,
    Color? liveSessionColor,
    Color? upcomingSessionColor,
    Color? endedSessionColor,
  }) {
    return AttendanceThemeExtension(
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      presentColor: presentColor ?? this.presentColor,
      absentColor: absentColor ?? this.absentColor,
      pendingColor: pendingColor ?? this.pendingColor,
      liveSessionColor: liveSessionColor ?? this.liveSessionColor,
      upcomingSessionColor: upcomingSessionColor ?? this.upcomingSessionColor,
      endedSessionColor: endedSessionColor ?? this.endedSessionColor,
    );
  }

  @override
  AttendanceThemeExtension lerp(
    ThemeExtension<AttendanceThemeExtension>? other,
    double t,
  ) {
    if (other is! AttendanceThemeExtension) {
      return this;
    }
    return AttendanceThemeExtension(
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      presentColor: Color.lerp(presentColor, other.presentColor, t)!,
      absentColor: Color.lerp(absentColor, other.absentColor, t)!,
      pendingColor: Color.lerp(pendingColor, other.pendingColor, t)!,
      liveSessionColor: Color.lerp(liveSessionColor, other.liveSessionColor, t)!,
      upcomingSessionColor: Color.lerp(upcomingSessionColor, other.upcomingSessionColor, t)!,
      endedSessionColor: Color.lerp(endedSessionColor, other.endedSessionColor, t)!,
    );
  }

  static const AttendanceThemeExtension light = AttendanceThemeExtension(
    successColor: AppColors.success,
    warningColor: AppColors.warning,
    infoColor: AppColors.info,
    presentColor: AppColors.present,
    absentColor: AppColors.absent,
    pendingColor: AppColors.pending,
    liveSessionColor: AppColors.live,
    upcomingSessionColor: AppColors.upcoming,
    endedSessionColor: AppColors.ended,
  );

  static const AttendanceThemeExtension dark = AttendanceThemeExtension(
    successColor: AppColors.success,
    warningColor: AppColors.warning,
    infoColor: AppColors.info,
    presentColor: AppColors.present,
    absentColor: AppColors.absent,
    pendingColor: AppColors.pending,
    liveSessionColor: AppColors.live,
    upcomingSessionColor: AppColors.upcoming,
    endedSessionColor: AppColors.ended,
  );
}
