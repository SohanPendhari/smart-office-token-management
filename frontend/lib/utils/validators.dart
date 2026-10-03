class Validators {
  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? name(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Name is too short';
    if (s.length > 100) return 'Name is too long';
    return null;
  }

  /// 7-15 digits, optional leading +, spaces/dashes allowed (the backend cleans them).
  static String? mobile(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(s)) return 'Enter a valid mobile number (7-15 digits)';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? v) => (v == null || v.isEmpty) ? 'Password is required' : null;
}
