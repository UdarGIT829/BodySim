# Arm (biceps, brachialis, coracobrachialis, triceps)

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (7 entries): accepted Claude (claude-opus-5-5) draft without line-by-line expert review, at the project owner's request; automated rule and whole-table sanity checks passed.

**Rule checks:** all passed

## Brachialis muscle  `muscle.brachialis`
*reviewed · confidence high*

- elbow_joint / flexion: **1.00**

> Brachialis is the prime elbow flexor in all forearm positions because it inserts on the ulna and so is unaffected by pronation or supination. It crosses no other joint in the vocabulary.

## Coracobrachialis muscle  `muscle.coracobrachialis`
*reviewed · confidence medium*

- glenohumeral_joint / adduction: **0.40**
- glenohumeral_joint / flexion: **0.30**
- glenohumeral_joint / horizontal_adduction: **0.30**
- stabilizes glenohumeral_stabilization: 0.20

> Coracobrachialis is a weak synergist for shoulder flexion and adduction and assists horizontal adduction. It helps resist inferior displacement of the humeral head. It does not cross the elbow, so it has no elbow action.

## Lateral head of triceps brachii  `muscle.lateral_head_of_triceps_brachii`
*reviewed · confidence high*

- elbow_joint / extension: **0.90**

> The lateral head is a major elbow extender and is recruited strongly under high loads. It arises from the humerus and does not cross the shoulder.

## Long head of biceps brachii  `muscle.long_head_of_biceps_brachii`
*reviewed · confidence medium*

- elbow_joint / flexion: **0.80**
- radioulnar_joint / supination: **0.80**
- glenohumeral_joint / flexion: **0.30**
- glenohumeral_joint / abduction: **0.20**
- stabilizes humeral_head_stabilization: 0.30
- stabilizes anterior_shoulder_stability: 0.30

> Shared with the short head, this is a major elbow flexor, strongest with the forearm supinated. It is also a major supinator, most effective with the elbow flexed. Its intra-articular tendon weakly assists shoulder flexion and, with the humerus externally rotated, abduction, and it helps depress and centre the humeral head.

## Long head of triceps brachii  `muscle.long_head_of_triceps_brachii`
*reviewed · confidence high*

- elbow_joint / extension: **0.80**
- glenohumeral_joint / extension: **0.40**
- glenohumeral_joint / adduction: **0.30**
- stabilizes glenohumeral_stabilization: 0.20

> The long head is a major elbow extender and the only triceps head that crosses the shoulder. It assists shoulder extension mainly from a flexed position, and also assists adduction. It supports the inferior glenohumeral joint when the arm is abducted.

## Medial head of triceps brachii  `muscle.medial_head_of_triceps_brachii`
*reviewed · confidence high*

- elbow_joint / extension: **0.90**
- stabilizes elbow_joint_integrity: 0.20

> The medial head is active in nearly all elbow extension, including light loads, which makes it a major extender. Its deep fibres (articularis cubiti) tension the posterior elbow capsule. It does not cross the shoulder.

## Short head of biceps brachii  `muscle.short_head_of_biceps_brachii`
*reviewed · confidence medium*

- elbow_joint / flexion: **0.80**
- radioulnar_joint / supination: **0.80**
- glenohumeral_joint / flexion: **0.30**
- glenohumeral_joint / adduction: **0.20**
- glenohumeral_joint / horizontal_adduction: **0.20**

> Shared with the long head, this is a major elbow flexor and supinator, most effective with the elbow flexed. From the coracoid it assists shoulder flexion and gives minor help with adduction and horizontal adduction.
