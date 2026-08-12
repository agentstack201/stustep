#!/bin/bash
# سكربت بناء Flutter Web لبيئة Vercel
# يُنزّل Flutter SDK ويبني التطبيق للنشر على الويب
set -euo pipefail

# النسخة مثبَّتة عمداً لا `stable` المتحرك: البناء الذي ينجح اليوم يجب أن
# ينجح يوم المناقشة. و Dart فيها 3.10.4 مطابق لقيد `pubspec.yaml` (^3.10.4).
FLUTTER_VERSION="3.38.5-stable"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}.tar.xz"

echo "==> تنزيل Flutter SDK ${FLUTTER_VERSION}..."
curl -fsSL -o flutter.tar.xz "$FLUTTER_URL"

echo "==> فك الضغط..."
tar xf flutter.tar.xz
rm flutter.tar.xz

export PATH="$PWD/flutter/bin:$PATH"

# مستودع Vercel المستنسخ ليس مملوكاً لمستخدم البناء، و Flutter يرفض العمل
# داخل مستودع Git لا يثق به فيفشل البناء برسالة غامضة عن "dubious ownership".
git config --global --add safe.directory '*' || true

echo "==> إعداد Flutter..."
flutter config --no-analytics
flutter --version

echo "==> تنزيل التبعيات..."
flutter pub get

# فحص سريع قبل البناء: خطأ تحليل واحد يعني نشر نسخة مكسورة على رابط عام.
# اكتشافه هنا في ثوانٍ أرخص من اكتشافه أمام الدكتور.
echo "==> التحقق من التحليل..."
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "==> بناء التطبيق للويب..."
# `--no-web-resources-cdn` يضع CanvasKit داخل المخرجات بدل جلبه وقت التشغيل
# من `gstatic.com`. السبب عملي لا تجميلي: بدونها لا يعمل التطبيق إطلاقاً على
# أي شبكة تحجب ذلك النطاق — وشبكات الجامعات تفعل ذلك كثيراً. النتيجة نسخة
# مكتفية بذاتها لا تعتمد على أي طرف ثالث لترسم أول إطار.
flutter build web --release --no-web-resources-cdn

echo "==> البناء اكتمل بنجاح ✅"
