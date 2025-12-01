import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.drawerForeground,
    required this.drawerSecondary,
    required this.drawerBadgeBackground,
    required this.drawerBadgeForeground,
    required this.drawerIconColor,
    required this.drawerAvatarBackground,
    required this.toastForeground,
    required this.toastBackground,
    required this.surfaceBorder,
    required this.textSecondary,
  });

  final Color drawerForeground;
  final Color drawerSecondary;
  final Color drawerBadgeBackground;
  final Color drawerBadgeForeground;
  final Color drawerIconColor;
  final Color drawerAvatarBackground;
  final Color toastForeground;
  final Color toastBackground;
  final Color surfaceBorder;
  final Color textSecondary;

  static const AppPalette light = AppPalette(
    drawerForeground: AppTheme.neutral0,
    drawerSecondary: Color(0xCCFFFFFF),
    drawerBadgeBackground: Color(0x33FFFFFF),
    drawerBadgeForeground: AppTheme.neutral0,
    drawerIconColor: AppTheme.neutral0,
    drawerAvatarBackground: AppTheme.neutral0,
    toastForeground: AppTheme.neutral0,
    toastBackground: AppTheme.primaryColor,
    surfaceBorder: AppTheme.neutral20,
    textSecondary: AppTheme.neutral60,
  );

  static const AppPalette dark = AppPalette(
    drawerForeground: AppTheme.neutral0,
    drawerSecondary: Color(0xB3FFFFFF),
    drawerBadgeBackground: Color(0x33FFFFFF),
    drawerBadgeForeground: AppTheme.neutral0,
    drawerIconColor: AppTheme.neutral0,
    drawerAvatarBackground: Color(0x4DFFFFFF),
    toastForeground: AppTheme.neutral0,
    toastBackground: AppTheme.primaryColorLight,
    surfaceBorder: Color(0xFF2D322F),
    textSecondary: AppTheme.neutral40,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? drawerForeground,
    Color? drawerSecondary,
    Color? drawerBadgeBackground,
    Color? drawerBadgeForeground,
    Color? drawerIconColor,
    Color? drawerAvatarBackground,
    Color? toastForeground,
    Color? toastBackground,
    Color? surfaceBorder,
    Color? textSecondary,
  }) {
    return AppPalette(
      drawerForeground: drawerForeground ?? this.drawerForeground,
      drawerSecondary: drawerSecondary ?? this.drawerSecondary,
      drawerBadgeBackground: drawerBadgeBackground ?? this.drawerBadgeBackground,
      drawerBadgeForeground: drawerBadgeForeground ?? this.drawerBadgeForeground,
      drawerIconColor: drawerIconColor ?? this.drawerIconColor,
      drawerAvatarBackground: drawerAvatarBackground ?? this.drawerAvatarBackground,
      toastForeground: toastForeground ?? this.toastForeground,
      toastBackground: toastBackground ?? this.toastBackground,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      drawerForeground: Color.lerp(drawerForeground, other.drawerForeground, t) ?? drawerForeground,
      drawerSecondary: Color.lerp(drawerSecondary, other.drawerSecondary, t) ?? drawerSecondary,
      drawerBadgeBackground:
          Color.lerp(drawerBadgeBackground, other.drawerBadgeBackground, t) ?? drawerBadgeBackground,
      drawerBadgeForeground:
          Color.lerp(drawerBadgeForeground, other.drawerBadgeForeground, t) ?? drawerBadgeForeground,
      drawerIconColor: Color.lerp(drawerIconColor, other.drawerIconColor, t) ?? drawerIconColor,
      drawerAvatarBackground:
          Color.lerp(drawerAvatarBackground, other.drawerAvatarBackground, t) ?? drawerAvatarBackground,
      toastForeground: Color.lerp(toastForeground, other.toastForeground, t) ?? toastForeground,
      toastBackground: Color.lerp(toastBackground, other.toastBackground, t) ?? toastBackground,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t) ?? surfaceBorder,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
    );
  }
}

class AppTheme {
  /// Brand palette — keep existing greens while expanding supporting accents.
  static const Color primaryColor = Color(0xFF007D53);
  static const Color secondaryColor = Color(0xFF00A86B);
  static const Color tertiaryColor = Color(0xFF3AA891);
  static const Color primaryColorLight = Color(0xFF33B37C);

  static const Color successColor = Color(0xFF00C853);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color infoColor = Color(0xFF2D9CDB);

  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral10 = Color(0xFFF6F8F7);
  static const Color neutral20 = Color(0xFFE7EBEA);
  static const Color neutral50 = Color(0xFF92A29D);
  static const Color neutral40 = Color(0xFFB4C1BE);
  static const Color neutral60 = Color(0xFF6F7E7A);
  static const Color neutral80 = Color(0xFF2F3C38);
  static const Color neutral90 = Color(0xFF1D2623);

  // Backwards compatibility aliases
  static const Color surfaceLight = neutral10;
  static const Color surfaceDark = neutral20;
  static const Color dividerColor = neutral20;
  static const Color textPrimary = neutral90;
  static const Color textSecondary = neutral60;

  /// Elevation shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x1A0F2E1D),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];
  
  /// Status Colors helper
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return warningColor;
      case 'supervisor_approved':
      case 'dgs_approved':
      case 'ddgs_approved':
      case 'ad_transport_approved':
        return infoColor;
      case 'transport_officer_assigned':
      case 'driver_accepted':
        return const Color(0xFF9C27B0);
      case 'in_progress':
        return successColor;
      case 'completed':
      case 'returned':
        return successColor;
      case 'rejected':
        return errorColor;
      case 'needs_correction':
        return warningColor;
      default:
        return Colors.grey;
    }
  }
  
  /// Spacing scale (8pt grid)
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  /// Corner radii
  static const double radiusXS = 6;
  static const double radiusS = 10;
  static const double radiusM = 14;
  static const double radiusL = 20;
  static const double radiusXL = 28;

  static BorderRadius get bradiusXS => BorderRadius.circular(radiusXS.toDouble());
  static BorderRadius get bradiusS => BorderRadius.circular(radiusS.toDouble());
  static BorderRadius get bradiusM => BorderRadius.circular(radiusM.toDouble());
  static BorderRadius get bradiusL => BorderRadius.circular(radiusL.toDouble());
  static BorderRadius get bradiusXL => BorderRadius.circular(radiusXL.toDouble());

  /// Elevation tokens
  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 2;
  static const double elevation3 = 4;
  static const double elevation4 = 6;
  
  /// Animation tokens
  static const Duration shortDuration = Duration(milliseconds: 180);
  static const Duration mediumDuration = Duration(milliseconds: 280);
  static const Duration longDuration = Duration(milliseconds: 420);
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: neutral0,
      secondary: secondaryColor,
      onSecondary: neutral0,
      tertiary: tertiaryColor,
      onTertiary: neutral0,
      error: errorColor,
      onError: neutral0,
      background: neutral10,
      onBackground: neutral90,
      surface: neutral0,
      onSurface: neutral90,
      surfaceTint: primaryColor,
    );

    final baseTextTheme = GoogleFonts.manropeTextTheme().apply(
      displayColor: neutral90,
      bodyColor: neutral80,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: neutral90,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: neutral80,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: neutral80,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.55,
        color: neutral80,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.6,
        color: neutral60,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.5,
        letterSpacing: 0.2,
        color: neutral60,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: neutral90,
      ),
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: neutral10,
      canvasColor: neutral0,
      dividerColor: neutral20,
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: neutral0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
        margin: const EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingS),
        surfaceTintColor: neutral0,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: neutral90,
        surfaceTintColor: Colors.transparent,
        titleSpacing: spacingL,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
        toolbarHeight: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral0,
        hintStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: neutral20, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: neutral20, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: errorColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: errorColor, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: neutral0,
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: neutral0,
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: neutral20, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: spacingS),
          shape: RoundedRectangleBorder(borderRadius: bradiusXS),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: neutral0,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neutral20,
        selectedColor: primaryColor.withOpacity(.12),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 12, color: neutral80),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(fontSize: 12, color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: spacingXS),
        shape: RoundedRectangleBorder(borderRadius: bradiusS),
        side: const BorderSide(color: Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: bradiusM),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        iconColor: primaryColor,
        textColor: neutral80,
      ),
      cardColor: neutral0,
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
        backgroundColor: neutral0,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: neutral0,
        modalBackgroundColor: neutral0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral90,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: neutral0),
        elevation: 4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: bradiusS),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppPalette.light,
      ],
    );
  }

  static ThemeData get darkTheme {
    const background = Color(0xFF0F1110);
    const surface = Color(0xFF171B1A);
    const surfaceVariant = Color(0xFF1F2321);
    const outline = Color(0xFF2D322F);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColorLight,
      onPrimary: neutral0,
      secondary: secondaryColor,
      onSecondary: neutral0,
      tertiary: tertiaryColor,
      onTertiary: neutral0,
      error: errorColor,
      onError: neutral0,
      background: background,
      onBackground: neutral10,
      surface: surface,
      onSurface: neutral0,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: neutral60,
      outline: outline,
      shadow: Colors.black87,
      inverseSurface: neutral0,
      onInverseSurface: neutral90,
      inversePrimary: primaryColor,
    );

    final baseTextTheme =
        GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).apply(bodyColor: neutral0, displayColor: neutral0);
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
      displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.5),
      bodySmall: baseTextTheme.bodySmall?.copyWith(height: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: outline,
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: surfaceVariant,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
        margin: const EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingS),
        surfaceTintColor: surfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: neutral0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: spacingL,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
        toolbarHeight: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: textTheme.bodyMedium?.copyWith(color: neutral50),
        border: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: primaryColorLight, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: errorColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: bradiusM,
          borderSide: const BorderSide(color: errorColor, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColorLight,
          foregroundColor: neutral0,
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: neutral0,
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neutral0,
          side: BorderSide(color: outline, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: bradiusM),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColorLight,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: spacingS),
          shape: RoundedRectangleBorder(borderRadius: bradiusXS),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColorLight,
        foregroundColor: neutral0,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primaryColorLight.withOpacity(.24),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 12, color: neutral0),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(fontSize: 12, color: primaryColorLight),
        padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: spacingXS),
        shape: RoundedRectangleBorder(borderRadius: bradiusS),
        side: BorderSide(color: outline, width: 1),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: bradiusM),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        iconColor: neutral0,
        textColor: neutral0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: bradiusL),
        backgroundColor: surface,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: surface,
        modalBackgroundColor: surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: bradiusM),
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceVariant,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: neutral0),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppPalette.dark,
      ],
    );
  }
}

