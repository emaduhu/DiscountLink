part of '../../../../../main.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: ResponsiveCenter(
            maxWidth: kResponsiveFormMaxWidth,
            child: Column(
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/welcome_image.png',
                  height: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                Text(
                  kAppName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Discounted products, verified sellers, tracked delivery, and fast checkout in one shopping flow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextColor, height: 1.45),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onContinue,
                  child: Text(tx('Continue', 'Endelea')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
