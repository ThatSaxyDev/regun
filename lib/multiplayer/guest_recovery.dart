/// Optional secure-store support for retaining a rejected guest credential.
/// Recovery is explicit; a network timeout must never replace an identity.
abstract interface class RejectedGuestArchive {
  Future<void> archiveRejectedGuest();
}
