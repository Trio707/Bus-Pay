class AgentPasswordRule {
  static final pattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,}$',
  );

  static bool isValid(String value) => pattern.hasMatch(value);

  /// Weak, Medium, or Strong. The backend still decides acceptance.
  static String strength(String value) {
    final classes = [
      RegExp(r'[A-Z]').hasMatch(value),
      RegExp(r'[a-z]').hasMatch(value),
      RegExp(r'\d').hasMatch(value),
      RegExp(r'[^A-Za-z0-9]').hasMatch(value),
    ].where((match) => match).length;
    if (value.length >= 12 && classes == 4) return 'Strong';
    if (value.length >= 8 && classes >= 3) return 'Medium';
    return 'Weak';
  }
}
