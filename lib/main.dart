import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranOriginalApp());
}

class QuranOriginalApp extends StatelessWidget {
  const QuranOriginalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'القرآن الكريم',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF07131C),
        ),
        home: const OriginalInterface(),
      );
}

class OriginalInterface extends StatefulWidget {
  const OriginalInterface({super.key});

  @override
  State<OriginalInterface> createState() => _OriginalInterfaceState();
}

class _OriginalInterfaceState extends State<OriginalInterface> {
  late final WebViewController controller;
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF07131C))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              loading = true;
              loadError = null;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                loading = false;
                loadError = error.description;
              });
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/quran_alkareem_glass.html');
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: controller),
                if (loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF55E5ED),
                    ),
                  ),
                if (loadError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 42),
                          const SizedBox(height: 12),
                          const Text(
                            'تعذر فتح واجهة التطبيق',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => controller.reload(),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
