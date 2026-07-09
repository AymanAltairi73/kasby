class KycSelfieCaptureResult {
  final String frontPath;
  final String rightPath;
  final String leftPath;
  final Map<String, dynamic> livenessMetadata;

  const KycSelfieCaptureResult({
    required this.frontPath,
    required this.rightPath,
    required this.leftPath,
    required this.livenessMetadata,
  });
}
