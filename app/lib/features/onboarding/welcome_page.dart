import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';

/// S-01 Welcome and risk notice. Continue stays disabled until the box is
/// ticked; Continue stores `riskAcknowledgedAt` and opens S-02.
class WelcomePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _understood = false;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    final now = ref.read(clockProvider).now().toUtc();
    try {
      await ref
          .read(settingsRepoProvider)
          .update((s) => s.copyWith(riskAcknowledgedAt: now));
    } on Object {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.go(Routes.loginPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = StorizeColors.of(context).warning;
    final risks = [l10n.onbRisk1, l10n.onbRisk2, l10n.onbRisk3, l10n.onbRisk4];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(
                  StorizeSpacing.screenMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: StorizeSpacing.s24),
                    Row(
                      children: [
                        const StorizeMark(size: 56),
                        const SizedBox(width: StorizeSpacing.s12),
                        Text(
                          l10n.appTitle,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 36,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StorizeSpacing.s24),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.onbWelcomeHeadline,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 34,
                          height: 40 / 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s12),
                    Text(
                      l10n.onbWelcomeTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s24),
                    _Promise(
                      icon: Icons.download_rounded,
                      title: l10n.onbPromiseAutoTitle,
                      body: l10n.onbPromiseAutoBody,
                    ),
                    _Promise(
                      icon: Icons.person_search_rounded,
                      title: l10n.onbPromiseChooseTitle,
                      body: l10n.onbPromiseChooseBody,
                    ),
                    _Promise(
                      icon: Icons.lock_outline_rounded,
                      title: l10n.onbPromisePrivateTitle,
                      body: l10n.onbPromisePrivateBody,
                    ),
                    const SizedBox(height: StorizeSpacing.s8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: StorizeRadii.cardRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: StorizeSpacing.s16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: warning.color,
                                ),
                                const SizedBox(width: StorizeSpacing.s12),
                                Expanded(
                                  child: Text(
                                    l10n.onbRiskTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: StorizeSpacing.s8),
                            for (final r in risks)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  bottom: StorizeSpacing.s8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '•  ',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: scheme.onSurface),
                                    ),
                                    Expanded(
                                      child: _RiskText(
                                        r,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.onSurface),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: StorizeSpacing.s12),
                    CheckboxListTile(
                      key: const ValueKey('onb-risk-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _understood,
                      title: Text(
                        l10n.onbRiskCheckbox,
                        style: theme.textTheme.bodyLarge,
                      ),
                      onChanged: (v) =>
                          setState(() => _understood = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.screenMargin,
                0,
                StorizeSpacing.screenMargin,
                StorizeSpacing.s16,
              ),
              child: PrimaryButton(
                key: const ValueKey('onb-continue'),
                label: l10n.onbContinue,
                expand: true,
                loading: _saving,
                onPressed: _understood ? _continue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders text where `**phrase**` segments are bold.
class _RiskText extends StatelessWidget {
  const _RiskText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// One promise row: a brand icon, a title and a muted line.
class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: StorizeSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 22, color: scheme.primary)),
          const SizedBox(width: StorizeSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  body,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
