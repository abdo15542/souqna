import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// بطاقة إحصاء صغيرة لعرض رقم دالٍّ (مخزون منخفض / ذمم / متأخرون ...).
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatChip({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: softShadow(),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
          ]),
        ],
      ),
    );
  }
}

/// زر إجراء كبير لشبكة الرئيسية — أيقونة ملوّنة + عنوان + وصف.
class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const ActionCard({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: softShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.button)),
                child: Icon(icon, color: color, size: 26),
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل بحث موحد مع أيقونة ومحو سريع.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  const SearchField({super.key, required this.controller, required this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(onPressed: () { controller.clear(); onChanged?.call(''); }, icon: const Icon(Icons.close_rounded)),
        ),
      ),
    );
  }
}

/// بطاقة قسم داخل الشاشات الداخلية (إعدادات/تفاصيل).
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;
  const SectionCard({super.key, required this.title, required this.children, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(children: [
              if (accent != null)
                Container(width: 4, height: 18, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
              if (accent != null) const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(children: children)),
        ],
      ),
    );
  }
}

/// صف اختيار فاتورة/عنصر بأسلوب قائمة حديثة.
class SelectableRow extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const SelectableRow({super.key, required this.selected, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? cs.primary : cs.outline, size: 22),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          ])),
        ]),
      ),
    );
  }
}
