# Forearm (wrist, finger and forearm-rotation muscles)

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (24 entries): revised by Claude (claude-opus-5-5) from council findings (reports/muscle_actions_v2/feedback/2026-11-06-ez-bar-curl-council.md) and accepted without line-by-line expert review, at the project owner's request; automated rule and whole-table checks passed.

**Rule checks:** all passed

## Abductor pollicis longus  `muscle.abductor_pollicis_longus`
*reviewed · confidence high*

- thumb_joints / abduction: **0.90**
- thumb_joints / extension: **0.30**
- wrist_joint / radial_deviation: **0.30**

> Abducts the thumb at the carpometacarpal joint, alongside abductor pollicis brevis, and assists carpometacarpal extension. Its tendon crosses the radial wrist, so it clearly assists radial deviation. It is a thumb abductor rather than a flexor, so it is not given grip, and its wrist role is too small for wrist_stability.

## Anconeus muscle  `muscle.anconeus`
*reviewed · confidence medium*

- elbow_joint / extension: **0.20**
- stabilizes elbow_stability: 0.30
- stabilizes elbow_joint_integrity: 0.30

> A small muscle that gives minor help to triceps in elbow extension. Its main role is tensing the posterior capsule and stabilizing the humeroulnar joint. The ulnar abduction it produces during pronation is not in the vocabulary.

## Brachioradialis muscle  `muscle.brachioradialis`
*reviewed · confidence medium*

- elbow_joint / flexion: **0.70**
- radioulnar_joint / supination: **0.20**
- radioulnar_joint / pronation: **0.20**
- stabilizes elbow_stability: 0.20

> A major elbow flexor, strongest with the forearm in neutral (hammer position). It rotates the forearm only back toward mid-position, from pronation or from supination, so both rotation weights are minor and position-dependent. It does not cross the wrist, so it has no grip or wrist_stability role.

## Deep head of pronator teres  `muscle.deep_head_of_pronator_teres`
*reviewed · confidence medium*

- radioulnar_joint / pronation: **0.40**

> The small ulnar (coronoid) head pulls the radius into pronation. Because it arises distal to the humerus, it adds essentially no elbow flexion.

## Extensor carpi radialis brevis  `muscle.extensor_carpi_radialis_brevis`
*reviewed · confidence high*

- wrist_joint / extension: **1.00**
- wrist_joint / radial_deviation: **0.40**
- stabilizes wrist_stability: 0.80

> Its central insertion on the third metacarpal makes it the prime wrist extensor, especially during gripping. It is less radially placed than the longus, so radial deviation is a secondary action. It is the main extensor co-contracting to hold the wrist neutral against the flexion pull of a gripped load, hence a high wrist_stability weight.

## Extensor carpi radialis longus  `muscle.extensor_carpi_radialis_longus`
*reviewed · confidence high*

- wrist_joint / radial_deviation: **0.90**
- wrist_joint / extension: **0.80**
- elbow_joint / flexion: **0.10**
- stabilizes wrist_stability: 0.60

> It inserts on the second metacarpal, which makes it a major wrist extensor and a leading radial deviator. Its origin on the supracondylar ridge gives it only a minor elbow flexion moment. It co-contracts with ECRB to hold the wrist neutral under a hand load.

## Extensor digiti minimi  `muscle.extensor_digiti_minimi`
*reviewed · confidence high*

- finger_joints / extension: **0.30**
- wrist_joint / extension: **0.10**

> It extends only the little finger, so its share of overall finger extension is small. It contributes only minor wrist extension, too little for a wrist_stability role.

## Extensor digitorum  `muscle.extensor_digitorum`
*reviewed · confidence high*

- finger_joints / extension: **1.00**
- wrist_joint / extension: **0.50**
- stabilizes wrist_stability: 0.20

> The prime extensor of the medial four fingers at the metacarpophalangeal joints, acting through the extensor expansion. It crosses the wrist dorsally and clearly assists wrist extension, giving a minor contribution to holding the wrist neutral under load; as a finger extensor it is an antagonist to grip, not a grip muscle.

## Extensor indicis  `muscle.extensor_indicis`
*reviewed · confidence high*

- finger_joints / extension: **0.30**
- wrist_joint / extension: **0.10**

> It extends only the index finger, giving independent pointing, so its share of finger extension is small. It contributes only minor wrist extension.

## Extensor pollicis brevis  `muscle.extensor_pollicis_brevis`
*reviewed · confidence high*

- thumb_joints / extension: **0.60**
- thumb_joints / abduction: **0.30**
- wrist_joint / radial_deviation: **0.20**

> It extends the thumb at the metacarpophalangeal and carpometacarpal joints and assists thumb abduction. Its course gives it a small radial deviation moment at the wrist.

## Extensor pollicis longus  `muscle.extensor_pollicis_longus`
*reviewed · confidence high*

- thumb_joints / extension: **1.00**
- thumb_joints / adduction: **0.20**
- wrist_joint / extension: **0.10**

> The prime thumb extensor, and the only one that extends the interphalangeal joint. Its pull around Lister's tubercle also retropositions (adducts) the thumb and slightly assists wrist extension.

## Flexor carpi radialis  `muscle.flexor_carpi_radialis`
*reviewed · confidence high*

- wrist_joint / flexion: **0.90**
- wrist_joint / radial_deviation: **0.60**
- stabilizes wrist_stability: 0.60

> A major wrist flexor that also clearly assists radial deviation together with the radial extensors. Its weak elbow flexion and pronation are negligible and omitted. It co-contracts with the extensors to hold the wrist neutral under a hand load.

## Flexor digitorum profundus  `muscle.flexor_digitorum_profundus`
*reviewed · confidence high*

- finger_joints / flexion: **1.00**
- wrist_joint / flexion: **0.30**
- stabilizes grip: 1.00

> The only flexor of the distal interphalangeal joints, and the prime mover of finger flexion in gripping, so it is the prime grip muscle. It crosses the wrist and assists wrist flexion.

## Flexor pollicis longus  `muscle.flexor_pollicis_longus`
*reviewed · confidence high*

- thumb_joints / flexion: **1.00**
- wrist_joint / flexion: **0.10**
- stabilizes grip: 0.60

> The prime thumb flexor, and the only flexor of the thumb interphalangeal joint; it wraps the thumb around a bar or handle, a clear grip contribution behind the finger flexors. It gives minor assistance to wrist flexion.

## Humeral head of extensor carpi ulnaris  `muscle.humeral_head_of_extensor_carpi_ulnaris`
*reviewed · confidence medium*

- wrist_joint / ulnar_deviation: **0.80**
- wrist_joint / extension: **0.50**
- stabilizes wrist_stability: 0.50

> The main belly of extensor carpi ulnaris. Its insertion on the fifth metacarpal gives a large ulnar deviation moment and a moderate extension moment. The extension moment falls in pronation, which is position-dependent. It stabilizes the ulnar side of the wrist when a load is held.

## Humeral head of flexor carpi ulnaris  `muscle.humeral_head_of_flexor_carpi_ulnaris`
*reviewed · confidence medium*

- wrist_joint / flexion: **0.70**
- wrist_joint / ulnar_deviation: **0.70**
- stabilizes wrist_stability: 0.50
- stabilizes elbow_stability: 0.20

> With the ulnar head, it forms the strongest wrist flexor and ulnar deviator, so the whole-muscle weight is split between the two heads. Its medial epicondyle origin gives a minor dynamic restraint against elbow valgus, and it co-contracts to hold the wrist neutral under load.

## Humero-ulnar head of flexor digitorum superficialis  `muscle.humero_ulnar_head_of_flexor_digitorum_superficialis`
*reviewed · confidence medium*

- finger_joints / flexion: **0.70**
- wrist_joint / flexion: **0.40**
- stabilizes grip: 0.80

> The larger head of flexor digitorum superficialis. It flexes the proximal interphalangeal and metacarpophalangeal joints as a major helper to flexor digitorum profundus, making it a major grip contributor, and assists wrist flexion. Its elbow flexion moment is negligible and omitted.

## Palmaris longus muscle  `muscle.palmaris_longus`
*reviewed · confidence high*

- wrist_joint / flexion: **0.30**
- stabilizes wrist_stability: 0.20

> A small and often absent muscle that weakly flexes the wrist and tenses the palmar aponeurosis, giving a minor share of wrist stabilization. Tensing the aponeurosis is not a vocabulary action.

## Pronator quadratus  `muscle.pronator_quadratus`
*reviewed · confidence high*

- radioulnar_joint / pronation: **1.00**

> The prime pronator in every elbow position, assisted by pronator teres under load or at speed. It also binds the distal radioulnar joint, which is not a listed stabilization demand.

## Radial head of flexor digitorum superficialis  `muscle.radial_head_of_flexor_digitorum_superficialis`
*reviewed · confidence medium*

- finger_joints / flexion: **0.40**
- wrist_joint / flexion: **0.20**
- stabilizes grip: 0.40

> This thin head from the anterior radius joins the superficialis belly, so it flexes the fingers at the proximal interphalangeal joints and assists wrist flexion and grip on a smaller scale than the humero-ulnar head.

## Superficial head of pronator teres  `muscle.superficial_head_of_pronator_teres`
*reviewed · confidence high*

- radioulnar_joint / pronation: **0.80**
- elbow_joint / flexion: **0.20**
- stabilizes elbow_stability: 0.20

> The humeral head is the main bulk of pronator teres and a major pronator, especially against resistance. Because it crosses the elbow, it weakly flexes it and gives minor valgus restraint.

## Supinator  `muscle.supinator`
*reviewed · confidence high*

- radioulnar_joint / supination: **0.80**

> The main supinator during slow or unresisted movement and with the elbow extended. Biceps brachii takes over as prime mover against load with the elbow flexed.

## Ulnar head of extensor carpi ulnaris  `muscle.ulnar_head_of_extensor_carpi_ulnaris`
*reviewed · confidence medium*

- wrist_joint / ulnar_deviation: **0.50**
- wrist_joint / extension: **0.30**
- stabilizes wrist_stability: 0.30

> The smaller head arising from the posterior ulna joins the common tendon to the fifth metacarpal. It gives clear help with ulnar deviation and a moderate extension moment that depends on forearm rotation, and a smaller share of ulnar-side wrist stabilization than the humeral head.

## Ulnar head of flexor carpi ulnaris  `muscle.ulnar_head_of_flexor_carpi_ulnaris`
*reviewed · confidence medium*

- wrist_joint / flexion: **0.70**
- wrist_joint / ulnar_deviation: **0.70**
- stabilizes wrist_stability: 0.50

> With the humeral head, it forms the strongest wrist flexor and ulnar deviator, inserting via the pisiform on the hamate and fifth metacarpal, and co-contracts to hold the wrist neutral under load. It arises from the olecranon and ulna, so it does not act at the elbow.
