# Vehicle Driver Flutter API Probe

تطبيق Flutter لاختبار الوصول إلى API الخاص بـ Vehicle Driver من داخل جلسة WebView.

## الاستخدام

1. افتح التطبيق.
2. سجّل الدخول داخل بوابة Huawei الظاهرة أعلى الشاشة.
3. أدخل رقم الهاتف أو حساب السائق.
4. جرّب فحص الملف أو المهام الحالية أو السجل.

التطبيق لا يخزن كلمة المرور. الطلبات تُنفّذ من JavaScript داخل نفس جلسة WebView لاختبار تجاوز مشكلة CORS الموجودة في نسخة GitHub Pages.

## بناء Android

يوجد Workflow باسم **Build Android APK** في GitHub Actions. بعد نجاحه، نزّل ملف APK من قسم Artifacts في صفحة تشغيل الـWorkflow.
