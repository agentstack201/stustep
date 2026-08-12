import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stustep/features/admission/models/admission_enums.dart';
import 'package:stustep/features/admission/models/admission_requirement_model.dart';
import 'package:stustep/features/admission/models/department_admission_override.dart';
import 'package:stustep/features/admission/models/entrance_exam_model.dart';
import 'package:stustep/features/admission/models/exam_paper_model.dart';
import 'package:stustep/features/admission/models/high_school_certificate.dart';
import 'package:stustep/features/admission/models/housing_model.dart';
import 'package:stustep/features/admission/models/subject_requirement.dart';
import 'package:stustep/features/admission/models/upload_file.dart';

/// اختبارات **العقود** التي تقوم عليها معمارية الموديول.
///
/// ما يميّز هذا الملف عن بقية الاختبارات: هو لا يفحص سلوكاً يراه المستخدم،
/// بل يفحص **القواعد المعمارية نفسها** — تلك التي إن انكسرت بصمت أتلفت
/// بيانات مخزَّنة أو غيّرت ترتيب أسبقية دون أن يفشل أي اختبار آخر.
void main() {
  // ===================== 1. التعدادات نصاً لا رقماً =====================

  group('التعدادات — العقد مع Firestore', () {
    // القاعدة: يُخزَّن `code` النصي لا `index` الرقمي. الفهرس الرقمي يتغيّر
    // عند إضافة قيمة في منتصف التعداد، فتتلف كل البيانات المخزَّنة مسبقاً.
    // هذا الاختبار يجعل كسر القاعدة يفشل فوراً بدل أن يُكتشف بعد النشر.

    test('كل رمز في كل تعداد يعود إلى قيمته نفسها', () {
      for (final value in CertificateType.values) {
        expect(CertificateType.fromCode(value.code), value);
      }
      for (final value in HighSchoolTrack.values) {
        expect(HighSchoolTrack.fromCode(value.code), value);
      }
      for (final value in GpaScale.values) {
        expect(GpaScale.fromCode(value.code), value);
      }
      for (final value in HousingStatus.values) {
        expect(HousingStatus.fromCode(value.code), value);
      }
      for (final value in HousingGender.values) {
        expect(HousingGender.fromCode(value.code), value);
      }
      for (final value in ExamPaperType.values) {
        expect(ExamPaperType.fromCode(value.code), value);
      }
      for (final value in ModerationStatus.values) {
        expect(ModerationStatus.fromCode(value.code), value);
      }
    });

    test('لا يوجد رمز مكرر داخل أي تعداد', () {
      void expectUniqueCodes(List<String> codes) {
        expect(codes.toSet().length, codes.length);
      }

      expectUniqueCodes(CertificateType.values.map((v) => v.code).toList());
      expectUniqueCodes(HighSchoolTrack.values.map((v) => v.code).toList());
      expectUniqueCodes(GpaScale.values.map((v) => v.code).toList());
      expectUniqueCodes(HousingStatus.values.map((v) => v.code).toList());
      expectUniqueCodes(HousingGender.values.map((v) => v.code).toList());
      expectUniqueCodes(ExamPaperType.values.map((v) => v.code).toList());
      expectUniqueCodes(ModerationStatus.values.map((v) => v.code).toList());
    });

    test('الرموز نصوص إنجليزية لا أرقام مُصاغة كنص', () {
      // لو كتب أحد `HousingStatus('0')` لمرّ كل ما سبق. هذا يمنعه.
      for (final code in [
        ...CertificateType.values.map((v) => v.code),
        ...HighSchoolTrack.values.map((v) => v.code),
        ...ExamPaperType.values.map((v) => v.code),
      ]) {
        expect(int.tryParse(code), isNull, reason: 'الرمز "$code" رقم');
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(code), isTrue);
      }
    });

    test('قيمة غير معروفة تعود إلى الافتراضي الآمن لا إلى انهيار', () {
      // البيانات القادمة من Firestore قد تحمل رمزاً كتبه أحد يدوياً بالخطأ.
      expect(CertificateType.fromCode('مجهول'), CertificateType.yemeniGeneral);
      expect(HighSchoolTrack.fromCode(null), HighSchoolTrack.scientific);
      expect(HousingStatus.fromCode(''), HousingStatus.available);
      expect(ExamPaperType.fromCode('???'), ExamPaperType.model);
      expect(ModerationStatus.fromCode(null), ModerationStatus.published);
    });

    test('كل مفتاح ترجمة مبني على الرمز نفسه تحت جذر admission', () {
      for (final value in CertificateType.values) {
        expect(value.labelKey, 'admission.certificate_type.${value.code}');
      }
      for (final value in HighSchoolTrack.values) {
        expect(value.labelKey, 'admission.track.${value.code}');
      }
    });
  });

  // ===================== 2. أسبقية الحد الأدنى للمعدل =====================

  group('effectiveMinGpa — ترتيب الأسبقية الأربعة', () {
    // الترتيب المعتمد:
    //   استثناء القسم ← حسب نوع الشهادة ← حسب المسار ← الحد العام
    // هذا الترتيب قرار إداري لا تفصيلة تقنية، وأي انقلاب فيه يغيّر مصير
    // طلاب حقيقيين بلا أن يفشل أي اختبار آخر في المشروع.

    const requirements = AdmissionRequirementModel(
      collegeId: 'col_medicine',
      minGpa: 70,
      minGpaByTrack: {'scientific': 80},
      minGpaByCertificate: {'yemeni_general': 85},
      departmentOverrides: [
        DepartmentAdmissionOverride(departmentId: 'dep_medicine', minGpa: 90),
        DepartmentAdmissionOverride(departmentId: 'dep_nursing', minGpa: 65),
      ],
    );

    test('استثناء القسم يتقدّم على كل ما عداه', () {
      expect(
        requirements.effectiveMinGpa(
          departmentId: 'dep_medicine',
          certificateCode: 'yemeni_general',
          trackCode: 'scientific',
        ),
        90,
      );
    });

    test('استثناء القسم يتقدّم حتى حين يكون **أقل** من الحد العام', () {
      // الاستثناء ليس «رفعاً للحد» بل «قيمة القسم». التمريض 65 والعام 70.
      expect(
        requirements.effectiveMinGpa(
          departmentId: 'dep_nursing',
          certificateCode: 'yemeni_general',
          trackCode: 'scientific',
        ),
        65,
      );
    });

    test('بلا استثناء قسم: نوع الشهادة يتقدّم على المسار', () {
      expect(
        requirements.effectiveMinGpa(
          certificateCode: 'yemeni_general',
          trackCode: 'scientific',
        ),
        85,
      );
    });

    test('بلا نوع مطابق: المسار يتقدّم على الحد العام', () {
      expect(
        requirements.effectiveMinGpa(
          certificateCode: 'azhari',
          trackCode: 'scientific',
        ),
        80,
      );
    });

    test('بلا أي مطابقة: الحد العام', () {
      expect(
        requirements.effectiveMinGpa(
          certificateCode: 'azhari',
          trackCode: 'literary',
        ),
        70,
      );
    });

    test('قسم غير موجود في الاستثناءات لا يُسقط الحساب', () {
      expect(
        requirements.effectiveMinGpa(
          departmentId: 'dep_unknown',
          certificateCode: 'azhari',
          trackCode: 'literary',
        ),
        70,
      );
    });
  });

  // ===================== 3. دمج شروط القسم مع الكلية =====================

  group('effectiveFor — دمج استثناء القسم مع شروط الكلية', () {
    const collegeSubject = SubjectRequirement(
      subjectCode: 'biology',
      subjectName: 'الأحياء',
      minGrade: 85,
    );
    const departmentSubject = SubjectRequirement(
      subjectCode: 'chemistry',
      subjectName: 'الكيمياء',
      minGrade: 80,
    );

    const requirements = AdmissionRequirementModel(
      collegeId: 'col_medicine',
      minGpa: 70,
      acceptedCertificates: ['yemeni_general', 'azhari'],
      allowedTracks: ['scientific'],
      maxCertificateAgeYears: 3,
      requiresEquivalency: true,
      subjectRequirements: [collegeSubject],
      entranceExams: [
        EntranceExamModel(code: 'general', name: 'اختبار عام'),
        EntranceExamModel(
          code: 'medical_aptitude',
          name: 'قدرات طبية',
          isRequired: false,
        ),
      ],
      departmentOverrides: [
        DepartmentAdmissionOverride(
          departmentId: 'dep_medicine',
          acceptedCertificates: ['yemeni_general'],
          subjectRequirements: [departmentSubject],
          extraExamCodes: ['medical_aptitude'],
        ),
      ],
    );

    test('شروط المواد تُجمَع ولا يستبدل القسمُ الكليةَ', () {
      // الخلط الشائع: اعتبار استثناء القسم بديلاً. الصواب أنه **إضافة**،
      // وإلا سقط شرط الأحياء الذي تفرضه الكلية على كل أقسامها.
      final effective = requirements.effectiveFor(departmentId: 'dep_medicine');

      expect(effective.subjectRequirements.length, 2);
      expect(
        effective.subjectRequirements.map((s) => s.subjectCode),
        containsAll(['biology', 'chemistry']),
      );
    });

    test('الشهادات المقبولة يستبدلها القسم بالكامل حين يحدّدها', () {
      // هنا العكس: القائمة قرار قاطع لا تراكمي. قسم يقبل نوعاً واحداً فقط
      // لا يصحّ أن يرث بقية أنواع الكلية.
      final effective = requirements.effectiveFor(departmentId: 'dep_medicine');

      expect(effective.acceptedCertificates, ['yemeni_general']);
      expect(effective.acceptsCertificate('azhari'), isFalse);
    });

    test('القسم بلا استثناء يرث قوائم الكلية كما هي', () {
      final effective = requirements.effectiveFor(departmentId: 'dep_nursing');

      expect(effective.acceptedCertificates, ['yemeni_general', 'azhari']);
      expect(effective.subjectRequirements.length, 1);
    });

    test('الاختبار الاختياري يُدرَج فقط لمن طلبه من الأقسام', () {
      final medicine = requirements.effectiveFor(departmentId: 'dep_medicine');
      final nursing = requirements.effectiveFor(departmentId: 'dep_nursing');

      expect(medicine.entranceExams.map((e) => e.code), [
        'general',
        'medical_aptitude',
      ]);
      expect(nursing.entranceExams.map((e) => e.code), ['general']);
    });

    test('الشروط غير القابلة للاستثناء تُنقَل كما هي', () {
      final effective = requirements.effectiveFor(departmentId: 'dep_medicine');

      expect(effective.maxCertificateAgeYears, 3);
      expect(effective.requiresEquivalency, isTrue);
      expect(effective.collegeId, 'col_medicine');
      expect(effective.departmentId, 'dep_medicine');
    });
  });

  // ===================== 4. رحلة الذهاب والعودة إلى Firestore =====================

  group('التسلسل — ما يُكتب هو ما يُقرأ', () {
    test('الشهادة تعود من خريطتها بلا فقد ولا تحوير', () {
      const original = HighSchoolCertificate(
        type: CertificateType.foreignEquivalent,
        track: HighSchoolTrack.literary,
        gpa: 3.6,
        gpaScale: GpaScale.gpa4,
        graduationYear: 2024,
        hasEquivalency: true,
        subjectGrades: {'math': 88, 'english': 92.5},
      );

      final restored = HighSchoolCertificate.fromMap(original.toMap());

      expect(restored.type, original.type);
      expect(restored.track, original.track);
      expect(restored.gpa, original.gpa);
      expect(restored.gpaScale, original.gpaScale);
      expect(restored.graduationYear, original.graduationYear);
      expect(restored.hasEquivalency, original.hasEquivalency);
      expect(restored.subjectGrades, original.subjectGrades);
    });

    test('الشهادة تُخزَّن بمعدلها الأصلي وسلّمه لا بالقيمة المطبَّعة', () {
      // تخزين القيمة المطبَّعة يفقد الأصل ويمنع تصحيح جدول التحويل لاحقاً.
      const certificate = HighSchoolCertificate(
        type: CertificateType.yemeniGeneral,
        track: HighSchoolTrack.scientific,
        gpa: 3.6,
        gpaScale: GpaScale.gpa4,
        graduationYear: 2025,
      );

      final map = certificate.toMap();
      expect(map['gpa'], 3.6);
      expect(map['gpaScale'], 'gpa4');
      expect(map['gpa'], isNot(90));
    });

    test('السكن يكتب التعدادات نصاً', () {
      const housing = HousingModel(
        id: 'h1',
        name: 'سكن النور',
        phone: '777123456',
        createdBy: 'uid1',
        status: HousingStatus.full,
        gender: HousingGender.female,
        moderationStatus: ModerationStatus.pending,
      );

      final map = housing.toFirestore();
      expect(map['status'], HousingStatus.full.code);
      expect(map['gender'], HousingGender.female.code);
      expect(map['moderationStatus'], ModerationStatus.pending.code);
      expect(map['status'], isA<String>());
    });

    test('السكن لا يكتب حقولاً اختيارية غائبة بقيمة null', () {
      // كتابة `null` صراحةً تُنشئ حقلاً فارغاً في الوثيقة يُربك أي قارئ
      // لاحق ويجعل التمييز بين «غير محدَّد» و«صفر» مستحيلاً.
      const housing = HousingModel(
        id: 'h2',
        name: 'سكن',
        phone: '777',
        createdBy: 'uid1',
      );

      final map = housing.toFirestore();
      expect(map.containsKey('priceMonthly'), isFalse);
      expect(map.containsKey('roomsAvailable'), isFalse);
      expect(map.containsKey('whatsapp'), isFalse);
    });

    test('نموذج الاختبار يكتب نوعه وحالة مراجعته نصاً', () {
      const paper = ExamPaperModel(
        id: 'p1',
        title: 'اختبار',
        fileUrl: 'https://example.com/a.pdf',
        collegeId: 'col_it',
        uploadedBy: 'uid1',
        type: ExamPaperType.quiz,
      );

      final map = paper.toFirestore();
      expect(map['type'], ExamPaperType.quiz.code);
      expect(map['moderationStatus'], ModerationStatus.published.code);
    });
  });

  // ===================== 5. مشتقّات النماذج =====================

  group('مشتقّات النماذج', () {
    test('اسم الملف المحلي من معرّف الوثيقة لا من العنوان', () {
      // تصحيح متعمَّد لخطأ نظام تنزيل الفيديو القائم: بناء الاسم من
      // `title.hashCode` يجعل الملف يتيماً عند أي تعديل على العنوان.
      const before = ExamPaperModel(
        id: 'paper_42',
        title: 'اختبار الرياضيات',
        fileUrl: 'u',
        collegeId: 'c',
        uploadedBy: 'u',
      );
      const after = ExamPaperModel(
        id: 'paper_42',
        title: 'اختبار الرياضيات — النسخة المصحَّحة',
        fileUrl: 'u',
        collegeId: 'c',
        uploadedBy: 'u',
      );

      expect(before.localFileName, after.localFileName);
      expect(before.localFileName, contains('paper_42'));
    });

    test('حجم الملف يُعرض بوحدة مقروءة، والغائب يُعرض شرطة', () {
      const withSize = ExamPaperModel(
        id: 'p',
        title: 't',
        fileUrl: 'u',
        collegeId: 'c',
        uploadedBy: 'u',
        fileSizeBytes: 2 * 1024 * 1024,
      );
      const withoutSize = ExamPaperModel(
        id: 'p',
        title: 't',
        fileUrl: 'u',
        collegeId: 'c',
        uploadedBy: 'u',
      );

      expect(withSize.formattedSize, contains('MB'));
      expect(withoutSize.formattedSize, '—');
    });

    test('الملكية تُقاس بالمعرّف، والزائر بلا معرّف ليس مالكاً', () {
      const housing = HousingModel(
        id: 'h',
        name: 'n',
        phone: 'p',
        createdBy: 'uid1',
      );

      expect(housing.isOwnedBy('uid1'), isTrue);
      expect(housing.isOwnedBy('uid2'), isFalse);
      expect(housing.isOwnedBy(null), isFalse);
    });

    test('رابط الخريطة يُبنى من الإحداثيات، وغيابها يعني لا رابط', () {
      const withoutLocation = HousingModel(
        id: 'h',
        name: 'n',
        phone: 'p',
        createdBy: 'uid1',
      );

      expect(withoutLocation.mapsUrl, isNull);
    });
  });

  // ===================== 6. عقد رفع الملفات =====================

  group('UploadFile — عقد رفع الملفات عبر المنصات', () {
    test('الحجم يُقرأ من البايتات لا من نظام الملفات', () {
      // هذا هو جوهر إصلاح توافق الويب: لا استعلام قرص ولا `await`، فلا
      // اختلاف بين أندرويد والويب في هذا المسار.
      final file = UploadFile(name: 'a.pdf', bytes: Uint8List(2048));

      expect(file.sizeBytes, 2048);
      expect(file.name, 'a.pdf');
    });

    test('الملف الفارغ حجمه صفر ولا يرمي', () {
      final file = UploadFile(name: 'empty.pdf', bytes: Uint8List(0));

      expect(file.sizeBytes, 0);
    });
  });
}
