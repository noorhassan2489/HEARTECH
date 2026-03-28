/// App-wide constants for HearTech.
class AppConstants {
  AppConstants._();

  // ─── Risk Score Thresholds ──────────────────────────────────────
  static const int lowRiskMax = 33;
  static const int mediumRiskMax = 66;
  // 67-100 = High

  // ─── Age Brackets ──────────────────────────────────────────────
  static const Map<int, AgeBracket> ageBrackets = {
    1: AgeBracket(
      id: 1,
      label: 'Infants (0–6 Months)',
      minMonths: 0,
      maxMonths: 6,
    ),
    2: AgeBracket(
      id: 2,
      label: 'Older Infants (7–12 Months)',
      minMonths: 7,
      maxMonths: 12,
    ),
    3: AgeBracket(
      id: 3,
      label: 'Toddlers (1–2 Years)',
      minMonths: 13,
      maxMonths: 24,
    ),
    4: AgeBracket(
      id: 4,
      label: 'Preschoolers (3–5 Years)',
      minMonths: 25,
      maxMonths: 60,
    ),
    5: AgeBracket(
      id: 5,
      label: 'School-Age (6–12 Years)',
      minMonths: 61,
      maxMonths: 144,
    ),
  };

  /// Return 1-5 bracket ID based on date of birth.
  static int bracketFromDob(DateTime dob) {
    final now = DateTime.now();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months--;
    if (months < 0) months = 0;

    if (months <= 6) return 1;
    if (months <= 12) return 2;
    if (months <= 24) return 3;
    if (months <= 60) return 4;
    return 5;
  }

  // ─── Ling Six Sounds ───────────────────────────────────────────
  static const List<LingSixSound> lingSixSounds = [
    LingSixSound(
      phoneme: '/m/',
      label: 'mmm',
      freqRange: '250–500 Hz',
      freqCategory: 'Low',
    ),
    LingSixSound(
      phoneme: '/ah/',
      label: 'aah',
      freqRange: '500–1000 Hz',
      freqCategory: 'Low-Mid',
    ),
    LingSixSound(
      phoneme: '/oo/',
      label: 'ooo',
      freqRange: '500–1000 Hz',
      freqCategory: 'Mid',
    ),
    LingSixSound(
      phoneme: '/ee/',
      label: 'eee',
      freqRange: '1000–3000 Hz',
      freqCategory: 'Mid-High',
    ),
    LingSixSound(
      phoneme: '/sh/',
      label: 'shh',
      freqRange: '2000–4000 Hz',
      freqCategory: 'High',
    ),
    LingSixSound(
      phoneme: '/s/',
      label: 'sss',
      freqRange: '4000–8000 Hz',
      freqCategory: 'Very High',
    ),
  ];

  // ─── User Roles ────────────────────────────────────────────────
  static const String roleParent = 'parent';
  static const String roleTeacher = 'teacher';
  static const String roleHcw = 'hcw';

  // ─── Speech Game Thresholds ────────────────────────────────────
  static const int speechExcellent = 90;
  static const int speechGood = 60;
  static const int speechNeedsPractice = 30;
}

class AgeBracket {
  final int id;
  final String label;
  final int minMonths;
  final int maxMonths;
  const AgeBracket({
    required this.id,
    required this.label,
    required this.minMonths,
    required this.maxMonths,
  });
}

class LingSixSound {
  final String phoneme;
  final String label;
  final String freqRange;
  final String freqCategory;
  const LingSixSound({
    required this.phoneme,
    required this.label,
    required this.freqRange,
    required this.freqCategory,
  });
}
