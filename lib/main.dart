import 'package:flutter/material.dart';
import 'core/firebase_config.dart';
import 'core/theme.dart';
import 'widgets/common.dart';
import 'widgets/itd_brand.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<void> _initialization = EmulatorConfig.initialize();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const IbitApp();
      }
      return MaterialApp(
        title: 'IBIT Rooms',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Builder(
                    builder: (context) {
                      final text = Theme.of(context).textTheme;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ItdLogo(height: 44),
                          const SizedBox(height: AppSpace.xl),
                          Text('IBIT Rooms', style: text.headlineSmall),
                          const SizedBox(height: AppSpace.lg + 4),
                          if (snapshot.hasError) ...[
                            Notice(
                              EmulatorConfig.hybrid
                                  ? 'We couldn’t start IBIT Rooms. Start the local booking server on your computer with scripts/start-hybrid-functions.ps1, then tap Try again.'
                                  : 'We couldn’t start IBIT Rooms. The app connection needs to be configured. Follow the setup instructions included with this build.',
                              isError: true,
                            ),
                            const SizedBox(height: AppSpace.lg + 4),
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _initialization =
                                    EmulatorConfig.initialize(),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ] else
                            const CircularProgressIndicator(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
