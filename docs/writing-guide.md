# Writing guide for the expanded edition

This is the brief for anyone extending the lessons: the shape of a lesson,
the block syntax, the vocabulary rules, the reading plan, and the story
outline for the composed readings. It was written for the 2026 expansion
(ten-item exercises, a Reading movement in every lesson, Part VI) and is
the standard any later lesson should meet.

## The lesson, in six movements

Every lesson keeps the same order. A lesson now runs across two class
periods of 45 minutes; the first period is movements 1–3, the second is
4–6.

| | Movement | Block | What it holds |
|:--|:--|:--|:--|
| 1 | The Story | `::: {.story time="5 min"}` | A classroom scene. English. |
| 2 | The New Greek | `::: {.newgreek time="10 min"}` | One grammatical idea, with examples; the `::: vocab` box. |
| 3 | The Investigation | `::: {.investigation time="20 min"}` | Exercises. Each exercise has **ten** items. One of them is **Retrieval**. |
| 4 | The Ancient Voice | `::: {.voice time="10 min" source="…"}` | A short authentic text, glossed line by line, with teacher notes. Unchanged. |
| 5 | The Reading | `::: {.reading time="20 min" title="…" source="…"}` | A passage of connected Greek with a running vocabulary beside it, then comprehension questions. |
| 6 | The Question | `::: {.question time="5 min"}` | Three reflection questions. |

A closing `::: {.story time="—"}` may follow The Question, as before.

## Block syntax

Fenced divs, exactly as in the existing lessons. Answer keys go in
`::: answers` immediately after their exercise and appear only in the
teacher's edition; teacher notes go in `::: teacheronly`. The checker
(`make check`) knows the block names `story newgreek investigation voice
question vocab exercise answers teacheronly note grammar latinbridge
paradigm part reading gloss`.

The Reading block:

```
::: {.reading time="20 min" title="The cat and the tablet" source="composed"}
**ὁ Φῆλιξ** βλέπει τὸν αἴλουρον. ὁ αἴλουρος οὐ βλέπει τὸν Φήλικα …

(more paragraphs of Greek; blank line between paragraphs)

::: gloss
- **ὁ αἴλουρος** — cat
- **ἡ τράπεζα** — table
- **καθεύδει** — sleeps *(3rd sing.)*
:::

::: {.exercise title="Understanding the reading"}
1. Where is the cat at the start of the story? What word tells you?
…
:::

::: answers
1. …
:::
:::
```

Everything before `::: gloss` is set as the passage (left column, 60%);
the gloss list is set beside it (right column, small type); everything
after the gloss runs full width. The `source` attribute is `composed`,
`adapted from …`, or the citation of an unadapted text.

## Vocabulary rules

These follow the research summary in `docs/didactics-review.md`.

1. **Every lesson's `::: vocab` box lists 12–15 required words**, the ones
   a pupil will be tested on. Existing boxes have 5–9; raise them to the
   range by adding words the lesson's reading needs, chosen from the
   high-frequency core (the DCC Greek core list, or Major's 80% list) where
   there is a choice. Never add a word the lesson does not then use.
2. **The reading may use any word from any earlier vocab box without a
   gloss.** Every other word in the reading is glossed in the `::: gloss`
   list beside it — in English, one line each, with the form that appears
   in the text if it is not the dictionary form (`**ἔδραμεν** — ran
   *(aorist of τρέχω)*`). Glossed words are not examinable.
3. **Re-encounter.** A word from a vocab box should reappear in the
   readings of at least six later lessons. When you write a reading, reach
   first for words taught two to five lessons earlier.
4. **Forms.** A reading may use only forms the lesson has taught (see the
   grammar schedule below). A form the pupils have not met may appear
   *only* if it is glossed whole in the gloss list, and no more than three
   such forms per reading. Do not use the middle or passive, the future,
   the perfect, the subjunctive, or -μι verbs (other than εἰμί) before Part
   VI; do not use participles before Lesson 21; do not use the third
   declension before Lesson 15 except in words already taught whole.
5. **Names.** Θεόδωρος, Μᾶρκος, Ἰουλία, Φῆλιξ (gen. Φήλικος — avoid
   oblique cases before Lesson 15, or gloss them), Σαβῖνα, Κόιντος, Λιβία,
   Θεοδόσιος, Αἰλία; the cat is **ὁ αἴλουρος**; the paedagogus is
   **ὁ παιδαγωγός**; the house is **ἡ οἰκία**; the school room is **τὸ
   διδασκαλεῖον** (gloss it).

## Exercise rules

1. **Ten items per exercise.** Keep the existing items (renumbering if
   needed) and add new ones in the same style; the new items may use only
   the vocabulary and forms available at that lesson.
2. **Every exercise has an answer key** in `::: answers`, item by item,
   with a note on the likely wrong answer where there is one. Keep the
   existing notes.
3. **Add one exercise titled `Retrieval`** to every lesson from Lesson 2 on,
   placed first in The Investigation. Ten short mixed items drawing on the
   previous three or four lessons (not the current one): a form to
   identify, a word to translate, a sentence to turn round, a case to name.
   Its key is in `::: answers` like any other. Its purpose is retrieval
   practice, so items must be answerable from memory, not by looking up.
4. **Into Greek** stays short: ten items, each a single sentence.

## The reading plan

| Lessons | Kind | Length | Notes |
|:--|:--|:--|:--|
| 1–2 | none | — | The alphabet lessons have no Reading movement. |
| 3–14 | composed | 50 → 150 words | *Theodoros's tablets*: a continuous story in Greek, written by Theodoros about his own pupils, which he sets them to read. One episode per lesson, following the outline below. |
| 15–30 | authentic, tiered | 100 → 250 words | A real passage, given in **two tiers**: first an adapted version in the vocabulary and forms the class has, then the original. Label both. The gloss list serves the original. |
| 31–36 | authentic, tiered | 200 → 300 words | As above. |

Authentic passages assigned (do not change without reason — they are
chosen so each lesson's grammar is on the page):

| Lesson | Passage |
|:--|:--|
| 15 | Homer, *Odyssey* 1.1–10 |
| 16 | Homer, *Odyssey* 9.360–370 (the naming) |
| 17 | Plato, *Apology* 38a (ὁ δὲ ἀνεξέταστος βίος…) with its surrounding sentence |
| 18 | John 1:1–5 |
| 19 | 1 John 4:7–12 |
| 20 | Psalm 22 (LXX), whole |
| 21 | Matthew 5:1–12 |
| 22 | Luke 10:25–37, whole |
| 23 | Xenophon, *Anabasis* 1.1.1–3 beside Mark 1:9–11 |
| 24 | Aesop, *The North Wind and the Sun* (Perry 46), in the Attic-ised text of the collections, labelled as such |
| 25 | Plato, *Meno* 70a–71a |
| 26 | Matthew 7:7–12 |
| 27 | Mark 4:35–41 |
| 28 | BGU II 423, whole (regularised tier, then the papyrus's own spellings) |
| 29 | Plato, *Crito* 43a–b |
| 30 | John 1:1–14 |
| 31 | Mark 1:9–13 (middle and passive) |
| 32 | Matthew 6:25–34 (futures) |
| 33 | 1 Corinthians 15:3–8 (perfects) |
| 34 | John 21:15–17 (contract verbs) |
| 35 | John 3:1–8 (subjunctive, ἵνα, ἐάν) |
| 36 | Matthew 7:7–11 and Plato, *Apology* 29d (-μι verbs) |

Quote the standard text (NA28 for the New Testament; Rahlfs for the
Septuagint; the Oxford texts for Homer, Plato and Xenophon). Mark anything
adapted as adapted.

## Theodoros's tablets: outline of the composed story, Lessons 3–14

The conceit: from Lesson 3, Theodoros writes a short story in Greek about
the class, on a tablet, and sets it to be read. The pupils are reading
about themselves. The stories are in Attic, in the vocabulary the class
has, and they are slightly unfair to everybody. Keep each episode to
what the lesson's grammar allows; the outline says what happens, not how
it is phrased.

- **3. The cat on the table.** The cat is on the table. Felix sees the
  cat; the cat does not see Felix. Marcus sees the teacher; the teacher
  sees Marcus. Nominative and accusative, article and noun, present of
  βλέπω and εἰμί-less sentences. ~50 words.
- **4. Who sees whom.** The courtroom: the judge (Sabina) sees the
  witness (Felix); the witness does not see the judge; Marcus, the
  accused, sees the road. Word order shuffled for emphasis; vocatives
  (ὦ κριτά, ὦ μάρτυς). ~60 words.
- **5. Everyone says who they are.** Each pupil says one thing about
  themselves in the first person; the cat says nothing. εἰμί in full,
  present active, ἐγώ for emphasis. ~70 words.
- **6. The teacher's "no".** Marcus says he cannot read; the teacher says
  he has not looked; Marcus looks; he reads. οὐ/οὐκ/οὐχ, the imperfect
  ἦν only as glossed. ~80 words.
- **7. Plural things.** The pupils carry the tablets; the days are long;
  the deeds of the pupils are not the words of the pupils. Plurals of
  article and nouns; neuter plural with singular verb. ~80 words.
- **8. Whose tablet.** The tablet of the teacher is in the house of the
  judge; the son of the teacher has the book of the judge. Genitives,
  ἐκ/ἀπό/περί. ~90 words.
- **9. The letter to the teacher.** Felix writes a letter to the teacher
  but gives it to the cat; the cat gives nothing to anyone. Datives, ἐν,
  σύν. ~100 words.
- **10. The wise and the good.** Sabina gives everyone an adjective;
  nobody agrees with hers. Attributive and predicate position: *the wise
  Julia* against *Julia is wise*. ~100 words.
- **11. Who is acting.** A sheet of sentences with no subjects; the class
  works out who did what from the endings. All persons of the present.
  ~110 words.
- **12. Man the measure.** The class argues about whether the pupil is
  the measure of the lesson; Theodoros's tablet says the teacher is.
  Review of Parts I–II; nothing new. ~120 words.
- **13. What happened yesterday.** Yesterday the teacher was speaking and
  the pupils were listening; the cat was sleeping. Imperfect throughout.
  ~130 words.
- **14. What happened next.** Then Felix spoke; then the cat woke; then
  the tablet fell. Imperfect against aorist, each used where it belongs.
  ~150 words.

## Part VI

Lessons 31–36 follow the six-movement shape exactly, with the story
continuing from Lesson 30 (the Great Reading is over; the class is in its
second term; Theodoros is now teaching them to write what they can read).
The grammar for each:

- **31. The voice that looks back.** The middle and passive: present,
  imperfect and aorist middle (λύομαι, ἐλυόμην, ἐλυσάμην), the aorist
  passive (ἐλύθην), deponents (βούλομαι, γίγνομαι, ἔρχομαι, δύναμαι —
  already met whole), and what "middle" means. Mark 1:9–13.
- **32. What will be.** The future active and middle (λύσω, λύσομαι),
  including the contract future of liquids (μενῶ), εἶμι as future of
  ἔρχομαι, and the deponent futures of common verbs. Matthew 6:25–34.
- **33. What stands done.** The perfect active and middle/passive
  (λέλυκα, λέλυμαι), reduplication, the perfect as a present state;
  οἶδα explained at last; the pluperfect in one paragraph. 1 Corinthians
  15:3–8.
- **34. Verbs that melt.** Contract verbs: -άω, -έω, -όω in the present
  and imperfect, with ἀγαπάω, ποιέω, φιλέω, δηλόω. John 21:15–17.
- **35. What might be.** The subjunctive: present and aorist; ἵνα,
  ἐάν, οὐ μή, hortatory and deliberative uses; conditions in one table.
  John 3:1–8.
- **36. The old verbs.** The -μι verbs: δίδωμι, τίθημι, ἵστημι in the
  present and aorist; εἰμί and εἶμι in full; φημί. Matthew 7:7–11 and
  Plato, *Apology* 29d.

Part VI readings are tiered like Part V's. Its vocab boxes carry 15 words
each. Its Retrieval exercises range over all of Parts I–V.
