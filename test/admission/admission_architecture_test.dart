@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// اختبارات **القواعد المعمارية** المكتوبة في `CLAUDE.md`.
///
/// كل قاعدة هنا كانت محروسة بانضباط بشري فقط: تُقرأ في الوثيقة، ويُنسى
/// تطبيقها بعد شهر أو يخالفها من لم يقرأها. تحويلها إلى اختبار يجعل كسرها
/// **يفشل فوراً** بدل أن يُكتشف في المناقشة أو بعد النشر.
///
/// هذا الملف يقرأ من القرص فيعمل على الـVM وحده — ولذلك `@TestOn('vm')`.
void main() {
  final moduleDirectories = [
    Directory('lib/features/admission'),
    Directory('lib/core/services'),
  ];

  /// ملفات الموديول وحدها — خدمات الزملاء في `core/services` مستثناة.
  final moduleServiceFiles = <String>{
    'admission_collections.dart',
    'admission_seed_service.dart',
    'admission_service.dart',
    'academic_guide_service.dart',
    'app_config_service.dart',
    'certificate_service.dart',
    'certificate_storage_service.dart',
    'eligibility_evaluator.dart',
    'exam_paper_service.dart',
    'external_launcher_service.dart',
    'housing_service.dart',
    'major_matcher_service.dart',
    'matcher_result_service.dart',
    'matcher_scoring.dart',
    'storage_service.dart',
  };

  List<File> admissionFiles() {
    final files = <File>[];
    for (final directory in moduleDirectories) {
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final isService = directory.path.endsWith('core/services');
        if (isService && !moduleServiceFiles.contains(_basename(entity.path))) {
          continue;
        }
        files.add(entity);
      }
    }
    return files;
  }

  test('ملفات الموديول موجودة فعلاً — حارس على الحارس نفسه', () {
    // بدون هذا الفحص قد تمرّ كل الاختبارات التالية على قائمة فارغة لو
    // تغيّر مسار المجلد، فتبدو خضراء وهي لا تفحص شيئاً.
    expect(admissionFiles().length, greaterThan(50));
  });

  // ===================== 1. صفر dart:io =====================

  test('لا ملف في الموديول يستورد dart:io', () {
    // القاعدة رقم 8 في CLAUDE.md. `dart:io` لا يعمل على الويب، والتطبيق
    // يُنشر عليه. كسر هذه القاعدة لا يُفشل التحليل ولا البناء — يظهر فقط
    // كعطل صامت للمستخدم النهائي، ولذلك يجب أن يُمسك هنا.
    final offenders = <String>[];

    for (final file in admissionFiles()) {
      final hasImport = file
          .readAsLinesSync()
          .any((line) => RegExp(r'''^\s*import\s+['"]dart:io['"]''').hasMatch(line));
      if (hasImport) offenders.add(file.path);
    }

    expect(offenders, isEmpty, reason: 'استيراد dart:io يكسر الويب: $offenders');
  });

  // ===================== 2. سقف الثلاثمئة سطر =====================

  test('لا ملف في الموديول يتجاوز 300 سطر', () {
    // قاعدة تُخرق مرة تُخرق دائماً، وهي السبب المباشر لوجود ملف بـ1,096
    // سطراً في المشروع القائم.
    final offenders = <String>[];

    for (final file in admissionFiles()) {
      final lines = file.readAsLinesSync().length;
      if (lines > 300) offenders.add('${file.path} ($lines)');
    }

    expect(offenders, isEmpty, reason: 'تجاوز سقف الثلاثمئة سطر: $offenders');
  });

  // ===================== 3. debugPrint لا print =====================

  test('لا استدعاء print في ملفات الموديول', () {
    // ستة مواضع في المشروع القائم تستخدم `print` في كود الإنتاج. الموديول
    // يستخدم `debugPrint` حصراً لأنها تُحذف في نسخة الإصدار.
    final offenders = <String>[];
    final printCall = RegExp(r'(?<![A-Za-z_.])print\s*\(');

    for (final file in admissionFiles()) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        if (printCall.hasMatch(line)) {
          offenders.add('${file.path}:${index + 1}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'استخدم debugPrint: $offenders');
  });

  // ===================== 4. عقد الترجمة =====================

  group('الترجمة — العقد بين الكود وملفَّي اللغة', () {
    Map<String, dynamic> flatten(Map<String, dynamic> source, [String prefix = '']) {
      final result = <String, dynamic>{};
      source.forEach((key, value) {
        final path = prefix.isEmpty ? key : '$prefix.$key';
        if (value is Map<String, dynamic>) {
          result.addAll(flatten(value, path));
        } else {
          result[path] = value;
        }
      });
      return result;
    }

    Map<String, dynamic> loadKeys(String language) {
      final raw = File('assets/translations/$language.json').readAsStringSync();
      return flatten(json.decode(raw) as Map<String, dynamic>);
    }

    test('ملفّا العربية والإنجليزية متطابقان مفتاحاً بمفتاح', () {
      final arabic = loadKeys('ar').keys.toSet();
      final english = loadKeys('en').keys.toSet();

      expect(
        arabic.difference(english),
        isEmpty,
        reason: 'مفاتيح موجودة في العربية وناقصة في الإنجليزية',
      );
      expect(
        english.difference(arabic),
        isEmpty,
        reason: 'مفاتيح موجودة في الإنجليزية وناقصة في العربية',
      );
    });

    test('كل مفتاح admission مستخدم في الكود موجود في اللغتين', () {
      // هذا ما يمنع ظهور `admission.housing.price` نصاً خاماً على شاشة
      // الطالب. اختبارات الودجت تمسك المفاتيح المعروضة فعلاً، وهذا يمسك
      // كل المفاتيح حتى ما لم يُعرض في اختبار.
      final arabic = loadKeys('ar').keys.toSet();
      final english = loadKeys('en').keys.toSet();
      final pattern = RegExp(r'''['"](admission\.[A-Za-z0-9_.]+)['"]''');
      final used = <String>{};

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final match in pattern.allMatches(entity.readAsStringSync())) {
          used.add(match.group(1)!);
        }
      }

      expect(used, isNotEmpty);
      expect(used.difference(arabic), isEmpty, reason: 'ناقص في ar.json');
      expect(used.difference(english), isEmpty, reason: 'ناقص في en.json');
    });
  });

  // ===================== 5. صفر Firestore داخل الشاشات =====================

  test('لا شاشة في الموديول تستورد cloud_firestore', () {
    // القاعدة الحاكمة: الشاشة ← الخدمة ← Firestore. النماذج مستثناة لأنها
    // تحتاج `DocumentSnapshot` و`GeoPoint` في التحويل من الوثيقة وإليها.
    final offenders = <String>[];
    final screens = Directory('lib/features/admission')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/models/'));

    for (final file in screens) {
      if (file.readAsStringSync().contains("package:cloud_firestore")) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'الشاشات لا تعرف Firestore — مرّر عبر خدمة: $offenders',
    );
  });
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
