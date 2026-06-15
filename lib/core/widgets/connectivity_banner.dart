import 'package:flutter/material.dart';

/// Previously showed an inline connectivity banner. Kept as a pass-through
/// wrapper so callers do not need to change.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
