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
  bool ready = false;
  bool busy = false;
  String status = 'سجّل الدخول داخل بوابة Huawei أعلاه أولًا.';
  String result = 'لم يتم إرسال أي طلب بعد.';

  @override
  void initState() {
    super.initState();
    webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
    account.dispose();
    super.dispose();
  }

  String pathFor(String action) => action == 'profile'
      ? 'vehicle_profile/driverLogin/driverLoginController/getDriverArchivesByTelephone'
      : 'vehicle_dispatch/dispatchOrderTask/services/order/useVehicle/queryOrderTaskList';

  Map<String, dynamic> bodyFor(String action) => action == 'profile'
      ? {'telephone': account.text.trim(), 'language': 'en'}
      : {
          'queryType': action == 'current' ? '1' : '2',
          'phoneNumber': account.text.trim(),
          'language': 'en',
          'pageVO': {'curPage': 1, 'pageSize': 20},
        };

  Future<void> probe(String action) async {
    if (account.text.trim().isEmpty) {
      setState(() => status = 'اكتب رقم الحساب أولًا.');
      return;
    }
    if (!ready) {
      setState(() => status = 'انتظر اكتمال بوابة Huawei.');
      return;
    }

    setState(() {
      busy = true;
      status = 'جارٍ إرسال الطلب من داخل جلسة WebView…';
      result = 'POST ' + proxyBase + pathFor(action);
    });

    final base = jsonEncode(proxyBase);
    final path = jsonEncode(pathFor(action));
    final body = jsonEncode(bodyFor(action));
    final script = '''
(async () => {
  try {
    const response = await fetch($base + $path, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'content-type': 'application/json;charset=UTF-8',
        'accept': 'application/json'
      },
      body: JSON.stringify($body)
    });
    return JSON.stringify({
      ok: true,
      status: response.status,
      body: await response.text()
    });
  } catch (error) {
    return JSON.stringify({ok: false, error: String(error)});
  }
})()
''';

    try {
      final raw = await webView.runJavaScriptReturningResult(script);
      dynamic data = raw is String ? jsonDecode(raw) : raw;
      if (data is String) data = jsonDecode(data);

      if (data is Map && data['ok'] == true) {
        dynamic payload = data['body'];
        if (payload is String) {
          try {
            payload = jsonDecode(payload);
          } catch (_) {}
        }
        setState(() {
          status = 'تم استلام رد HTTP ' + data['status'].toString();
          result = const JsonEncoder.withIndent('  ').convert(payload);
        });
      } else {
        setState(() {
          status = 'فشل الطلب داخل التطبيق.';
          result = const JsonEncoder.withIndent('  ').convert(data);
        });
      }
    } catch (e) {
      setState(() {
        status = 'تعذر تنفيذ الطلب داخل WebView.';
        result = e.toString();
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget action(String label, String name) => Expanded(
        child: FilledButton(
          onPressed: busy ? null : () => probe(name),
          child: Text(label, textAlign: TextAlign.center),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle Driver API Probe'),
          actions: [
            IconButton(
              onPressed: busy
                  ? null
                  : () => webView.loadRequest(Uri.parse(loginUrl)),
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
        body: Column(children: [
          Expanded(flex: 5, child: WebViewWidget(controller: webView)),
          Expanded(
            flex: 4,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'سجّل الدخول داخل البوابة، ثم أدخل رقم الحساب واضغط اختبار.',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: account,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف / حساب السائق',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      action('فحص الملف', 'profile'),
                      const SizedBox(width: 6),
                      action('المهام الحالية', 'current'),
                      const SizedBox(width: 6),
                      action('السجل', 'history'),
                    ]),
                    const SizedBox(height: 10),
                    Text(status),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xff10231c),
                      child: SelectableText(
                        result,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Color(0xffd4f9e9),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      );
}
