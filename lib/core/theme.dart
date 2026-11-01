import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFFFF8000);
  static const brandLight = Color(0xFFFFB74D);
  static const primary = Color(0xFFFF8000);
  static const primaryDark = Color(0xFFCC6600);
  static const primarySoft = Color(0xFFFFF3E8);
  static const danger = Color(0xFFCD201F);
  static const success = Color(0xFF5EBA00);
  static const warning = Color(0xFFF1C40F);
  static const text = Color(0xFF212529);
  static const textSecondary = Color(0xFF666666);
  static const muted = Color(0xFF8F959E);
  static const border = Color(0xFFE5E9F0);
  static const borderStrong = Color(0xFFD9DEE7);
  static const sidebar = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFFFFFF);
  static const hover = Color(0xFFF8F8F9);
  static const hoverPressed = Color(0xFFF1F2F3);
  static const selected = Color(0xFFFFF4EA);
  static const tableHeader = Color(0xFFFAFAFA);
  static const folder = Color(0xFFFFB42D);
}

abstract final class AppMotion {
  static const hover = Duration(milliseconds: 160);
  static const press = Duration(milliseconds: 90);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.brand,
    onSecondary: Colors.white,
    error: AppColors.danger,
    surface: AppColors.canvas,
    onSurface: AppColors.text,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    surfaceContainerHighest: AppColors.hover,
    surfaceContainerLow: AppColors.tableHeader,
  );

  const textTheme = TextTheme(
    headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.3),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
    bodyLarge: TextStyle(fontSize: 14, color: AppColors.text, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.text, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, color: AppColors.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamilyFallback: const ['PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'Segoe UI'],
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    textTheme: textTheme,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    splashFactory: InkRipple.splashFactory,
    hoverColor: AppColors.hover,
    focusColor: AppColors.primary.withValues(alpha: 0.08),
    highlightColor: AppColors.primary.withValues(alpha: 0.06),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
      contentTextStyle: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      floatingLabelStyle: const TextStyle(fontSize: 12, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.primary, width: 1)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.danger, width: 1)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.borderStrong,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: 0.18);
          if (states.contains(WidgetState.hovered)) return Colors.white.withValues(alpha: 0.10);
          return null;
        }),
        animationDuration: AppMotion.hover,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.10);
          if (states.contains(WidgetState.hovered)) return AppColors.hover;
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return const BorderSide(color: AppColors.primary);
          return const BorderSide(color: AppColors.borderStrong);
        }),
        animationDuration: AppMotion.hover,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.08);
          if (states.contains(WidgetState.hovered)) return AppColors.hover;
          return null;
        }),
        animationDuration: AppMotion.hover,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        highlightColor: AppColors.hover,
        minimumSize: const Size(32, 32),
        iconSize: 19,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppColors.primary.withValues(alpha: 0.10);
          if (states.contains(WidgetState.hovered)) return AppColors.hover;
          return null;
        }),
        animationDuration: AppMotion.hover,
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)))),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppColors.borderStrong, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.white;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: const TextStyle(fontSize: 13, color: AppColors.text),
      menuPadding: const EdgeInsets.symmetric(vertical: 5),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: const Color(0xE62F3439),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF33383D),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 8,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0xFFEDF0F4),
      circularTrackColor: Color(0xFFEDF0F4),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(7),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
          return AppColors.muted.withValues(alpha: 0.75);
        }
        return AppColors.muted.withValues(alpha: 0.4);
      }),
      crossAxisMargin: 2,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0x55467FCF),
      selectionHandleColor: AppColors.primary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 19),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.text,
      dense: true,
      horizontalTitleGap: 8,
      minLeadingWidth: 20,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return const Color(0xFFE5E7EB);
      }),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    menuBarTheme: const MenuBarThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        elevation: const WidgetStatePropertyAll(10),
      ),
    ),
  );
}
