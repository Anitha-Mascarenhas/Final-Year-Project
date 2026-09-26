// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PoshanEye';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeSubtitle =>
      'Continue with the role that matches your journey and keep every child milestone in view.';

  @override
  String get whoAreYou => 'Who are you?';

  @override
  String get roleParentTitle => 'Parent';

  @override
  String get roleParentDesc => 'Manage your child\'s growth and nutrition';

  @override
  String get roleHealthcareTitle => 'Healthcare Worker';

  @override
  String get roleHealthcareDesc => 'Monitor and manage child health records';

  @override
  String get backToRoles => 'Back to roles';

  @override
  String get authChoiceSubtitle =>
      'Choose how you would like to continue with your PoshanEye account.';

  @override
  String get signInTitle => 'Sign In';

  @override
  String get signInDesc => 'Existing account login';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get createAccountDesc => 'Register new account';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get clinicalSignIn => 'Clinical Sign In';

  @override
  String get parentSignInSubtitle =>
      'Sign in to view growth insights & nutrition status.';

  @override
  String get healthcareSignInSubtitle =>
      'Sign in to access patient & child health records.';

  @override
  String get childIdLabel => 'CHILD ID';

  @override
  String get hospitalIdLabel => 'HOSPITAL ID';

  @override
  String get childIdHint => 'e.g. PE-1048';

  @override
  String get hospitalIdHint => 'e.g. HID-2341';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get passwordHint => 'Enter password';

  @override
  String get continueButton => 'Continue';

  @override
  String get backButton => 'Back';

  @override
  String get joinClinician => 'Join Clinician';

  @override
  String get parentSignUpSubtitle =>
      'Set up your family account and track child growth.';

  @override
  String get healthcareSignUpSubtitle =>
      'Create a protected workspace for clinical monitoring.';

  @override
  String get childNameLabel => 'CHILD NAME';

  @override
  String get childNameHint => 'Aarav';

  @override
  String get dobLabel => 'DATE OF BIRTH';

  @override
  String get dobHint => 'dd-mm-yyyy';

  @override
  String get emailLabel => 'EMAIL';

  @override
  String get emailHint => 'hello@poshaneye.com';

  @override
  String get nameLabel => 'NAME';

  @override
  String get doctorNameHint => 'Dr. Priya Nair';

  @override
  String get doctorEmailHint => 'doctor@hospital.org';

  @override
  String get confirmPasswordLabel => 'CONFIRM PASSWORD';

  @override
  String get confirmPasswordHint => 'Repeat password';

  @override
  String get passwordMinHint => 'Min 8 characters';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get errorEnterIdPassword =>
      'Enter your child ID and password to continue.';

  @override
  String get errorIncorrectIdPassword => 'Incorrect child ID or password.';

  @override
  String get navHome => 'Home';

  @override
  String get navGrowth => 'Growth';

  @override
  String get navScan => 'Scan';

  @override
  String get navNutrition => 'Nutrition';

  @override
  String get navProfile => 'Profile';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String doingWellSubtitle(String childName) {
    return '$childName is doing well today.';
  }

  @override
  String get currentVitals => 'Current Vitals';

  @override
  String get updatedDaysAgo => 'Updated 2 days ago';

  @override
  String get weightLabel => 'Weight';

  @override
  String get heightLabel => 'Height';

  @override
  String get muacLabel => 'MUAC';

  @override
  String get bmiLabel => 'BMI';

  @override
  String get ageLabel => 'Age';

  @override
  String get genderLabel => 'Gender';

  @override
  String get statusLabel => 'Status';

  @override
  String get growthStatusHeader => 'GROWTH STATUS';

  @override
  String get normalGrowthTitle => 'Normal Growth';

  @override
  String growthStatusDesc(String childName) {
    return '$childName remains in the healthy percentile for their age group according to WHO standards.';
  }

  @override
  String get viewGrowthDetails => 'View growth details →';

  @override
  String get nutritionMilestonesHeader => 'NUTRITION MILESTONES';

  @override
  String get optimalNutritionTitle => 'Optimal Nutrition';

  @override
  String get nutritionMilestonesDesc =>
      'Analysis indicates optimal protein intake and balanced micro-nutrients.';

  @override
  String get viewNutritionPlan => 'View nutrition plan →';

  @override
  String get startNewScan => 'Start New Scan';

  @override
  String get nutritionPlanBtn => 'Nutrition Plan';

  @override
  String get childProfileTitle => 'Child Profile';

  @override
  String get childHistoryTitle => 'Child History';

  @override
  String profileHeader(String childName) {
    return '$childName\'S\nPROFILE';
  }

  @override
  String get secChildProfile => '01 CHILD PROFILE';

  @override
  String get secParentAccount => '02 PARENT / ACCOUNT';

  @override
  String get secPreferences => '03 PREFERENCES';

  @override
  String get secSupport => '04 SUPPORT';

  @override
  String get signOut => 'Sign Out';

  @override
  String get noPhoto => 'NO PHOTO';

  @override
  String get onTrack => 'On Track';

  @override
  String get healthy => 'Healthy';

  @override
  String get premiumAccount => 'Premium Account';

  @override
  String get notifications => 'Notifications';

  @override
  String get appSettings => 'App Settings';

  @override
  String get manageProfiles => 'Manage Profiles';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get privacySecurity => 'Privacy & Security';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get languageLabel => 'Language';

  @override
  String get healthStatusPrefix => 'Health status : ';

  @override
  String get clearRecordSubtitle =>
      'A clear record of growth, scans, and clinical notes.';

  @override
  String get currentDetails => 'CURRENT DETAILS';

  @override
  String get previousScansRecords => 'PREVIOUS SCANS & RECORDS';

  @override
  String get loggedVitals => 'LOGGED VITALS';

  @override
  String get noVitalsYet => 'No vitals records logged yet.';

  @override
  String get doctorsPrescription => 'DOCTOR\'S PRESCRIPTION';

  @override
  String get continueCarePlan => 'Continue the current care plan';

  @override
  String get carePlanDesc =>
      'Keep regular meals, hydration, and outdoor play consistent. Bring this record to the next pediatric review.';

  @override
  String get reviewNextVisit => '📄 REVIEW AT NEXT VISIT';

  @override
  String get exportPdfReport => 'Export PDF report';

  @override
  String get pdfExportSuccess => 'PDF Report exported successfully';

  @override
  String get editChildProfile => 'Edit child profile';

  @override
  String get editParentAccount => 'Edit parent account';

  @override
  String get growthStatusField => 'Growth status';

  @override
  String get parentNameField => 'Parent name';

  @override
  String get accountTypeField => 'Account type';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get growthTrackingHeader => 'Growth Tracking';

  @override
  String get whoGrowthStandards => 'WHO Growth Standards';

  @override
  String get growthTrackingSubtitle =>
      'Track weight, height, MUAC, and Z-scores against WHO charts.';

  @override
  String get tabWhoGrowthCurve => 'WHO Growth Curve';

  @override
  String get tabVitalsCalculator => 'Vitals Calculator';

  @override
  String get healthStatusOnTrack => 'HEALTH STATUS: ON TRACK';

  @override
  String get normalAnthropometric => 'Normal Anthropometric Measurements';

  @override
  String get lastUpdatedToday => 'Last updated: Today';

  @override
  String get zScoreWeightHeight => 'Z-Score: Weight-for-Height';

  @override
  String get zScoreHeightAge => 'Z-Score: Height-for-Age';

  @override
  String get normalSdRange => 'Within +1 SD to -1 SD (Normal)';

  @override
  String get heightForAge => 'Height-for-Age';

  @override
  String get weightForAge => 'Weight-for-Age';

  @override
  String get weightForHeight => 'Weight-for-Height';

  @override
  String get bmiForAge => 'BMI-for-Age';

  @override
  String get childValueLegend => 'Child Value';

  @override
  String get medianLegend => 'Median (50th)';

  @override
  String get whoBoundsLegend => 'WHO Bounds (±2 SD)';

  @override
  String get growthCurveNote =>
      'Growth curve data shows consistent progress along the median.';

  @override
  String get logNewMeasurement => 'Log New Measurement';

  @override
  String get logMeasurementDesc =>
      'Record height, weight, and MUAC to update charts';

  @override
  String get enterWeight => 'Enter Weight (kg)';

  @override
  String get enterHeight => 'Enter Height (cm)';

  @override
  String get enterMuac => 'Enter MUAC (cm)';

  @override
  String get saveMeasurement => 'Save Measurement';

  @override
  String get measurementSaved => 'Measurement recorded successfully!';

  @override
  String get vitalsCalcTitle => 'Child Anthropometry Calculator';

  @override
  String get vitalsCalcSubtitle =>
      'Enter measurements to calculate Z-scores, BMI, and WHO nutrition classification.';

  @override
  String get ageMonthsLabel => 'Age (months)';

  @override
  String get genderBoy => 'Boy';

  @override
  String get genderGirl => 'Girl';

  @override
  String get calculateZScores => 'Calculate Z-Scores';

  @override
  String get resultsClassification => 'Results & Classification';

  @override
  String get stuntingStatus => 'Stunting Status';

  @override
  String get wastingStatus => 'Wasting Status';

  @override
  String get underweightStatus => 'Underweight Status';

  @override
  String get nutritionPlanTitle => 'Nutrition Plan';

  @override
  String get tailoredCarePlans => 'Tailored Care & Meal Plans';

  @override
  String get nutritionPlanSubtitle =>
      'Nutritional recommendations optimized for child growth stage.';

  @override
  String get dailyTarget => 'DAILY NUTRITION TARGET';

  @override
  String get balancedDietPlan => 'Balanced Diet Plan';

  @override
  String get calories => 'Calories';

  @override
  String get protein => 'Protein';

  @override
  String get iron => 'Iron';

  @override
  String get vitaminA => 'Vitamin A';

  @override
  String get mealSchedule => 'Meal Schedule';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get midMorningSnack => 'Mid-Morning Snack';

  @override
  String get lunch => 'Lunch';

  @override
  String get afternoonSnack => 'Afternoon Snack';

  @override
  String get eveningSnack => 'Evening Snack';

  @override
  String get dinner => 'Dinner';

  @override
  String get keyNutrients => 'Key Nutrients & Foods';

  @override
  String get keyNutrientsDesc => 'Foods rich in Iron, Calcium, Zinc & Vitamins';

  @override
  String get parentingTips => 'Parenting Tips for Healthy Eating';

  @override
  String childNutritionPlanTitle(String childName) {
    return '$childName\'s Nutrition Plan';
  }

  @override
  String get nourishingMealGuide => 'Nourishing meal guide tailored for today.';

  @override
  String get readMore => 'Read more';

  @override
  String get readLess => 'Read less';

  @override
  String get swapOption => 'Swap Option';

  @override
  String get swapping => 'Swapping...';

  @override
  String get aiScannerHeader => 'AI Scanner';

  @override
  String get cameraAssessment => '3D Camera Assessment';

  @override
  String get aiScanSubtitle =>
      'Capture front, side, and arm photos for AI-assisted anthropometric estimates.';

  @override
  String get step1Frontal => 'Step 1: Frontal Profile';

  @override
  String get step2Lateral => 'Step 2: Lateral Profile';

  @override
  String get step3Arm => 'Step 3: Arm / MUAC Measurement';

  @override
  String get scanInstruction1 =>
      'Ensure proper lighting and child is standing straight.';

  @override
  String get scanInstruction2 =>
      'Keep camera at waist level and align within frame.';

  @override
  String get scanInstruction3 => 'Hold still while capturing image.';

  @override
  String get takePhotoButton => 'Take Photo';

  @override
  String get retakeButton => 'Retake';

  @override
  String get confirmProceed => 'Confirm & Proceed';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get analyzingImage => 'Analyzing image with AI model...';

  @override
  String get detectingLandmarks => 'Detecting body landmarks...';

  @override
  String get calculatingEstimates => 'Calculating anthropometric estimates...';

  @override
  String get aiAssessmentSummary => 'AI Assessment Summary';

  @override
  String get estimatedWeight => 'Estimated Weight';

  @override
  String get estimatedHeight => 'Estimated Height';

  @override
  String get estimatedMuac => 'Estimated MUAC';

  @override
  String get estimatedBmi => 'Estimated BMI';

  @override
  String get confidenceScore => 'Confidence Score';

  @override
  String get riskLevel => 'Risk Level';

  @override
  String get riskLow => 'Low Risk / Normal';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get saveToRecords => 'Save to Child Records';

  @override
  String get rescan => 'Re-scan';

  @override
  String get langEnglish => 'English';

  @override
  String get langHindi => 'हिन्दी';

  @override
  String get langKannada => 'ಕನ್ನಡ';

  @override
  String get scanUploadImage => 'Upload / Take Photo';

  @override
  String get scanCapturePhoto => 'Capture Photo';

  @override
  String get scanProcessing => 'Processing...';

  @override
  String get scanAnalyzing => 'Analysing with AI...';

  @override
  String get scanNewScan => 'New Scan';

  @override
  String get scanViewResults => 'View Results';

  @override
  String get scanPhotoConfirm => 'Confirm Photo';

  @override
  String get scanPhotoRetake => 'Retake';

  @override
  String scanStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get soundsEnabled => 'Sounds Enabled';

  @override
  String get soundsDisabled => 'Sounds Disabled';

  @override
  String get close => 'Close';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';
}
