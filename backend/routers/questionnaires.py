from fastapi import APIRouter

router = APIRouter()

# ═══════════════════════════════════════════════════════════════════════════════
# QUESTIONNAIRE DATA — All 15 questionnaire sets (5 HCW + 5 Parent + 5 Teacher)
# ═══════════════════════════════════════════════════════════════════════════════

QUESTIONNAIRES = {
    # ─── HCW Bracket 1 (0-6 months) ──────────────────────────────────────
    "hcw_1": [
        {"id": "hcw1_q1", "text": "Does the child startle or jump at sudden, loud noises?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q2", "text": "Does the child quiet down or smile when they hear your voice?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q3", "text": "Does the child move their eyes or turn toward the direction of sounds?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q4", "text": "Does the child make cooing or babbling sounds (oooo, pa, ba)?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q5", "text": "Does the child react to toys that make sounds?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q6", "text": "Was the child born prematurely or admitted to NICU?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q7", "text": "Is there any family history of childhood hearing loss?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw1_q8", "text": "Has the child had severe illnesses since birth (meningitis, jaundice, infections)?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
    ],
    # ─── HCW Bracket 2 (7-12 months) ─────────────────────────────────────
    "hcw_2": [
        {"id": "hcw2_q1", "text": "Does the child turn to look at you when you call their name?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q2", "text": "Does the child respond to simple phrases like 'No' or 'Come here'?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q3", "text": "Does the child understand words for common items (cup, ball, truck)?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q4", "text": "Does the child babble in long strings of sounds (mamama, bababa)?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q5", "text": "Does the child use gestures like waving bye-bye or pointing?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q6", "text": "Has the child started saying 1-2 simple words like dada or mama?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q7", "text": "Does the child only notice you when they see you, not when called?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw2_q8", "text": "Has the child had frequent ear infections or fluid in the ears?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
    ],
    # ─── HCW Bracket 3 (1-2 years) ───────────────────────────────────────
    "hcw_3": [
        {"id": "hcw3_q1", "text": "Can the child point to body parts when asked (Where is your nose)?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q2", "text": "Can the child follow simple 1-part directions without gesturing?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q3", "text": "Does the child listen to stories, songs, and rhymes?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q4", "text": "Is the child using new words and starting to put 2 words together?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q5", "text": "Does the child respond to simple questions (Who's that, Where's your shoe)?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q6", "text": "Do you have to speak loudly or repeat yourself often to be understood?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q7", "text": "Does the child frequently pull or tug at their ears?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw3_q8", "text": "Is there a noticeable speech delay compared to peers?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
    ],
    # ─── HCW Bracket 4 (3-5 years) ───────────────────────────────────────
    "hcw_4": [
        {"id": "hcw4_q1", "text": "Does the child respond when called from another room?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q2", "text": "Can the child follow 2 or 3-part directions?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q3", "text": "Does the child understand words for colors, shapes, and family members?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q4", "text": "Can the child answer Who, What, Where, and Why questions?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q5", "text": "Do people outside the family understand the child most of the time?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q6", "text": "Does the child turn the TV volume up excessively high?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q7", "text": "Does the child frequently say 'Huh' or 'What' when spoken to?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw4_q8", "text": "Has the child had more than 3 ear infections in the past year?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
    ],
    # ─── HCW Bracket 5 (6-12 years) ──────────────────────────────────────
    "hcw_5": [
        {"id": "hcw5_q1", "text": "Does the child frequently ask for instructions to be repeated?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q2", "text": "Is the child experiencing difficulty with reading, phonics, or academics?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q3", "text": "Does the child have unclear speech or articulation issues?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q4", "text": "Does the child seem inattentive, especially in noisy environments?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q5", "text": "Does the child struggle with jokes, idioms, or fast conversations?", "isClinical": False, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q6", "text": "Does the child complain of ringing in their ears or ear pain?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q7", "text": "Does the child favor one ear over the other when listening?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
        {"id": "hcw5_q8", "text": "Does the child speak unusually loudly or softly?", "isClinical": True, "responseType": "yes_partial_no_notsure"},
    ],
    # ─── PARENT Bracket 1 (0-6 months) ───────────────────────────────────
    "parent_1": [
        {"id": "par1_q1", "text": "Does your baby startle, blink, or jump at sudden loud sounds?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q2", "text": "Does your baby calm down when you talk or sing to them?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q3", "text": "Does your baby seem to recognize your voice vs a stranger's?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q4", "text": "Does your baby make sounds like coos, gurgles, or babbling (oooh, aah)?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q5", "text": "Does your baby look toward the source of sounds like a rattle?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q6", "text": "Does your baby react differently to loud and soft sounds?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q7", "text": "Was your baby born before 37 weeks (premature)?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par1_q8", "text": "Does your family have a history of hearing problems in young children?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
    ],
    # ─── PARENT Bracket 2 (7-12 months) ──────────────────────────────────
    "parent_2": [
        {"id": "par2_q1", "text": "Does your baby turn to look at you when you call their name?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q2", "text": "Does your baby understand simple words like 'No' or their name?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q3", "text": "Does your baby babble with different sounds strung together?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q4", "text": "Does your baby wave bye-bye or point at things they want?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q5", "text": "Does your baby try to copy sounds you make?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q6", "text": "Has your baby started saying any words like mama or dada?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q7", "text": "Does your baby only notice you when they can see you, not when called?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par2_q8", "text": "Has your doctor mentioned ear fluid or ear infections?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
    ],
    # ─── PARENT Bracket 3 (1-2 years) ────────────────────────────────────
    "parent_3": [
        {"id": "par3_q1", "text": "Can your child point to their nose or tummy when you ask?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q2", "text": "Can your child follow a simple instruction without you pointing?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q3", "text": "Does your child enjoy songs, nursery rhymes, or being read to?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q4", "text": "Is your child using more new words every month?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q5", "text": "Does your child try to put two words together like 'more juice'?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q6", "text": "Does your child look at you or TV when they hear familiar sounds?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q7", "text": "Do you repeat things several times for your child to respond?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par3_q8", "text": "Does your child pull at their ears frequently?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
    ],
    # ─── PARENT Bracket 4 (3-5 years) ────────────────────────────────────
    "parent_4": [
        {"id": "par4_q1", "text": "Does your child respond when you call from a different room?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q2", "text": "Can your child follow instructions with two or three steps?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q3", "text": "Can your child tell simple stories or talk about their day?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q4", "text": "Do people outside your family understand most of what your child says?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q5", "text": "Does your child enjoy conversation and ask lots of why and what questions?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q6", "text": "Does your child understand colors, shapes, and family member names?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q7", "text": "Does your child set the TV very loud, louder than others prefer?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par4_q8", "text": "Does your child frequently say 'what' or 'huh' or ask you to repeat yourself?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
    ],
    # ─── PARENT Bracket 5 (6-12 years) ───────────────────────────────────
    "parent_5": [
        {"id": "par5_q1", "text": "Does your child frequently ask you to repeat things?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q2", "text": "Does your child struggle with schoolwork or following teacher instructions?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q3", "text": "Is your child's speech hard to understand or do they mispronounce words?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q4", "text": "Does your child zone out, especially in noisy environments?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q5", "text": "Does your child find it hard to follow conversations with background noise?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q6", "text": "Does your child complain of ringing sounds or ear pain?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q7", "text": "Does your child turn one ear toward you when listening?", "isClinical": False, "responseType": "yes_sometimes_no_notsure"},
        {"id": "par5_q8", "text": "Has your child had more than 3 ear infections in the past 12 months?", "isClinical": True, "responseType": "yes_sometimes_no_notsure"},
    ],
    # ─── TEACHER Bracket 1-2 (0-12 months) ───────────────────────────────
    "teacher_1": [
        {"id": "tch12_q1", "text": "Does the child react visibly (startles, turns head) to sudden classroom sounds?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q2", "text": "Does the child look toward speakers or sound sources during activities?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q3", "text": "Does the child respond to their name by turning or making eye contact?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q4", "text": "Does the child vocalize or babble during playtime?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q5", "text": "Is the child more attentive when in your direct line of sight vs behind them?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q6", "text": "Does the child fail to react to sounds that make other children react?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q7", "text": "Has the child's family mentioned any hearing concerns or medical history?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
    ],
    "teacher_2": [
        {"id": "tch12_q1", "text": "Does the child react visibly (startles, turns head) to sudden classroom sounds?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q2", "text": "Does the child look toward speakers or sound sources during activities?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q3", "text": "Does the child respond to their name by turning or making eye contact?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q4", "text": "Does the child vocalize or babble during playtime?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q5", "text": "Is the child more attentive when in your direct line of sight vs behind them?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q6", "text": "Does the child fail to react to sounds that make other children react?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch12_q7", "text": "Has the child's family mentioned any hearing concerns or medical history?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
    ],
    # ─── TEACHER Bracket 3 (1-2 years) ───────────────────────────────────
    "teacher_3": [
        {"id": "tch3_q1", "text": "Does the child respond to their name from a normal distance consistently?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q2", "text": "Does the child follow simple one-step classroom instructions?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q3", "text": "Does the child participate in group songs, clapping, sound-based activities?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q4", "text": "Does the child vocalize or communicate with teachers and peers?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q5", "text": "Does the child appear confused or ignore instructions other children follow?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q6", "text": "Does the child watch others to copy actions (possible hearing compensation)?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q7", "text": "Does the child react more to touch than to being called?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch3_q8", "text": "Have you seen the child tug at their ears or show ear discomfort?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
    ],
    # ─── TEACHER Bracket 4 (3-5 years) ───────────────────────────────────
    "teacher_4": [
        {"id": "tch4_q1", "text": "Does the child follow class directions without individual prompting?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q2", "text": "Does the child participate in circle time and group discussions?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q3", "text": "Can the child follow a story and answer simple questions about it?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q4", "text": "Is the child's speech understood by you and classmates most of the time?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q5", "text": "Does the child ask for repetition more than other children?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q6", "text": "Does the child watch others' faces or lips closely when they speak?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q7", "text": "Does the child seem easily distracted with background noise?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch4_q8", "text": "Does the child consistently sit very close to you during group activities?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
    ],
    # ─── TEACHER Bracket 5 (6-12 years) ──────────────────────────────────
    "teacher_5": [
        {"id": "tch5_q1", "text": "Does the child frequently ask for instructions or questions to be repeated?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q2", "text": "Does the child have difficulty following multi-step verbal instructions?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q3", "text": "Does the child struggle with reading, phonics, spelling, or verbal comprehension?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q4", "text": "Does the child seem easily distracted in a noisy classroom?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q5", "text": "Does the child respond incorrectly as if they misheard the question?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q6", "text": "Does the child watch your lips or face intently while listening?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q7", "text": "Does the child struggle socially — missing jokes, mishearing peers?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q8", "text": "Does the child speak unusually loudly or softly compared to peers?", "isClinical": False, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q9", "text": "Does the child consistently position closer to you or the audio source?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
        {"id": "tch5_q10", "text": "Have parents mentioned hearing concerns, ear infections, or medical history?", "isClinical": True, "responseType": "always_often_sometimes_rarely_never"},
    ],
}


@router.get("/questionnaire/{role}/{bracket_id}")
async def get_questionnaire(role: str, bracket_id: int):
    """
    Serve questionnaire JSON for a given role and age bracket.
    role: hcw | parent | teacher
    bracket_id: 1-5
    Returns: { questions: [ { id, text, isClinical, responseType } ] }
    """
    key = f"{role}_{bracket_id}"

    if key not in QUESTIONNAIRES:
        return {
            "questions": [],
            "message": f"No questionnaire found for {role} bracket {bracket_id}."
        }

    return {"questions": QUESTIONNAIRES[key]}
