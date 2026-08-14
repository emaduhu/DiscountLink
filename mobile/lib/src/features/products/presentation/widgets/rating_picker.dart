part of '../../../../../main.dart';

class RatingPicker extends StatefulWidget {
  const RatingPicker({super.key, required this.onRate});
  final Future<void> Function(int rating) onRate;

  @override
  State<RatingPicker> createState() => _RatingPickerState();
}
