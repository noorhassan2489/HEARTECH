class QuestionnaireOption {
  final String text;
  final int score; // 0 = low risk, 1 = medium risk, 2 = high risk

  const QuestionnaireOption(this.text, this.score);
}

class Question {
  final String id;
  final String text;
  final bool isClinical;
  final List<QuestionnaireOption> options;

  const Question({
    required this.id,
    required this.text,
    this.isClinical = false,
    this.options = const [
      QuestionnaireOption("Yes", 0),
      QuestionnaireOption("Sometimes/Unsure", 1),
      QuestionnaireOption("No", 2),
    ],
  });
}

class QuestionnaireData {
  static const List<String> ageBrackets = [
    "0-6 months",
    "6-12 months",
    "1-2 years",
    "2-3 years",
    "3+ years",
  ];

  static List<Question> getQuestions(String role, String ageBracket) {
    // We mock the full 15 matrices (3 roles x 5 brackets) with generalized questions 
    // to fit the HearTech clinical/parent/teacher profiles.
    // In production, each of these 15 sets would have 5-10 specific WHO/CDC questions.

    final r = role.toLowerCase();
    
    if (r == "hcw" || r == "healthcare worker") {
      return _getHCWQuestions(ageBracket);
    } else if (r == "teacher") {
      return _getTeacherQuestions(ageBracket);
    } else {
      return _getParentQuestions(ageBracket);
    }
  }

  static List<Question> _getHCWQuestions(String ageBracket) {
    // Clinical Flag: HCW forms can flag specific clinical symptoms that automatically bump risk
    final clinicalOptions = [
      const QuestionnaireOption("None", 0),
      const QuestionnaireOption("Past Infection", 1),
      const QuestionnaireOption("Chronic/Active", 2),
    ];

    final standardList = [
      const Question(
        id: "hcw_c1",
        text: "Are there any physical abnormalities of the ear (e.g., microtia, ear tags)?",
        isClinical: true,
        options: [
          QuestionnaireOption("No", 0),
          QuestionnaireOption("Minor", 1),
          QuestionnaireOption("Yes", 2),
        ],
      ),
      Question(
        id: "hcw_c2",
        text: "History of recurrent otitis media (ear infections)?",
        isClinical: true,
        options: clinicalOptions,
      ),
      const Question(
        id: "hcw_c3",
        text: "Does the child exhibit appropriate startle reflexes to loud noises?",
      ),
    ];

    // Bracket specifics
    if (ageBracket == "0-6 months") {
      standardList.add(const Question(id: "hcw_06_1", text: "Does the infant calm down to the sound of caregiver's voice?"));
    } else if (ageBracket == "6-12 months") {
      standardList.add(const Question(id: "hcw_612_1", text: "Does the child turn their head toward sounds out of sight?"));
    } else if (ageBracket == "1-2 years") {
      standardList.add(const Question(id: "hcw_12_1", text: "Can the child point to correctly named body parts without visual cues?"));
    } else if (ageBracket == "2-3 years") {
      standardList.add(const Question(id: "hcw_23_1", text: "Can the child follow two-step verbal commands?"));
    } else {
      standardList.add(const Question(id: "hcw_3p_1", text: "Is the child's speech intelligible to strangers at least 75% of the time?"));
      standardList.add(const Question(id: "hcw_3p_2", text: "Does the child frequently ask for things to be repeated?"));
    }

    return standardList;
  }

  static List<Question> _getParentQuestions(String ageBracket) {
    if (ageBracket == "0-6 months") {
      return [
        const Question(id: "par_06_1", text: "Does your baby jump or blink at sudden, loud noises?"),
        const Question(id: "par_06_2", text: "Does your baby wake up when there is a loud sound?"),
        const Question(id: "par_06_3", text: "Does your baby soothe or quiet down to your voice?"),
      ];
    } else if (ageBracket == "6-12 months") {
       return [
        const Question(id: "par_612_1", text: "Does your baby turn toward sounds, even if they can't see what's making it?"),
        const Question(id: "par_612_2", text: "Does your baby respond to their name being called?"),
        const Question(id: "par_612_3", text: "Does your baby babble using consonant sounds (like 'baba' or 'dada')?"),
      ];
    } else if (ageBracket == "1-2 years") {
       return [
        const Question(id: "par_12_1", text: "Does your child point to pictures in a book when you name them?"),
        const Question(id: "par_12_2", text: "Does your child use a few single words consistently to mean something?"),
        const Question(id: "par_12_3", text: "Does your child follow simple instructions like 'give it to me'?"),
      ];
    } else if (ageBracket == "2-3 years") {
       return [
        const Question(id: "par_23_1", text: "Does your child understand differences in meaning ('go' vs 'stop', 'up' vs 'down')?"),
        const Question(id: "par_23_2", text: "Does your child put 2 or 3 words together to talk about things?"),
        const Question(id: "par_23_3", text: "Do family members understand most of what the child says?"),
      ];
    } else {
       return [
        const Question(id: "par_3p_1", text: "Does your child hear you when you call from another room?"),
        const Question(id: "par_3p_2", text: "Does your child watch TV at the same volume as the rest of the family?"),
        const Question(id: "par_3p_3", text: "Does your child answer questions about a short story?"),
      ];
    }
  }

  static List<Question> _getTeacherQuestions(String ageBracket) {
    // Teachers usually observe behavioral indicators in older kids, 
    // but early years practitioners might see younger ones.
    
    if (ageBracket == "0-6 months" || ageBracket == "6-12 months") {
      return [
        const Question(id: "tch_inf_1", text: "Does the infant respond to environmental sounds in the nursery?"),
        const Question(id: "tch_inf_2", text: "Does the infant vocalize in response to interaction?"),
      ];
    } else if (ageBracket == "1-2 years") {
      return [
        const Question(id: "tch_12_1", text: "Does the toddler respond to group instructions during activities?"),
        const Question(id: "tch_12_2", text: "Does the toddler prefer highly visual toys over sound-based tracking?"),
        const Question(id: "tch_12_3", text: "Is the toddler's vocalization age-appropriate compared to peers?"),
      ];
    } else {
      return [
        const Question(id: "tch_pre_1", text: "Does the student often need instructions repeated during class?"),
        const Question(id: "tch_pre_2", text: "Does the student tend to watch your lips/face intensely when you speak?"),
        const Question(id: "tch_pre_3", text: "Does the student seem inattentive or easily distracted during verbal tasks?"),
        const Question(id: "tch_pre_4", text: "Is there difficulty with phonics or pronouncing certain sounds compared to peers?"),
        const Question(id: "tch_pre_5", text: "Does the student speak unusually loudly or softly for the environment?"),
      ];
    }
  }
}
