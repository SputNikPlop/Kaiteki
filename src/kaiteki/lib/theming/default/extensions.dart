import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:kaiteki/preferences/app_preferences.dart" as preferences;
import "package:kaiteki/preferences/app_preferences.dart";
import "package:kaiteki/preferences/theme_preferences.dart" as preferences;
import "package:kaiteki/theming/default/text_themes.dart" as kaiteki;
import "package:kaiteki/theming/theme.dart";
import "package:kaiteki/ui/shared/emoji/emoji_theme.dart";
import "package:kaiteki/ui/shared/posts/avatar_widget.dart";

extension ThemeDataExtensions on ThemeData {
  ThemeData applyUserPreferences(WidgetRef ref) {
    ShapeBorder getAvatarShape(double cornerRadius) {
      return switch (cornerRadius) {
        <= 0 => const Border(),
        >= double.infinity => const CircleBorder(),
        _ => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
      };
    }

    final avatarCornerRadius = ref.watch(preferences.avatarCornerRadius).value;
    final useNaturalBadgeColors =
        ref.watch(preferences.useNaturalBadgeColors).value;
    final interfaceFont = ref.watch(preferences.interfaceFont).value;

    TextTheme? getTextTheme(TextTheme? original) {
      final textTheme = original ?? const TextTheme();
      return switch (interfaceFont) {
        InterfaceFont.system => null,
        InterfaceFont.roboto => textTheme.apply(fontFamily: "Roboto"),
        InterfaceFont.kaiteki => kaiteki.getTextTheme(textTheme),
        InterfaceFont.atkinsonHyperlegible =>
          GoogleFonts.atkinsonHyperlegibleTextTheme(original),
        InterfaceFont.openDyslexic =>
          textTheme.apply(fontFamily: "OpenDyslexic"),
      };
    }

    return copyWith(
      extensions: [
        ...extensions.values,
        EmojiTheme(square: ref.watch(preferences.squareEmojis).value),
        AvatarTheme(shape: getAvatarShape(avatarCornerRadius)),
      ],
      badgeTheme: useNaturalBadgeColors
          ? badgeTheme.copyWith(
              backgroundColor: colorScheme.inverseSurface,
              textColor: colorScheme.onInverseSurface,
            )
          : null,
      textTheme: getTextTheme(textTheme),
      visualDensity: ref.watch(preferences.visualDensity).value,
    );
  }

  ThemeData applyDefaultTweaks() {
    final navigationBarForegroundColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.onSurface
            : colorScheme.onPrimary;
    return copyWith(
      snackBarTheme: snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: floatingActionButtonTheme.copyWith(
        extendedTextStyle: textTheme.labelLarge ?? const TextStyle(),
      ),
      dividerTheme: dividerTheme.copyWith(space: 1, thickness: 1),
      bottomNavigationBarTheme: bottomNavigationBarTheme.copyWith(
        backgroundColor: colorScheme.brightness == Brightness.dark
            ? colorScheme.surface
            : colorScheme.primary,
        selectedItemColor: navigationBarForegroundColor,
        unselectedItemColor: navigationBarForegroundColor.withOpacity(0.76),
        showSelectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Adds Kaiteki-specific extensions to the theme.
  ThemeData addKaitekiTheme() {
    return copyWith(
      extensions: [
        ...extensions.values,
        KaitekiTheme.fromMaterialTheme(this),
      ],
    );
  }
}
