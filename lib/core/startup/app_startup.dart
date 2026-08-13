import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// تهيئة الخدمات الخارجية قبل إقلاع التطبيق.
///
/// **لماذا وُجد هذا الملف؟**
/// كان `main()` ينتظر `Firebase.initializeApp()` بلا حماية، ثم يستدعي
/// `runApp()`. وعلى الويب يُجلب Firebase JS SDK من `gstatic.com` **وقت
/// التشغيل**، فأي تعذّر في الوصول إليه (شبكة تحجب النطاق · انقطاع لحظي ·
/// حاجب إعلانات) كان يرمي استثناءً قبل `runApp` — فلا يُرسم شيء إطلاقاً.
///
/// النتيجة التي رآها المستخدم: **صفحة بيضاء صامتة**. لا شعار، ولا رسالة،
/// ولا زر. وهي أسوأ أنواع الأعطال لأنها لا تقول للمستخدم ماذا حدث ولا ما
/// يستطيع فعله، ولا تُفرّق عنده بين «التطبيق معطّل» و«الإنترنت عندي».
///
/// المبدأ المتّبع هنا هو نفسه الذي يحكم محرّك الأهلية في الموديول:
/// **لا فشل مبهم أبداً.** كل فشل يحمل سببه ومخرجاً منه.
class AppStartup {
  const AppStartup._();

  /// أقصى انتظار للتهيئة قبل اعتبارها فاشلة.
  ///
  /// **الرقم ليس تحوّطاً نظرياً.** تُحقِّق عملياً في متصفح على شبكة تحجب
  /// `gstatic.com`: التهيئة على الويب لا ترمي استثناءً، بل **تتعلّق إلى
  /// الأبد** لأن `firebase_core_web` ينتظر وحدة JavaScript تُجلب بـ
  /// `import()` ديناميكي لا يُحسَم أبداً. و`try/catch` لا يمسك تعليقاً —
  /// يمسك رمياً فقط. فبلا هذه المهلة يبقى المستخدم أمام صفحة بيضاء صامتة
  /// مهما بلغت جودة معالجة الأخطاء بعدها.
  ///
  /// خمس عشرة ثانية سخيّة عمداً على اتصال بطيء، وانتهاؤها خطأً ليس نهاية
  /// المطاف: شاشة الخطأ تحمل زر إعادة محاولة حقيقياً.
  static const Duration initializationTimeout = Duration(seconds: 15);

  /// تهيئة Firebase.
  ///
  /// تُعيد `null` عند النجاح، أو نصّ الخطأ التقني عند الفشل — ولا ترمي
  /// أبداً ولا تتعلّق أبداً. أيٌّ منهما يعني موت التطبيق قبل أن يرسم إطاراً
  /// واحداً، وهو بالضبط العطل الذي وُجدت هذه الدالة لمنعه.
  static Future<String?> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(initializationTimeout);
      return null;
    } catch (error) {
      // إعادة التهيئة بعد نجاح سابق ترمي `duplicate-app`، وهي ليست فشلاً:
      // التطبيق مهيّأ فعلاً. تمييزها يمنع إظهار شاشة خطأ كاذبة عند إعادة
      // المحاولة أو عند إعادة بناء الشجرة في وضع التطوير.
      if (error is FirebaseException && error.code == 'duplicate-app') {
        return null;
      }

      debugPrint('AppStartup: Firebase initialization failed: $error');
      return error.toString();
    }
  }
}
