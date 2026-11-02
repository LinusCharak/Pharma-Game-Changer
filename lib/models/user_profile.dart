/// The authenticated DSA's identity + reporting chain, mapped directly
/// from the existing Supabase `login` table (via the check_login RPC --
/// never queried directly). Field names here are camelCase; the mapping
/// from the table's snake_case columns happens once, in fromMap().
class UserProfile {
  final String username;
  final String fullName;
  final String designation;
  final String? hq;
  final String? email;
  final String? zone;

  final String? asmName;
  final String? asmHq;
  final String? asmEmail;

  final String? rsmName;
  final String? rsmHq;
  final String? rsmEmail;

  final String? ztmName;
  final String? ztmEmail;

  final String? ntmName;
  final String? ntmEmail;

  final bool isActive;

  UserProfile({
    required this.username,
    required this.fullName,
    required this.designation,
    this.hq,
    this.email,
    this.zone,
    this.asmName,
    this.asmHq,
    this.asmEmail,
    this.rsmName,
    this.rsmHq,
    this.rsmEmail,
    this.ztmName,
    this.ztmEmail,
    this.ntmName,
    this.ntmEmail,
    required this.isActive,
  });

  /// Maps one row returned by the `check_login` RPC. That RPC never
  /// returns the `password` column, so there is nothing password-shaped
  /// to accidentally carry into this model.
  ///
  /// This same map shape is also used for local JSON caching (see
  /// toMap()), so this factory doubles as the deserializer for the
  /// offline-session cache -- one mapping, two sources.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      username: map['username'] as String,
      fullName: map['dsa_name'] as String,
      designation: map['designation'] as String,
      hq: map['dsa_hq'] as String?,
      email: map['dsa_email'] as String?,
      zone: map['zone'] as String?,
      asmName: map['asm_name'] as String?,
      asmHq: map['asm_hq'] as String?,
      asmEmail: map['asm_email'] as String?,
      rsmName: map['rsm_name'] as String?,
      rsmHq: map['rsm_hq'] as String?,
      rsmEmail: map['rsm_email'] as String?,
      ztmName: map['ztm_name'] as String?,
      ztmEmail: map['ztm_email'] as String?,
      ntmName: map['ntm_name'] as String?,
      ntmEmail: map['ntm_email'] as String?,
      isActive: map['is_active'] as bool? ?? false,
    );
  }

  /// Inverse of fromMap() -- same keys, so the local JSON cache round-trips
  /// through the exact same shape the RPC returns. Deliberately contains
  /// no password field; there is nothing password-shaped to serialize.
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'dsa_name': fullName,
      'designation': designation,
      'dsa_hq': hq,
      'dsa_email': email,
      'zone': zone,
      'asm_name': asmName,
      'asm_hq': asmHq,
      'asm_email': asmEmail,
      'rsm_name': rsmName,
      'rsm_hq': rsmHq,
      'rsm_email': rsmEmail,
      'ztm_name': ztmName,
      'ztm_email': ztmEmail,
      'ntm_name': ntmName,
      'ntm_email': ntmEmail,
      'is_active': isActive,
    };
  }
}
