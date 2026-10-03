/// What a visitor types in when generating a token.
class VisitorInput {
  VisitorInput({required this.name, required this.mobile, this.priority = false});

  final String name;
  final String mobile;
  final bool priority;
}
