# Leg (below the knee)

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (14 entries): accepted Claude (claude-opus-5-5) draft without line-by-line expert review, at the project owner's request; automated rule and whole-table sanity checks passed.

**Rule checks:** all passed

## Extensor digitorum longus  `muscle.extensor_digitorum_longus`
*reviewed · confidence high*

- toe_joints / extension: **1.00**
- ankle_joint / dorsiflexion: **0.50**
- subtalar_joint / eversion: **0.30**

> It is the prime extensor of the lateral four toes and a clear assistant to tibialis anterior in dorsiflexion. Its lateral tendon line gives a modest eversion moment.

## Extensor hallucis longus  `muscle.extensor_hallucis_longus`
*reviewed · confidence high*

- toe_joints / extension: **0.80**
- ankle_joint / dorsiflexion: **0.40**
- subtalar_joint / inversion: **0.10**

> It is the prime extensor of the hallux, weighted 0.8 because toe_joints is pooled with EDL covering four toes, and it assists dorsiflexion. Its inversion contribution is weak and depends on foot position.

## Fibularis brevis muscle  `muscle.fibularis_brevis`
*reviewed · confidence high*

- subtalar_joint / eversion: **0.90**
- ankle_joint / plantarflexion: **0.20**
- stabilizes ankle_stability: 0.60

> It is a major evertor alongside fibularis longus, and it has only a minor plantarflexion moment because it passes close behind the lateral malleolus. It is important for resisting inversion sprain in stance.

## Fibularis longus muscle  `muscle.fibularis_longus`
*reviewed · confidence high*

- subtalar_joint / eversion: **1.00**
- ankle_joint / plantarflexion: **0.20**
- stabilizes ankle_stability: 0.60
- stabilizes postural_sway_control: 0.30

> It is the prime evertor and a weak plantarflexor. It controls mediolateral ankle stability and sway in stance. It also depresses the first ray and supports the transverse arch, but the vocabulary has no action for this.

## Fibularis tertius muscle  `muscle.fibularis_tertius`
*reviewed · confidence medium*

- subtalar_joint / eversion: **0.30**
- ankle_joint / dorsiflexion: **0.20**

> It is a small, variably present slip of EDL that assists eversion and dorsiflexion. It is minor relative to the fibularis longus and brevis and to tibialis anterior.

## Flexor digitorum longus  `muscle.flexor_digitorum_longus`
*reviewed · confidence high*

- toe_joints / flexion: **1.00**
- subtalar_joint / inversion: **0.30**
- ankle_joint / plantarflexion: **0.20**
- stabilizes ankle_stability: 0.30

> It is the prime flexor of the lateral four toes. It assists inversion and contributes only minor plantarflexion compared with the triceps surae, and it helps support the medial arch in stance.

## Flexor hallucis longus  `muscle.flexor_hallucis_longus`
*reviewed · confidence high*

- toe_joints / flexion: **0.80**
- ankle_joint / plantarflexion: **0.20**
- subtalar_joint / inversion: **0.20**
- stabilizes ankle_stability: 0.30

> It is the prime flexor of the hallux, which is important in push-off, and is weighted 0.8 within the pooled toe_joints. It contributes minor plantarflexion and inversion and helps support the medial arch.

## Lateral head of gastrocnemius  `muscle.lateral_head_of_gastrocnemius`
*reviewed · confidence high*

- ankle_joint / plantarflexion: **0.70**
- knee_joint / flexion: **0.30**
- stabilizes postural_sway_control: 0.40
- stabilizes postural_stabilization: 0.30

> It is a major plantarflexor, smaller than the medial head, and its plantarflexion output falls as the knee flexes because the muscle is two-joint. It assists knee flexion, mainly when the ankle is dorsiflexed.

## Medial head of gastrocnemius  `muscle.medial_head_of_gastrocnemius`
*reviewed · confidence high*

- ankle_joint / plantarflexion: **0.80**
- knee_joint / flexion: **0.30**
- stabilizes postural_sway_control: 0.40
- stabilizes postural_stabilization: 0.30

> It is the larger gastrocnemius head and a major plantarflexor, most effective with the knee extended because it is two-joint. It assists knee flexion and contributes to standing sway control.

## Plantaris muscle  `muscle.plantaris`
*reviewed · confidence medium*

- ankle_joint / plantarflexion: **0.10**
- knee_joint / flexion: **0.10**

> It is a small, often absent muscle with a negligible cross-section. It gives only minor assistance to gastrocnemius in plantarflexion and knee flexion.

## Popliteus muscle  `muscle.popliteus`
*reviewed · confidence high*

- knee_joint / internal_rotation: **0.70**
- knee_joint / flexion: **0.20**
- stabilizes knee_joint_stability: 0.50

> It unlocks the extended knee by internally rotating the tibia, or laterally rotating the femur when the foot is fixed, and is a major internal rotator alongside the medial hamstrings. Its flexion contribution is weak, and it resists posterolateral tibial rotation and translation.

## Soleus muscle  `muscle.soleus`
*reviewed · confidence high*

- ankle_joint / plantarflexion: **1.00**
- subtalar_joint / inversion: **0.20**
- stabilizes postural_sway_control: 0.90
- stabilizes postural_stabilization: 0.80
- stabilizes ankle_stability: 0.50

> It is the prime plantarflexor, being single-joint and effective at any knee angle, and the main tonic antigravity muscle controlling forward sway in standing. Its insertion via the Achilles tendon gives slight inversion.

## Tibialis anterior muscle  `muscle.tibialis_anterior`
*reviewed · confidence high*

- ankle_joint / dorsiflexion: **1.00**
- subtalar_joint / inversion: **0.60**
- stabilizes postural_sway_control: 0.50
- stabilizes ankle_stability: 0.40

> It is the prime dorsiflexor and a clear inverter, second to tibialis posterior. It controls backward sway and stabilizes the ankle in stance.

## Tibialis posterior muscle  `muscle.tibialis_posterior`
*reviewed · confidence high*

- subtalar_joint / inversion: **1.00**
- ankle_joint / plantarflexion: **0.20**
- stabilizes ankle_stability: 0.70

> It is the prime inverter and a weak plantarflexor because its moment arm is small. It is the key dynamic support of the medial longitudinal arch and controls pronation under load.
