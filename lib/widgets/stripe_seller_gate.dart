import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../services/payment_service.dart';
import '../theme/app_colors.dart';

/// Banner + blocco soft: i venditori senza Stripe non possono pubblicare.
class StripeSellerGateBanner extends StatefulWidget {
  const StripeSellerGateBanner({super.key});

  @override
  State<StripeSellerGateBanner> createState() => _StripeSellerGateBannerState();
}

class _StripeSellerGateBannerState extends State<StripeSellerGateBanner> {
  final _payments = PaymentService();
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final url = await _payments.startConnectOnboarding();
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire Stripe')),
        );
      }
      final status = await _payments.fetchConnectStatus();
      if (!mounted) return;
      final profile = AppScope.of(context).profile;
      if (profile != null) {
        AppScope.of(context).setProfile(
          profile.copyWithStripe(
            stripeAccountId: status.stripeAccountId ?? profile.stripeAccountId,
            stripeChargesEnabled: status.chargesEnabled,
            stripeDetailsSubmitted: status.detailsSubmitted,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    if (profile == null || !profile.needsStripeOnboarding) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.danger.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.account_balance_outlined, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Come venditore devi collegare Stripe Connect prima di pubblicare annunci.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Collega', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog obbligatorio al login se il venditore non ha Stripe.
Future<void> showStripeRequiredDialogIfNeeded(BuildContext context) async {
  final profile = AppScope.of(context).profile;
  if (profile == null || !profile.needsStripeOnboarding) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _StripeRequiredDialog(parentContext: context);
    },
  );
}

class _StripeRequiredDialog extends StatefulWidget {
  final BuildContext parentContext;

  const _StripeRequiredDialog({required this.parentContext});

  @override
  State<_StripeRequiredDialog> createState() => _StripeRequiredDialogState();
}

class _StripeRequiredDialogState extends State<_StripeRequiredDialog> {
  final _payments = PaymentService();
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final url = await _payments.startConnectOnboarding();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      final status = await _payments.fetchConnectStatus();
      final profile = AppScope.of(widget.parentContext).profile;
      if (profile != null) {
        AppScope.of(widget.parentContext).setProfile(
          profile.copyWithStripe(
            stripeAccountId: status.stripeAccountId ?? profile.stripeAccountId,
            stripeChargesEnabled: status.chargesEnabled,
            stripeDetailsSubmitted: status.detailsSubmitted,
          ),
        );
      }
      if (status.ready && mounted) {
        Navigator.of(context).pop();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa l\'onboarding Stripe nel browser, poi torna in app e aggiorna da Profilo.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Stripe obbligatorio',
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      ),
      content: Text(
        'I venditori devono collegare un account Stripe Connect per poter pubblicare annunci e ricevere pagamenti.',
        style: TextStyle(color: AppColors.textGrey, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Più tardi'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Collega Stripe'),
        ),
      ],
    );
  }
}
