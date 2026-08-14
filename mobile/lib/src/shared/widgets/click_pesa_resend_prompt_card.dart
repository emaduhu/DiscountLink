part of '../../../main.dart';

class ClickPesaResendPromptCard extends StatelessWidget {
  const ClickPesaResendPromptCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.onSend,
    required this.busy,
    this.errorText,
    this.onCancel,
    this.sendLabel,
    this.busyLabel,
    this.phoneFieldKey = const ValueKey('clickpesa-resend-phone'),
    this.sendButtonKey = const ValueKey('clickpesa-resend-confirm'),
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool busy;
  final String? errorText;
  final VoidCallback? onCancel;
  final String? sendLabel;
  final String? busyLabel;
  final Key phoneFieldKey;
  final Key sendButtonKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfffffbf8), Colors.white, Color(0xfffff2ea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryColor, kPrimaryColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_iphone_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kTextColor,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: phoneFieldKey,
            controller: controller,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!busy) onSend();
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: tx(
                'ClickPesa payment phone',
                'Simu ya malipo ya ClickPesa',
              ),
              hintText: '255700000001',
              prefixIcon: const Icon(Icons.payments_outlined),
              errorText: errorText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onCancel != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(tx('Cancel', 'Ghairi')),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: sendButtonKey,
                  onPressed: busy ? null : onSend,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_to_mobile_outlined),
                  label: Text(
                    busy
                        ? (busyLabel ??
                              tx('Sending request...', 'Inatuma ombi...'))
                        : (sendLabel ??
                              tx(
                                'Send ClickPesa prompt',
                                'Tuma ombi la ClickPesa',
                              )),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
