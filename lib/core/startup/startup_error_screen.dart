import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// الشاشة التي تحلّ محلّ الصفحة البيضاء حين تفشل تهيئة الخدمات الخارجية.
///
/// **لماذا شاشة كاملة لا `try/catch` وحده؟**
/// تجاهل الفشل والمضيّ إلى `runApp` يبدو أبسط، لكنه ينقل العطل ولا يعالجه:
/// شاشة البداية تستدعي `FirebaseAuth.instance` بعد ثلاث ثوانٍ ونصف، فيتحول
/// «بياض فوري» إلى «انهيار متأخر» — وهو أسوأ، لأن المستخدم انتظر ثم فوجئ
/// بخطأ تقني لا يفهمه ولا يعرف ما يفعل بعده.
///
/// هذه الشاشة تقول ثلاثة أشياء بالترتيب: **ماذا حدث** بلغة المستخدم،
/// و**ما يستطيع فعله** (زر إعادة محاولة حقيقي)، و**التفصيل التقني** مطوياً
/// لمن يريده. وهي لا تعرف شيئاً عن بقية التطبيق: تستقبل دالة إعادة
/// المحاولة والشاشة التالية كمعاملين، فلا تعتمد طبقة `core` على `features`.
class StartupErrorScreen extends StatefulWidget {
  /// نصّ الخطأ التقني كما جاء من الخدمة.
  final String details;

  /// إعادة المحاولة — تُعيد `null` عند النجاح ونصّ الخطأ عند الفشل.
  final Future<String?> Function() onRetry;

  /// الشاشة التي يُنتقل إليها بعد نجاح إعادة المحاولة.
  final WidgetBuilder onReady;

  const StartupErrorScreen({
    super.key,
    required this.details,
    required this.onRetry,
    required this.onReady,
  });

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  late String _details = widget.details;
  bool _isRetrying = false;
  bool _showDetails = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);

    final error = await widget.onRetry();
    if (!mounted) return;

    if (error == null) {
      // النجاح ينقل المستخدم إلى المسار الطبيعي بلا أن يُعيد تشغيل التطبيق
      // يدوياً — وهو الفرق بين «رسالة خطأ» و«مخرج من الخطأ».
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: widget.onReady));
      return;
    }

    setState(() {
      _isRetrying = false;
      _details = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 72,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'startup.error_title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'startup.error_body'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _buildRetryButton(),
                const SizedBox(height: 14),
                _buildDetailsSection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return FilledButton.icon(
      onPressed: _isRetrying ? null : _retry,
      icon: _isRetrying
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
      label: Text(
        _isRetrying ? 'startup.retrying'.tr() : 'startup.retry'.tr(),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(220, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// التفصيل التقني مطويّ افتراضياً.
  ///
  /// إظهاره دائماً يُرعب المستخدم العادي بنصّ لا يعنيه، وإخفاؤه نهائياً
  /// يحرم من يستطيع قراءته — والمطوّر أو الدكتور في المناقشة يحتاجه.
  Widget _buildDetailsSection(ThemeData theme) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          icon: Icon(
            _showDetails
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
          ),
          label: Text('startup.details'.tr()),
        ),
        if (_showDetails)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              _details,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
      ],
    );
  }
}
