# Shoulder girdle (deltoid, rotator cuff, teres major, trapezius)

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (11 entries): revised by Claude (claude-opus-5-5) from council findings (reports/muscle_actions_v2/feedback/2026-11-06-ez-bar-curl-council.md) and accepted without line-by-line expert review, at the project owner's request; automated rule and whole-table checks passed.

**Rule checks:** all passed

## Acromial part of deltoid muscle  `muscle.acromial_part_of_deltoid`
*reviewed · confidence high*

- glenohumeral_joint / abduction: **1.00**
- glenohumeral_joint / horizontal_abduction: **0.30**
- glenohumeral_joint / flexion: **0.20**
- stabilizes shoulder_position_hold: 0.40

> The multipennate middle deltoid is the prime abductor, with supraspinatus as its main partner, and it assists horizontal abduction. It contributes to flexion only when the arm is elevated in the scapular plane. It works isometrically to hold the arm elevated or overhead, for example in an overhead triceps extension, so it gets a moderate shoulder_position_hold weight.

## Ascending part of trapezius muscle  `muscle.ascending_part_of_trapezius`
*reviewed · confidence high*

- scapulothoracic_joint / depression: **0.80**
- scapulothoracic_joint / upward_rotation: **0.70**
- scapulothoracic_joint / retraction: **0.50**
- stabilizes scapular_stabilization: 0.80
- stabilizes scapular_retraction_stability: 0.50
- stabilizes scapular_anchoring: 0.50

> Lower trapezius fibres pull the scapular spine medially and downward, so they depress and retract the scapula. Paired with serratus anterior and upper trapezius, they form the upward-rotation force couple that is critical during overhead elevation.

## Clavicular part of deltoid muscle  `muscle.clavicular_part_of_deltoid`
*reviewed · confidence high*

- glenohumeral_joint / flexion: **1.00**
- glenohumeral_joint / horizontal_adduction: **0.60**
- glenohumeral_joint / internal_rotation: **0.30**
- glenohumeral_joint / abduction: **0.30**
- stabilizes shoulder_position_hold: 1.00

> The anterior deltoid is the prime shoulder flexor, alongside clavicular pectoralis major, and assists horizontal adduction and internal rotation. It contributes to abduction mainly above about 60 degrees and in the scapular plane. As the main resister of the shoulder-extension moment, it holds the upper arm still in curls and keeps the arm overhead in triceps extensions, so it is the primary shoulder_position_hold muscle.

## Descending part of trapezius muscle  `muscle.descending_part_of_trapezius`
*reviewed · confidence high*

- scapulothoracic_joint / elevation: **1.00**
- scapulothoracic_joint / upward_rotation: **0.70**
- scapulothoracic_joint / retraction: **0.30**
- cervical_spine / extension: **0.30**
- cervical_spine / lateral_flexion: **0.30**
- cervical_spine / rotation: **0.20**
- stabilizes scapular_stabilization: 0.50
- stabilizes scapular_anchoring: 0.30

> Upper trapezius is the prime scapular elevator with levator scapulae and is part of the upward-rotation force couple. With the scapula fixed, it extends the neck, flexes it laterally to the same side and rotates the head to the opposite side.

## Infraspinatus muscle  `muscle.infraspinatus`
*reviewed · confidence high*

- glenohumeral_joint / external_rotation: **1.00**
- glenohumeral_joint / horizontal_abduction: **0.50**
- stabilizes glenohumeral_stabilization: 1.00
- stabilizes humeral_head_stabilization: 0.80

> Infraspinatus is the prime external rotator and assists horizontal abduction. As a posterior cuff muscle, it compresses the humeral head into the glenoid and pulls it inferiorly during elevation.

## Scapular spinal part of deltoid muscle  `muscle.scapular_spinal_part_of_deltoid`
*reviewed · confidence high*

- glenohumeral_joint / horizontal_abduction: **1.00**
- glenohumeral_joint / extension: **0.70**
- glenohumeral_joint / external_rotation: **0.40**
- stabilizes shoulder_position_hold: 0.40

> The posterior deltoid is the prime horizontal abductor and a major extensor alongside latissimus dorsi, and it assists external rotation; its abduction contribution is negligible and omitted. It resists shoulder flexion isometrically, for example stopping the elbows drifting forward in a curl, so it gets a moderate shoulder_position_hold weight.

## Subscapularis muscle  `muscle.subscapularis`
*reviewed · confidence high*

- glenohumeral_joint / internal_rotation: **1.00**
- glenohumeral_joint / adduction: **0.20**
- stabilizes anterior_shoulder_stability: 1.00
- stabilizes glenohumeral_stabilization: 1.00
- stabilizes humeral_head_stabilization: 0.70

> Subscapularis is the prime internal rotator and the main dynamic restraint against anterior humeral head translation. It gives only minor adduction from an abducted position.

## Supraspinatus muscle  `muscle.supraspinatus`
*reviewed · confidence high*

- glenohumeral_joint / abduction: **0.70**
- stabilizes glenohumeral_stabilization: 0.90
- stabilizes humeral_head_stabilization: 0.50

> Supraspinatus initiates abduction and works with the acromial deltoid throughout the range, mainly by compressing and centring the humeral head. Its slight external rotation contribution is negligible and omitted.

## Teres major muscle  `muscle.teres_major`
*reviewed · confidence high*

- glenohumeral_joint / extension: **0.70**
- glenohumeral_joint / adduction: **0.70**
- glenohumeral_joint / internal_rotation: **0.60**

> Teres major acts with latissimus dorsi to extend, adduct and internally rotate the humerus. It is most active against resistance and when the scapula is stabilized by the rhomboids. It is not a rotator cuff muscle, and its isometric arm-holding role is minor, so shoulder_position_hold is left to the deltoid parts.

## Teres minor muscle  `muscle.teres_minor`
*reviewed · confidence high*

- glenohumeral_joint / external_rotation: **0.70**
- glenohumeral_joint / horizontal_abduction: **0.30**
- glenohumeral_joint / adduction: **0.20**
- stabilizes glenohumeral_stabilization: 0.70
- stabilizes humeral_head_stabilization: 0.60

> Teres minor is a major external rotator alongside infraspinatus, assists horizontal abduction and gives weak adduction. It is a posterior cuff stabilizer that depresses and centres the humeral head.

## Transverse part of trapezius muscle  `muscle.transverse_part_of_trapezius`
*reviewed · confidence high*

- scapulothoracic_joint / retraction: **1.00**
- scapulothoracic_joint / upward_rotation: **0.30**
- stabilizes scapular_retraction_stability: 1.00
- stabilizes scapular_stabilization: 0.70
- stabilizes scapular_anchoring: 0.50

> Horizontal middle trapezius fibres are the prime scapular retractors, with the rhomboids as partners. They hold the scapula retracted during rowing and pressing, and contribute modestly to upward rotation.
