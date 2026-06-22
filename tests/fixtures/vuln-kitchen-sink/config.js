module.exports = {
  // Intentionally a real-looking literal value, not a placeholder, to test
  // secrets-hardcoded detection (and not process.env.PAYMENT_PROVIDER_KEY).
  // Deliberately NOT shaped like a real provider's key format (no sk_live_,
  // AKIA, ghp_, etc. prefix) so GitHub's own secret scanner doesn't flag this
  // fixture file as a real leaked credential when this repo is pushed.
  paymentProviderApiKey: "totally-fake-fixture-value-not-a-real-credential-001",
  appName: "kitchen-sink-fixture",
}
