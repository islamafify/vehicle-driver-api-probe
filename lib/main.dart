import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const VehicleDriverApp());

class VehicleDriverApp extends StatelessWidget {
  const VehicleDriverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Vehicle Driver API Probe',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff07885d)),
      useMaterial3: true,
    ),
    home: const ProbePage(),
  );
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  static const loginUrl = 'https://w3m.huawei.com/m/servlet/index?locale=en_US';
  static const proxyBase = 'https://w3m.huawei.com/mcloud/umag/ProxyForText/';
  late final WebViewController webView;
  final account = TextEditingController(text: '294990');
  Timer? timeoutTimer;
  bool ready = false;
  bool busy = false;
  String status = 'سجّل الدخول داخل بوابة Huawei أعلاه أولًا.';
  String result = 'لم يتم إرسال أي طلب بعد.';

  @override
  void initState() {
    super.initState();
    webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('ProbeChannel',
        onMessageReceived: (message) => _handleProbeMessage(message.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => ready = false),
        onPageFinished: (_) => setState(() => ready = true),
        onWebResourceError: (e) =>
          setState(() => status = 'خطأ في البوابة: ' + e.description),
      ))
      ..loadRequest(Uri.parse(loginUrl));
  }

  @override
  void dispose() {
    timeoutTimer?.cancel();
    account.dispose();
    super.dispose();
  }

  String pathFor(String action) {
    if (action == 'profile') return 'getDriverInfo';
    if (action == 'tasks') return 'getCurrentTaskList';
    return 'getDriverHistory';
  }

  Map<String, dynamic> bodyFor(String action) => {
    'account': account.text.trim(),
    'driverCode': account.text.trim(),
    'pageNo': 1,
    'pageSize': 20,
    'lang': 'en_US',
    'action': action,
  };

  Future<void> _runProbe(String action) async {
    if (!ready || busy) return;
    if (account.text.trim().isEmpty) {
      setState(() {
        status = 'أدخل رقم الهاتف أو حساب السائق أولًا.';
        result = '{}';
      });
      return;
    }
    setState(() {
      busy = true;
      status = 'جارٍ إرسال الطلب...';
      result = 'في انتظار رد الخادم...';
    });
    timeoutTimer?.cancel();

    final url = jsonEncode(proxyBase + pathFor(action));
    final body = jsonEncode(jsonEncode(bodyFor(action)));
    final script = '''
(() => {
  fetch($url, {
    method: 'POST',
    credentials: 'include',
    headers: {'Content-Type': 'application/json'},
    body: $body
  }).then(async (response) => {
    ProbeChannel.postMessage(JSON.stringify({
      ok: true,
      status: response.status,
      body: await response.text()
    }));
  }).catch((error) => {
    ProbeChannel.postMessage(JSON.stringify({
      ok: false,
      error: String(error),
      stack: error && error.stack ? error.stack : ''
    }));
  });
})()
''';

    try {
      await webView.runJavaScript(script);
      timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted || !busy) return;
        setState(() {
          busy = false;
          status = 'انتهت مهلة انتظار رد الخادم.';
          result = '{}';
        });
      });
    } catch (error) {
      _handleProbeMessage(jsonEncode({
        'ok': false,
        'error': 'تعذر تشغيل JavaScript: ' + error.toString(),
      }));
    }
  }

  void _handleProbeMessage(String message) {
    timeoutTimer?.cancel();
    if (!mounted) return;
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      if (payload['ok'] != true) {
        setState(() {
          busy = false;
          status = 'خطأ في الطلب: ' + (payload['error'] ?? 'غير معروف').toString();
          result = jsonEncode(payload);
        });
        return;
      }
      dynamic parsed = payload['body'];
      if (parsed is String && parsed.trim().isNotEmpty) {
        try { parsed = jsonDecode(parsed); } catch (_) {}
      }
      setState(() {
        busy = false;
        status = 'تم استلام رد HTTP ' + (payload['status'] ?? '').toString() + '.';
        result = const JsonEncoder.withIndent('  ').convert(parsed);
      });
    } catch (error) {
      setState(() {
        busy = false;
        status = 'رد غير مفهوم من WebView: ' + error.toString();
        result = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vehicle Driver API Probe'),
      actions: [
        IconButton(
          tooltip: 'إعادة تحميل البوابة',
          onPressed: () => webView.reload(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(flex: 6, child: WebViewWidget(controller: webView)),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'سجّل الدخول داخل البوابة، ثم أدخل رقم الحساب واضغط اختبار.',
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: account,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف / حساب السائق',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _actionButton('فحص الملف', 'profile'),
                    _actionButton('المهام الحالية', 'tasks'),
                    _actionButton('السجل', 'history'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(status, textAlign: TextAlign.right),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.all(10),
                  color: Colors.black87,
                  child: SelectableText(
                    result,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionButton(String label, String action) => ElevatedButton(
    onPressed: ready && !busy ? () => _runProbe(action) : null,
    child: Text(label),
  );
}
