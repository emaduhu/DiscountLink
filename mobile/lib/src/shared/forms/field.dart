part of '../../../main.dart';

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.maxLength,
    this.inputFormatters,
    this.suffixIcon,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    ),
  );
}
