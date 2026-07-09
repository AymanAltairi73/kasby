enum KycSelfieAngle {
  front,
  right,
  left;

  static const List<KycSelfieAngle> ordered = [front, right, left];

  int get stepIndex => ordered.indexOf(this) + 1;

  String get documentType => switch (this) {
        KycSelfieAngle.front => 'selfie_front',
        KycSelfieAngle.right => 'selfie_right',
        KycSelfieAngle.left => 'selfie_left',
      };

  String get titleKey => switch (this) {
        KycSelfieAngle.front => 'kyc_selfie_step_front',
        KycSelfieAngle.right => 'kyc_selfie_step_right',
        KycSelfieAngle.left => 'kyc_selfie_step_left',
      };

  String get instructionKey => switch (this) {
        KycSelfieAngle.front => 'kyc_selfie_place_face',
        KycSelfieAngle.right => 'kyc_face_turn_right',
        KycSelfieAngle.left => 'kyc_face_turn_left',
      };

  double get targetYaw => switch (this) {
        KycSelfieAngle.front => 0,
        KycSelfieAngle.right => 22,
        KycSelfieAngle.left => -22,
      };

  double get yawTolerance => switch (this) {
        KycSelfieAngle.front => 16,
        KycSelfieAngle.right => 14,
        KycSelfieAngle.left => 14,
      };

  double get maxRoll => 18;
}
