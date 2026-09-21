import 'package:flutter/material.dart';
import 'core/firebase_config.dart';
import 'core/theme.dart';
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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 280,
                      child: ItdBrand(section: 'IBIT Rooms', logoHeight: 60),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'IBIT Rooms',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.hasError) ...[
                      const Text(
                        'We couldn’t start IBIT Rooms.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        EmulatorConfig.hybrid
                            ? 'Start the local booking server on your computer with scripts/start-hybrid-functions.ps1, then tap Try again.'
                            : 'The app connection needs to be configured. Follow the setup instructions included with this build.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => setState(
                          () => _initialization = EmulatorConfig.initialize(),
                        ),
                        child: const Text('Try again'),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
