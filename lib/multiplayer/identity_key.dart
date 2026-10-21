/// SDK 1.3.0's raw BSATN Identity bytes are reversed relative to canonical
/// server/official-client string identities. Keep typed Identity/auth untouched;
/// normalize only canonical string foreign keys when joining presentation rows.
String identityKeyFromCanonical(String canonical) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(canonical)) {
    throw const FormatException('Invalid canonical identity key');
  }
  return RegExp(r'..')
      .allMatches(canonical.toLowerCase())
      .map((m) => m.group(0)!)
      .toList()
      .reversed
      .join();
}
