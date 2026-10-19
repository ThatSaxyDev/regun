import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:regun/utils/constants.dart';

/// Read installed bundle metadata, including --build-name/--build-number overrides.
class AppBuildLabel extends StatefulWidget {
  const AppBuildLabel({super.key});
  @override
  State<AppBuildLabel> createState() => _AppBuildLabelState();
}

class _AppBuildLabelState extends State<AppBuildLabel> {
  late final _info = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox(height: 14);
        return Text('v${info.version} (${info.buildNumber})',
            key: const ValueKey('app-build-label'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 10,
                height: 1.4,
                letterSpacing: 1,
                color: Color(0xffB8A78F)));
      });
}
