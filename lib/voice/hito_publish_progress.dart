class HitoPublishProgress {
  const HitoPublishProgress(this.stage, {this.fraction});
  final String stage;

  /// Actual bytes handed to the transport, not simulated server progress.
  final double? fraction;
}
