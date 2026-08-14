part of '../../../../../main.dart';

class _RatingPickerState extends State<RatingPicker> {
  int selected = 0;
  bool saving = false;

  Future<void> rate(int value) async {
    setState(() {
      selected = value;
      saving = true;
    });
    try {
      await widget.onRate(value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rating saved.')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Rate: ', style: TextStyle(fontWeight: FontWeight.w700)),
        for (var value = 1; value <= 5; value++)
          IconButton(
            tooltip: '$value stars',
            onPressed: saving ? null : () => rate(value),
            icon: Icon(
              value <= selected
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: Colors.amber.shade700,
            ),
          ),
        if (saving)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
