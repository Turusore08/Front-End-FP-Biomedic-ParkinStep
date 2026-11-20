import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Custom multi-stroke clinical vector icons and bespoke S-03 line-art
/// illustrations matching Figma v2 Page 2 paths without boilerplate icon sets.
abstract final class ParkinIcons {
  static Widget login({Color color = const Color(0xFF0077B6), double size = 24}) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M10 17L15 12L10 7" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M15 12H3" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<path d="M15 3H19C20.1 3 21 3.9 21 5V19C21 20.1 20.1 21 19 21H15" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget offlineShield({
    Color color = const Color(0xFF006299),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 2.5L4 6V11.5C4 16.7 7.4 21.4 12 22.8C16.6 21.4 20 16.7 20 11.5V6L12 2.5Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M9.5 12.2L11.2 13.9L14.8 10.3" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget help({Color color = const Color(0xFF0077B6), double size = 24}) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="9.5" stroke="$hex" stroke-width="2"/>'
      '<path d="M9.4 9.2C9.7 7.9 10.8 7 12.1 7C13.7 7 14.8 8 14.8 9.4C14.8 10.6 13.9 11.2 12.8 11.8C12.2 12.1 12 12.6 12 13.4" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="12" cy="16.8" r="1.2" fill="$hex"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget check({Color color = const Color(0xFF0077B6), double size = 24}) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M5 12.5L9.5 17L19 7.5" stroke="$hex" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget alertTriangle({
    Color color = const Color(0xFFB45309),
    double size = 20,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M10.4 4.4C11.1 3.2 12.9 3.2 13.6 4.4L20.8 17C21.5 18.2 20.6 19.7 19.2 19.7H4.8C3.4 19.7 2.5 18.2 3.2 17L10.4 4.4Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M12 9V13" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<circle cx="12" cy="16.2" r="1.1" fill="$hex"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget strideShoe({
    Color color = const Color(0xFF0077B6),
    double size = 26,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 15.5V9.2C4 8.5 4.6 8 5.2 8.2L8.4 9.5C9.4 9.9 10.6 9.5 11.2 8.6L12 7.4L15 11.4C16.2 12 18.2 12.2 19.6 12.7C20.5 13 21 13.8 21 14.8V16.2C21 16.9 20.4 17.5 19.7 17.5H5.5C4.7 17.5 4 16.6 4 15.5Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M4.2 15H20.6" stroke="$hex" stroke-width="1.8" stroke-linecap="round"/>'
      '<path d="M12.5 10.5L14 9.2" stroke="$hex" stroke-width="1.8" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget chevronRight({
    Color color = const Color(0xFF0077B6),
    double size = 18,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M9 6L15 12L9 18" stroke="$hex" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget close({
    Color color = const Color(0xFF234085),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M6 6L18 18" stroke="$hex" stroke-width="2.3" stroke-linecap="round"/>'
      '<path d="M18 6L6 18" stroke="$hex" stroke-width="2.3" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget capsule({
    Color color = const Color(0xFF0077B6),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="7" y="3.2" width="9.8" height="17.6" rx="4.9" transform="rotate(42 12 12)" stroke="$hex" stroke-width="2"/>'
      '<path d="M8.6 8.6L15.4 15.4" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget clock({
    Color color = const Color(0xFF475569),
    double size = 20,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="9" stroke="$hex" stroke-width="2"/>'
      '<path d="M12 7.5V12.2L15.2 14" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget navHome({
    Color color = const Color(0xFF0077B6),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 10.5L12 4L20 10.5V19C20 19.8 19.3 20.5 18.5 20.5H5.5C4.7 20.5 4 19.8 4 19V10.5Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M9.5 20.5V14H14.5V20.5" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget navHistory({
    Color color = const Color(0xFF64748B),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4.5 19.5H19.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M6.5 15.2L10.5 11.2L13.8 13.8L18.5 8" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<circle cx="18.5" cy="8" r="1.6" fill="$hex"/>'
      '<circle cx="10.5" cy="11.2" r="1.4" fill="$hex"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget navHelp({
    Color color = const Color(0xFF64748B),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="4" y="4" width="16" height="16" rx="4" stroke="$hex" stroke-width="2"/>'
      '<path d="M9.6 9.5C9.9 8.3 10.9 7.6 12.1 7.6C13.5 7.6 14.5 8.5 14.5 9.7C14.5 10.7 13.7 11.2 12.7 11.8C12.2 12.1 12 12.5 12 13.2" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="12" cy="16.2" r="1.1" fill="$hex"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget navSettings({
    Color color = const Color(0xFF64748B),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4.5 7H19.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M4.5 12H19.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M4.5 17H19.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="9" cy="7" r="2.2" fill="#FFFFFF" stroke="$hex" stroke-width="2"/>'
      '<circle cx="15" cy="12" r="2.2" fill="#FFFFFF" stroke="$hex" stroke-width="2"/>'
      '<circle cx="10.5" cy="17" r="2.2" fill="#FFFFFF" stroke="$hex" stroke-width="2"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget soundWave({
    Color color = const Color(0xFF006299),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 9.8V14.2H7.8L12.5 18V6L7.8 9.8H4Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M16 9C17 10.6 17 13.4 16 15" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M18.8 6.8C20.5 9.8 20.5 14.2 18.8 17.2" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  /// Bespoke medical line-art illustration 1: clinical stride shoe + 360 turnaround orbit.
  static Widget tes360Illustration({double size = 50}) {
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M14 39C11 33 12.5 23 19.5 17.5C27 11.5 39.5 12 46.5 18.5C52 23.6 52.5 31.8 48.5 37.2" stroke="#00A9EC" stroke-width="2.6" stroke-linecap="round" stroke-dasharray="4 3"/>'
      '<path d="M45 33.5L48.5 38L53.2 35" stroke="#00A9EC" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M18 44.5V35.2C18 34.1 19 33.4 20 33.8L25 35.7C26.5 36.2 28.1 35.6 29 34.3L30.2 32.5L35 38.4C36.8 39.3 39.8 39.6 42.2 40.3C43.6 40.8 44.5 42 44.5 43.5V45.5C44.5 46.6 43.6 47.5 42.5 47.5H20.5C19.1 47.5 18 46.2 18 44.5Z" fill="#E8F7FC" stroke="#234085" stroke-width="2.6" stroke-linejoin="round"/>'
      '<path d="M18.5 43.5H44" stroke="#0077B6" stroke-width="2.2" stroke-linecap="round"/>'
      '<circle cx="31.5" cy="40.5" r="2" fill="#0077B6"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  /// Bespoke medical line-art illustration 2: acoustic metronome + rhythmic audio arcs.
  static Widget cueingRasIllustration({double size = 50}) {
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M23 50L28.5 17C29 14.4 31.1 12.5 33.6 12.5C36.1 12.5 38.2 14.4 38.7 17L44 50H23Z" fill="#E8F7FC" stroke="#234085" stroke-width="2.6" stroke-linejoin="round"/>'
      '<path d="M19.5 50H47.5" stroke="#234085" stroke-width="2.8" stroke-linecap="round"/>'
      '<path d="M33.6 44L41.8 22.5" stroke="#0077B6" stroke-width="2.6" stroke-linecap="round"/>'
      '<circle cx="40.2" cy="27" r="3" fill="#1AEAD8" stroke="#234085" stroke-width="2"/>'
      '<path d="M15.5 23C13 27.5 13 33.5 15.5 38" stroke="#00A9EC" stroke-width="2.4" stroke-linecap="round"/>'
      '<path d="M48.5 23C51 27.5 51 33.5 48.5 38" stroke="#00A9EC" stroke-width="2.4" stroke-linecap="round"/>'
      '<path d="M52.5 19.5C56 26.2 56 34.8 52.5 41.5" stroke="#0077B6" stroke-width="2.2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  /// Bespoke medical line-art illustration 3: Levodopa capsule + dose schedule dial.
  static Widget catatObatIllustration({double size = 50}) {
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<g transform="rotate(-38 26 28)">'
      '<rect x="17" y="12" width="17" height="32" rx="8.5" fill="#E8F7FC" stroke="#234085" stroke-width="2.6"/>'
      '<path d="M17.5 28H33.5" stroke="#234085" stroke-width="2.4"/>'
      '<path d="M25.5 12C30.2 12 34 15.8 34 20.5V28H17V20.5C17 15.8 20.8 12 25.5 12Z" fill="#0077B6"/>'
      '</g>'
      '<circle cx="43.5" cy="43.5" r="10.5" fill="#FFFFFF" stroke="#234085" stroke-width="2.5"/>'
      '<path d="M43.5 38.2V43.8L47.5 46" stroke="#00A9EC" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget arrowBack({
    Color color = const Color(0xFF234085),
    double size = 20,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M15 6L9 12L15 18" stroke="$hex" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget floorDry({
    Color color = const Color(0xFF0077B6),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M3.5 17.5H20.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<path d="M5.5 14L8.5 11H15.5L18.5 14" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M9 7.5L11.2 9.7L15.2 5.7" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget radiusSpace({
    Color color = const Color(0xFF0077B6),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="8.5" stroke="$hex" stroke-width="2" stroke-dasharray="3.5 2.5"/>'
      '<path d="M7.5 12H16.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M9.5 10L7 12L9.5 14" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M14.5 10L17 12L14.5 14" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget chairSupport({
    Color color = const Color(0xFF0077B6),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M7 5V13.5H16.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M7 13.5V19.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<path d="M16.5 13.5V19.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<path d="M7 9.5H13.5" stroke="$hex" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget cameraLegs({
    Color color = const Color(0xFF0077B6),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="3.5" y="6.5" width="13.5" height="11" rx="2.5" stroke="$hex" stroke-width="2"/>'
      '<path d="M17 10L20.5 8V16L17 14" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<circle cx="10.2" cy="12" r="2.2" stroke="$hex" stroke-width="1.8"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget chevronUp({
    Color color = const Color(0xFFFFFFFF),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M6.5 14.5L12 9L17.5 14.5" stroke="$hex" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget chevronDown({
    Color color = const Color(0xFFFFFFFF),
    double size = 24,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M6.5 9.5L12 15L17.5 9.5" stroke="$hex" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget playTriangle({
    Color color = const Color(0xFF0077B6),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M8 6.5L18 12L8 17.5V6.5Z" stroke="$hex" stroke-width="2.2" stroke-linejoin="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget stopSquare({
    Color color = const Color(0xFFDC2626),
    double size = 20,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="6.5" y="6.5" width="11" height="11" rx="2.5" stroke="$hex" stroke-width="2.2"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static Widget soundMuted({
    Color color = const Color(0xFF64748B),
    double size = 22,
  }) {
    final hex = _toHex(color);
    return SvgPicture.string(
      '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 9.8V14.2H7.8L12.5 18V6L7.8 9.8H4Z" stroke="$hex" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M16 9.5L20 14.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '<path d="M20 9.5L16 14.5" stroke="$hex" stroke-width="2.2" stroke-linecap="round"/>'
      '</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }

  static String _toHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}
