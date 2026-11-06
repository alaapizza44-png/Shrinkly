import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n.dart';

/// In-app privacy policy (English / Arabic, follows the app language).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<List<String>> _en = <List<String>>[
    <String>['Overview', 'Shrinkly ("the app") reduces the size of videos that you choose from your phone. The app has no accounts or sign-up, and we do not run any server that receives your videos or personal data.'],
    <String>['Your videos', 'Videos are processed entirely on your device. They are never uploaded to us. The app copies a video you choose into its temporary cache while working and removes those copies when you clear the list or reopen the app. Compressed videos are saved in your device\'s Movies folder; your original videos are not changed or deleted.'],
    <String>['Advertising', 'The app shows ads through Google AdMob. AdMob may use your device\'s advertising ID and similar technologies to show and measure ads. Where required (for example in the EEA and the UK), the app asks for your consent first, and you can change your choice later from Settings → Ad privacy options. Learn more: https://policies.google.com/technologies/ads'],
    <String>['Permissions', 'Internet and network state: to load ads. Notifications: to show compression progress while the app is in the background. Files: you choose videos with the system file picker; the app does not scan your storage.'],
    <String>['Children', 'The app is not directed to children under 13 and we do not knowingly collect their data.'],
    <String>['Changes', 'We may update this policy; the date below will change when we do.'],
    <String>['Contact', 'Questions about this policy: '],
  ];

  static const List<List<String>> _ar = <List<String>>[
    <String>['نظرة عامة', 'يقلّل تطبيق Shrinkly («التطبيق») حجم الفيديوهات التي تختارها من هاتفك. لا يتطلب التطبيق حسابًا أو تسجيلًا، ولا نملك خادمًا يستقبل فيديوهاتك أو بياناتك الشخصية.'],
    <String>['فيديوهاتك', 'تتم معالجة الفيديوهات بالكامل على جهازك ولا تُرفع إلينا أبدًا. ينسخ التطبيق الفيديو الذي تختاره إلى ذاكرته المؤقتة أثناء العمل، ويحذف هذه النسخ عند مسح القائمة أو إعادة فتح التطبيق. تُحفظ الفيديوهات المضغوطة في مجلد الأفلام على جهازك، ولا تتغير فيديوهاتك الأصلية ولا تُحذف.'],
    <String>['الإعلانات', 'يعرض التطبيق إعلانات عبر Google AdMob. قد تستخدم AdMob معرّف الإعلانات في جهازك وتقنيات مشابهة لعرض الإعلانات وقياس أدائها. وحيث يلزم (مثل المنطقة الاقتصادية الأوروبية والمملكة المتحدة) يطلب التطبيق موافقتك أولًا، ويمكنك تغيير اختيارك لاحقًا من الإعدادات ← خيارات خصوصية الإعلانات. للمزيد: https://policies.google.com/technologies/ads'],
    <String>['الأذونات', 'الإنترنت وحالة الشبكة: لتحميل الإعلانات. الإشعارات: لعرض تقدم الضغط أثناء وجود التطبيق في الخلفية. الملفات: تختار الفيديوهات بنفسك عبر منتقي الملفات في النظام، ولا يفحص التطبيق ذاكرة جهازك.'],
    <String>['الأطفال', 'التطبيق غير موجّه للأطفال دون 13 عامًا، ولا نجمع بياناتهم عن علم.'],
    <String>['التغييرات', 'قد نحدّث هذه السياسة، وسيتغيّر التاريخ أدناه عند ذلك.'],
    <String>['التواصل', 'للاستفسار عن هذه السياسة: '],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final sections = ar ? _ar : _en;
    final last = sections.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('privacy_policy'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: <Widget>[
          for (var i = 0; i < sections.length; i++) ...<Widget>[
            Text(sections[i][0],
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary)),
            const SizedBox(height: 6),
            SelectableText(
              i == last ? '${sections[i][1]}${AppInfo.contactEmail}' : sections[i][1],
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
          ],
          Text('${ar ? 'آخر تحديث' : 'Last updated'}: ${AppInfo.policyDate}',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
