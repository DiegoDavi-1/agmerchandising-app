import 'package:flutter/material.dart';

/// Cores de superfície e texto que acompanham o modo claro/escuro.
extension UiPalette on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get uiSurface => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get uiSurfaceAlt =>
      isDarkMode ? const Color(0xFF273449) : const Color(0xFFF1F5F9);
  Color get uiBorder =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get uiTextStrong =>
      isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get uiTextBody =>
      isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  Color get uiTextMuted =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get uiTextFaint =>
      isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get uiAccent =>
      isDarkMode ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);
}
