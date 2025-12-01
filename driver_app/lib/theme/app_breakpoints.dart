import 'package:responsive_framework/responsive_framework.dart';

class AppBreakpoints {
  static const double compact = 0;
  static const double phone = 480;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;

  static const double maxContentWidth = 1080;

  static List<Breakpoint> responsiveBreakpoints = const [
    Breakpoint(start: compact, end: phone, name: MOBILE),
    Breakpoint(start: phone, end: tablet, name: TABLET),
    Breakpoint(start: tablet, end: desktop, name: DESKTOP),
    Breakpoint(start: desktop, end: largeDesktop, name: 'XL'),
    Breakpoint(start: largeDesktop, end: double.infinity, name: 'XXL'),
  ];
}

