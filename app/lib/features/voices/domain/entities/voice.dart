/// A single reference voice usable for cloning.
///
/// [builtIn] voices ship with the app (Reginald Ashworth and Deja Thoris) and
/// cannot be deleted; user voices are imported `.wav` files copied into app
/// storage.
class Voice {
  const Voice({
    required this.id,
    required this.name,
    required this.wavPath,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String wavPath;
  final bool builtIn;

  @override
  bool operator ==(Object other) =>
      other is Voice &&
      other.id == id &&
      other.name == name &&
      other.wavPath == wavPath &&
      other.builtIn == builtIn;

  @override
  int get hashCode => Object.hash(id, name, wavPath, builtIn);
}
