/// Central switch documenting *why* OTP is simulated.
///
/// Firebase Phone Auth requires a Blaze (pay-as-you-go) plan with a linked
/// billing account, even for a single test SMS (Google reCAPTCHA Enterprise
/// requirement, effective Sept 2024). This project currently runs on the
/// Spark (free) plan, so real SMS delivery is not available.
///
/// While kOtpDemoMode is true, OTPs are generated for real, stored with a
/// real expiry, and "delivered" via an in-app banner instead of SMS.
/// To go to production: set this to false and route sendOtp/verifyOtp
/// through FirebaseAuth.verifyPhoneNumber (see FirebaseAuthService).
const bool kOtpDemoMode = true;

const int kOtpLength = 6;
const Duration kOtpValidity = Duration(minutes: 5);
const Duration kOtpResendCooldown = Duration(seconds: 60);
const int kOtpMaxAttempts = 5;