import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/purchase_store.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../lessons/lessons.dart';

/// Satın alma hatasını dile göre metne çevirir.
String? purchaseErrorText(AppLocalizations t, PurchaseStore store) => switch (store.error) {
      null => null,
      PurchaseError.storeUnavailable => t.storeUnavailable,
      PurchaseError.storeUnavailableShort => t.storeUnavailableShort,
      PurchaseError.notStarted => t.purchaseNotStarted(store.errorDetail ?? ''),
      PurchaseError.failed => store.errorDetail ?? t.purchaseFailed,
    };

/// "Tüm Dersler" satın alma ekranı. Tek seferlik, aile için, reklamsız.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PurchaseStore.instance;
    final t = context.t;
    final lessons = buildLessons(t);
    final premium = lessons.skip(freeLessonCount).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t.allLessonsSection)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.hasFullAccess) return const _Owned();
          final error = purchaseErrorText(t, store);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    Image.asset('assets/branding/icon.png', width: 64, height: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.paywallHeroTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(t.paywallHeroSub,
                              style: const TextStyle(color: Color(0xFFBFD0EA), fontSize: 14, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(t.whatUnlocks, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < premium.length; i++) ...[
                      ListTile(
                        dense: true,
                        leading: Text(premium[i].emoji, style: const TextStyle(fontSize: 22)),
                        title: Text('${freeLessonCount + i + 1}. ${premium[i].title}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(premium[i].group.title(t)),
                      ),
                      if (i != premium.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Benefit(icon: Icons.family_restroom_rounded, text: t.benefitFamily),
              _Benefit(icon: Icons.block_rounded, text: t.benefitNoAds),
              _Benefit(icon: Icons.update_rounded, text: t.benefitUpdates),
              const SizedBox(height: 20),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(error, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              FilledButton(
                onPressed: store.busy ? null : store.buy,
                child: store.busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(t.unlockAllLessonsBtn(store.priceText)),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: store.busy ? null : store.restore, child: Text(t.restorePurchase)),
              if (kDebugMode) TextButton(onPressed: store.debugGrant, child: Text(t.devUnlock)),
              const SizedBox(height: 8),
              Text(t.storeNote, style: Theme.of(context).textTheme.bodyMedium),
            ],
          );
        },
      ),
    );
  }
}

class _Owned extends StatelessWidget {
  const _Owned();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 72, color: AppColors.success),
            const SizedBox(height: 12),
            Text(t.allLessonsOpen, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(t.ownedThanks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.backToLessons)),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }
}
