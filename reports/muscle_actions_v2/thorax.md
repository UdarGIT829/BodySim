# Thorax (pectorals, serratus, intercostals, diaphragm)

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (13 entries): accepted Claude (claude-opus-5-5) draft without line-by-line expert review, at the project owner's request; automated rule and whole-table sanity checks passed.

**Rule checks:** all passed

## Abdominal part of pectoralis major muscle  `muscle.abdominal_part_of_pectoralis_major`
*reviewed · confidence medium*

- glenohumeral_joint / adduction: **0.70**
- glenohumeral_joint / horizontal_adduction: **0.50**
- glenohumeral_joint / extension: **0.40**
- glenohumeral_joint / internal_rotation: **0.40**
- scapulothoracic_joint / depression: **0.20**

> The lowest, most obliquely ascending fibres act mainly as an adductor. They assist extension only from a flexed position, as in a dip or pullover. The shoulder-girdle depression is indirect, acting via the humerus, so it is kept minor.

## Clavicular head of pectoralis major muscle  `muscle.clavicular_head_of_pectoralis_major`
*reviewed · confidence high*

- glenohumeral_joint / horizontal_adduction: **0.80**
- glenohumeral_joint / flexion: **0.70**
- glenohumeral_joint / internal_rotation: **0.40**
- glenohumeral_joint / adduction: **0.30**

> It is a major shoulder flexor alongside the anterior deltoid and a strong horizontal adductor, as in an incline press. It adducts only with the arm below about 90 degrees, so adduction is weighted lower than for the sternocostal head.

## Diaphragm  `muscle.diaphragm`
*reviewed · confidence high*

- stabilizes intra_abdominal_pressure: 1.00

> The diaphragm moves no vocabulary joint. It is the principal generator of intra-abdominal pressure during bracing, working with transversus abdominis and the pelvic floor.

## External intercostal muscles  `muscle.external_intercostal`
*reviewed · confidence low*

- stabilizes anti_rotation_torso: 0.10

> Its main role is inspiration by elevating the ribs. It assists contralateral thoracic rotation, which has no thoracic-spine term in the vocabulary, so only a minor anti-rotation bracing role is listed.

## Innermost intercostal muscles  `muscle.innermost_intercostal`
*reviewed · confidence medium* · **not a movement muscle**

- (no actions)

> This thin, incomplete layer acts with the internal intercostals in respiration. There is no meaningful evidence that it contributes to trunk bracing or joint movement.

## Internal intercostal muscles  `muscle.internal_intercostal`
*reviewed · confidence low*

- stabilizes anti_rotation_torso: 0.10

> It depresses the ribs in forced expiration. It assists ipsilateral thoracic rotation, which is absent from the vocabulary, so only a minor anti-rotation bracing role is listed.

## Levatores breves costarum  `muscle.levatores_breves_costarum`
*reviewed · confidence medium* · **not a movement muscle**

- (no actions)

> These small muscles elevate the ribs. Any thoracic lateral flexion or rotation they produce is negligible and outside the vocabulary, so they are not treated as exercise muscles.

## Levatores longi costarum  `muscle.levatores_longi_costarum`
*reviewed · confidence medium* · **not a movement muscle**

- (no actions)

> They elevate the ribs, spanning two levels. Their thoracic rotation and lateral flexion effect is negligible and not in the vocabulary.

## Pectoralis minor muscle  `muscle.pectoralis_minor`
*reviewed · confidence high*

- scapulothoracic_joint / depression: **0.60**
- scapulothoracic_joint / downward_rotation: **0.60**
- scapulothoracic_joint / protraction: **0.50**
- stabilizes scapular_stabilization: 0.30

> Pulling on the coracoid, it tilts the scapula anteriorly and downward-rotates it with the rhomboids and levator scapulae. It depresses and assists serratus anterior in protraction, and helps fix the scapula in dips and push-ups. Its rib elevation in forced inspiration is not in the vocabulary.

## Serratus anterior muscle  `muscle.serratus_anterior`
*reviewed · confidence high*

- scapulothoracic_joint / protraction: **1.00**
- scapulothoracic_joint / upward_rotation: **1.00**
- scapulothoracic_joint / depression: **0.20**
- stabilizes scapular_anchoring: 1.00
- stabilizes scapular_stabilization: 0.80

> It is the prime protractor. It is also the co-prime upward rotator with the trapezius, its lower fibres dominating, and those lower fibres contribute slightly to depression. It holds the scapula against the thorax as the base for pressing and overhead work.

## Sternocostal head of pectoralis major muscle  `muscle.sternocostal_head_of_pectoralis_major`
*reviewed · confidence high*

- glenohumeral_joint / horizontal_adduction: **1.00**
- glenohumeral_joint / adduction: **0.80**
- glenohumeral_joint / extension: **0.50**
- glenohumeral_joint / internal_rotation: **0.50**

> It is the prime horizontal adductor, as in a flat press or fly, and a major adductor alongside latissimus dorsi. It extends the humerus only from a flexed position back toward neutral, and assists internal rotation.

## Subclavius muscle  `muscle.subclavius`
*reviewed · confidence medium*

- scapulothoracic_joint / depression: **0.20**
- stabilizes scapular_stabilization: 0.20

> It depresses the clavicle and draws it toward the sternum, stabilizing the sternoclavicular joint during shoulder-girdle movement. Its contribution to depression of the whole girdle is minor.

## Transversus thoracis muscle  `muscle.transversus_thoracis`
*reviewed · confidence medium* · **not a movement muscle**

- (no actions)

> This small expiratory muscle depresses the costal cartilages. It has no meaningful joint action or established trunk-bracing role, unlike its continuation, the transversus abdominis.
