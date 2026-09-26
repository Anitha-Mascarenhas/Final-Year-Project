import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PoshanEye'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with the role that matches your journey and keep every child milestone in view.'**
  String get welcomeSubtitle;

  /// No description provided for @whoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get whoAreYou;

  /// No description provided for @roleParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParentTitle;

  /// No description provided for @roleParentDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your child\'s growth and nutrition'**
  String get roleParentDesc;

  /// No description provided for @roleHealthcareTitle.
  ///
  /// In en, this message translates to:
  /// **'Healthcare Worker'**
  String get roleHealthcareTitle;

  /// No description provided for @roleHealthcareDesc.
  ///
  /// In en, this message translates to:
  /// **'Monitor and manage child health records'**
  String get roleHealthcareDesc;

  /// No description provided for @backToRoles.
  ///
  /// In en, this message translates to:
  /// **'Back to roles'**
  String get backToRoles;

  /// No description provided for @authChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you would like to continue with your PoshanEye account.'**
  String get authChoiceSubtitle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTitle;

  /// No description provided for @signInDesc.
  ///
  /// In en, this message translates to:
  /// **'Existing account login'**
  String get signInDesc;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @createAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Register new account'**
  String get createAccountDesc;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @clinicalSignIn.
  ///
  /// In en, this message translates to:
  /// **'Clinical Sign In'**
  String get clinicalSignIn;

  /// No description provided for @parentSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view growth insights & nutrition status.'**
  String get parentSignInSubtitle;

  /// No description provided for @healthcareSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access patient & child health records.'**
  String get healthcareSignInSubtitle;

  /// No description provided for @childIdLabel.
  ///
  /// In en, this message translates to:
  /// **'CHILD ID'**
  String get childIdLabel;

  /// No description provided for @hospitalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'HOSPITAL ID'**
  String get hospitalIdLabel;

  /// No description provided for @childIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. PE-1048'**
  String get childIdHint;

  /// No description provided for @hospitalIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. HID-2341'**
  String get hospitalIdHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get passwordHint;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @joinClinician.
  ///
  /// In en, this message translates to:
  /// **'Join Clinician'**
  String get joinClinician;

  /// No description provided for @parentSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your family account and track child growth.'**
  String get parentSignUpSubtitle;

  /// No description provided for @healthcareSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a protected workspace for clinical monitoring.'**
  String get healthcareSignUpSubtitle;

  /// No description provided for @childNameLabel.
  ///
  /// In en, this message translates to:
  /// **'CHILD NAME'**
  String get childNameLabel;

  /// No description provided for @childNameHint.
  ///
  /// In en, this message translates to:
  /// **'Aarav'**
  String get childNameHint;

  /// No description provided for @dobLabel.
  ///
  /// In en, this message translates to:
  /// **'DATE OF BIRTH'**
  String get dobLabel;

  /// No description provided for @dobHint.
  ///
  /// In en, this message translates to:
  /// **'dd-mm-yyyy'**
  String get dobHint;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'hello@poshaneye.com'**
  String get emailHint;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get nameLabel;

  /// No description provided for @doctorNameHint.
  ///
  /// In en, this message translates to:
  /// **'Dr. Priya Nair'**
  String get doctorNameHint;

  /// No description provided for @doctorEmailHint.
  ///
  /// In en, this message translates to:
  /// **'doctor@hospital.org'**
  String get doctorEmailHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get confirmPasswordHint;

  /// No description provided for @passwordMinHint.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get passwordMinHint;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @errorEnterIdPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your child ID and password to continue.'**
  String get errorEnterIdPassword;

  /// No description provided for @errorIncorrectIdPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect child ID or password.'**
  String get errorIncorrectIdPassword;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get navGrowth;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get navNutrition;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @doingWellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{childName} is doing well today.'**
  String doingWellSubtitle(String childName);

  /// No description provided for @currentVitals.
  ///
  /// In en, this message translates to:
  /// **'Current Vitals'**
  String get currentVitals;

  /// No description provided for @updatedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated 2 days ago'**
  String get updatedDaysAgo;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// No description provided for @muacLabel.
  ///
  /// In en, this message translates to:
  /// **'MUAC'**
  String get muacLabel;

  /// No description provided for @bmiLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmiLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @growthStatusHeader.
  ///
  /// In en, this message translates to:
  /// **'GROWTH STATUS'**
  String get growthStatusHeader;

  /// No description provided for @normalGrowthTitle.
  ///
  /// In en, this message translates to:
  /// **'Normal Growth'**
  String get normalGrowthTitle;

  /// No description provided for @growthStatusDesc.
  ///
  /// In en, this message translates to:
  /// **'{childName} remains in the healthy percentile for their age group according to WHO standards.'**
  String growthStatusDesc(String childName);

  /// No description provided for @viewGrowthDetails.
  ///
  /// In en, this message translates to:
  /// **'View growth details →'**
  String get viewGrowthDetails;

  /// No description provided for @nutritionMilestonesHeader.
  ///
  /// In en, this message translates to:
  /// **'NUTRITION MILESTONES'**
  String get nutritionMilestonesHeader;

  /// No description provided for @optimalNutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Optimal Nutrition'**
  String get optimalNutritionTitle;

  /// No description provided for @nutritionMilestonesDesc.
  ///
  /// In en, this message translates to:
  /// **'Analysis indicates optimal protein intake and balanced micro-nutrients.'**
  String get nutritionMilestonesDesc;

  /// No description provided for @viewNutritionPlan.
  ///
  /// In en, this message translates to:
  /// **'View nutrition plan →'**
  String get viewNutritionPlan;

  /// No description provided for @startNewScan.
  ///
  /// In en, this message translates to:
  /// **'Start New Scan'**
  String get startNewScan;

  /// No description provided for @nutritionPlanBtn.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Plan'**
  String get nutritionPlanBtn;

  /// No description provided for @childProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Profile'**
  String get childProfileTitle;

  /// No description provided for @childHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Child History'**
  String get childHistoryTitle;

  /// No description provided for @profileHeader.
  ///
  /// In en, this message translates to:
  /// **'{childName}\'S\nPROFILE'**
  String profileHeader(String childName);

  /// No description provided for @secChildProfile.
  ///
  /// In en, this message translates to:
  /// **'01 CHILD PROFILE'**
  String get secChildProfile;

  /// No description provided for @secParentAccount.
  ///
  /// In en, this message translates to:
  /// **'02 PARENT / ACCOUNT'**
  String get secParentAccount;

  /// No description provided for @secPreferences.
  ///
  /// In en, this message translates to:
  /// **'03 PREFERENCES'**
  String get secPreferences;

  /// No description provided for @secSupport.
  ///
  /// In en, this message translates to:
  /// **'04 SUPPORT'**
  String get secSupport;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @noPhoto.
  ///
  /// In en, this message translates to:
  /// **'NO PHOTO'**
  String get noPhoto;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get onTrack;

  /// No description provided for @healthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// No description provided for @premiumAccount.
  ///
  /// In en, this message translates to:
  /// **'Premium Account'**
  String get premiumAccount;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @manageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get manageProfiles;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @healthStatusPrefix.
  ///
  /// In en, this message translates to:
  /// **'Health status : '**
  String get healthStatusPrefix;

  /// No description provided for @clearRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear record of growth, scans, and clinical notes.'**
  String get clearRecordSubtitle;

  /// No description provided for @currentDetails.
  ///
  /// In en, this message translates to:
  /// **'CURRENT DETAILS'**
  String get currentDetails;

  /// No description provided for @previousScansRecords.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUS SCANS & RECORDS'**
  String get previousScansRecords;

  /// No description provided for @loggedVitals.
  ///
  /// In en, this message translates to:
  /// **'LOGGED VITALS'**
  String get loggedVitals;

  /// No description provided for @noVitalsYet.
  ///
  /// In en, this message translates to:
  /// **'No vitals records logged yet.'**
  String get noVitalsYet;

  /// No description provided for @doctorsPrescription.
  ///
  /// In en, this message translates to:
  /// **'DOCTOR\'S PRESCRIPTION'**
  String get doctorsPrescription;

  /// No description provided for @continueCarePlan.
  ///
  /// In en, this message translates to:
  /// **'Continue the current care plan'**
  String get continueCarePlan;

  /// No description provided for @carePlanDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep regular meals, hydration, and outdoor play consistent. Bring this record to the next pediatric review.'**
  String get carePlanDesc;

  /// No description provided for @reviewNextVisit.
  ///
  /// In en, this message translates to:
  /// **'📄 REVIEW AT NEXT VISIT'**
  String get reviewNextVisit;

  /// No description provided for @exportPdfReport.
  ///
  /// In en, this message translates to:
  /// **'Export PDF report'**
  String get exportPdfReport;

  /// No description provided for @pdfExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'PDF Report exported successfully'**
  String get pdfExportSuccess;

  /// No description provided for @editChildProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit child profile'**
  String get editChildProfile;

  /// No description provided for @editParentAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit parent account'**
  String get editParentAccount;

  /// No description provided for @growthStatusField.
  ///
  /// In en, this message translates to:
  /// **'Growth status'**
  String get growthStatusField;

  /// No description provided for @parentNameField.
  ///
  /// In en, this message translates to:
  /// **'Parent name'**
  String get parentNameField;

  /// No description provided for @accountTypeField.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountTypeField;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @growthTrackingHeader.
  ///
  /// In en, this message translates to:
  /// **'Growth Tracking'**
  String get growthTrackingHeader;

  /// No description provided for @whoGrowthStandards.
  ///
  /// In en, this message translates to:
  /// **'WHO Growth Standards'**
  String get whoGrowthStandards;

  /// No description provided for @growthTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track weight, height, MUAC, and Z-scores against WHO charts.'**
  String get growthTrackingSubtitle;

  /// No description provided for @tabWhoGrowthCurve.
  ///
  /// In en, this message translates to:
  /// **'WHO Growth Curve'**
  String get tabWhoGrowthCurve;

  /// No description provided for @tabVitalsCalculator.
  ///
  /// In en, this message translates to:
  /// **'Vitals Calculator'**
  String get tabVitalsCalculator;

  /// No description provided for @healthStatusOnTrack.
  ///
  /// In en, this message translates to:
  /// **'HEALTH STATUS: ON TRACK'**
  String get healthStatusOnTrack;

  /// No description provided for @normalAnthropometric.
  ///
  /// In en, this message translates to:
  /// **'Normal Anthropometric Measurements'**
  String get normalAnthropometric;

  /// No description provided for @lastUpdatedToday.
  ///
  /// In en, this message translates to:
  /// **'Last updated: Today'**
  String get lastUpdatedToday;

  /// No description provided for @zScoreWeightHeight.
  ///
  /// In en, this message translates to:
  /// **'Z-Score: Weight-for-Height'**
  String get zScoreWeightHeight;

  /// No description provided for @zScoreHeightAge.
  ///
  /// In en, this message translates to:
  /// **'Z-Score: Height-for-Age'**
  String get zScoreHeightAge;

  /// No description provided for @normalSdRange.
  ///
  /// In en, this message translates to:
  /// **'Within +1 SD to -1 SD (Normal)'**
  String get normalSdRange;

  /// No description provided for @heightForAge.
  ///
  /// In en, this message translates to:
  /// **'Height-for-Age'**
  String get heightForAge;

  /// No description provided for @weightForAge.
  ///
  /// In en, this message translates to:
  /// **'Weight-for-Age'**
  String get weightForAge;

  /// No description provided for @weightForHeight.
  ///
  /// In en, this message translates to:
  /// **'Weight-for-Height'**
  String get weightForHeight;

  /// No description provided for @bmiForAge.
  ///
  /// In en, this message translates to:
  /// **'BMI-for-Age'**
  String get bmiForAge;

  /// No description provided for @childValueLegend.
  ///
  /// In en, this message translates to:
  /// **'Child Value'**
  String get childValueLegend;

  /// No description provided for @medianLegend.
  ///
  /// In en, this message translates to:
  /// **'Median (50th)'**
  String get medianLegend;

  /// No description provided for @whoBoundsLegend.
  ///
  /// In en, this message translates to:
  /// **'WHO Bounds (±2 SD)'**
  String get whoBoundsLegend;

  /// No description provided for @growthCurveNote.
  ///
  /// In en, this message translates to:
  /// **'Growth curve data shows consistent progress along the median.'**
  String get growthCurveNote;

  /// No description provided for @logNewMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Log New Measurement'**
  String get logNewMeasurement;

  /// No description provided for @logMeasurementDesc.
  ///
  /// In en, this message translates to:
  /// **'Record height, weight, and MUAC to update charts'**
  String get logMeasurementDesc;

  /// No description provided for @enterWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter Weight (kg)'**
  String get enterWeight;

  /// No description provided for @enterHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter Height (cm)'**
  String get enterHeight;

  /// No description provided for @enterMuac.
  ///
  /// In en, this message translates to:
  /// **'Enter MUAC (cm)'**
  String get enterMuac;

  /// No description provided for @saveMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Save Measurement'**
  String get saveMeasurement;

  /// No description provided for @measurementSaved.
  ///
  /// In en, this message translates to:
  /// **'Measurement recorded successfully!'**
  String get measurementSaved;

  /// No description provided for @vitalsCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Anthropometry Calculator'**
  String get vitalsCalcTitle;

  /// No description provided for @vitalsCalcSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter measurements to calculate Z-scores, BMI, and WHO nutrition classification.'**
  String get vitalsCalcSubtitle;

  /// No description provided for @ageMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Age (months)'**
  String get ageMonthsLabel;

  /// No description provided for @genderBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get genderBoy;

  /// No description provided for @genderGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get genderGirl;

  /// No description provided for @calculateZScores.
  ///
  /// In en, this message translates to:
  /// **'Calculate Z-Scores'**
  String get calculateZScores;

  /// No description provided for @resultsClassification.
  ///
  /// In en, this message translates to:
  /// **'Results & Classification'**
  String get resultsClassification;

  /// No description provided for @stuntingStatus.
  ///
  /// In en, this message translates to:
  /// **'Stunting Status'**
  String get stuntingStatus;

  /// No description provided for @wastingStatus.
  ///
  /// In en, this message translates to:
  /// **'Wasting Status'**
  String get wastingStatus;

  /// No description provided for @underweightStatus.
  ///
  /// In en, this message translates to:
  /// **'Underweight Status'**
  String get underweightStatus;

  /// No description provided for @nutritionPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Plan'**
  String get nutritionPlanTitle;

  /// No description provided for @tailoredCarePlans.
  ///
  /// In en, this message translates to:
  /// **'Tailored Care & Meal Plans'**
  String get tailoredCarePlans;

  /// No description provided for @nutritionPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nutritional recommendations optimized for child growth stage.'**
  String get nutritionPlanSubtitle;

  /// No description provided for @dailyTarget.
  ///
  /// In en, this message translates to:
  /// **'DAILY NUTRITION TARGET'**
  String get dailyTarget;

  /// No description provided for @balancedDietPlan.
  ///
  /// In en, this message translates to:
  /// **'Balanced Diet Plan'**
  String get balancedDietPlan;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @iron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get iron;

  /// No description provided for @vitaminA.
  ///
  /// In en, this message translates to:
  /// **'Vitamin A'**
  String get vitaminA;

  /// No description provided for @mealSchedule.
  ///
  /// In en, this message translates to:
  /// **'Meal Schedule'**
  String get mealSchedule;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @midMorningSnack.
  ///
  /// In en, this message translates to:
  /// **'Mid-Morning Snack'**
  String get midMorningSnack;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @afternoonSnack.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Snack'**
  String get afternoonSnack;

  /// No description provided for @eveningSnack.
  ///
  /// In en, this message translates to:
  /// **'Evening Snack'**
  String get eveningSnack;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @keyNutrients.
  ///
  /// In en, this message translates to:
  /// **'Key Nutrients & Foods'**
  String get keyNutrients;

  /// No description provided for @keyNutrientsDesc.
  ///
  /// In en, this message translates to:
  /// **'Foods rich in Iron, Calcium, Zinc & Vitamins'**
  String get keyNutrientsDesc;

  /// No description provided for @parentingTips.
  ///
  /// In en, this message translates to:
  /// **'Parenting Tips for Healthy Eating'**
  String get parentingTips;

  /// No description provided for @childNutritionPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'{childName}\'s Nutrition Plan'**
  String childNutritionPlanTitle(String childName);

  /// No description provided for @nourishingMealGuide.
  ///
  /// In en, this message translates to:
  /// **'Nourishing meal guide tailored for today.'**
  String get nourishingMealGuide;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @readLess.
  ///
  /// In en, this message translates to:
  /// **'Read less'**
  String get readLess;

  /// No description provided for @swapOption.
  ///
  /// In en, this message translates to:
  /// **'Swap Option'**
  String get swapOption;

  /// No description provided for @swapping.
  ///
  /// In en, this message translates to:
  /// **'Swapping...'**
  String get swapping;

  /// No description provided for @aiScannerHeader.
  ///
  /// In en, this message translates to:
  /// **'AI Scanner'**
  String get aiScannerHeader;

  /// No description provided for @cameraAssessment.
  ///
  /// In en, this message translates to:
  /// **'3D Camera Assessment'**
  String get cameraAssessment;

  /// No description provided for @aiScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture front, side, and arm photos for AI-assisted anthropometric estimates.'**
  String get aiScanSubtitle;

  /// No description provided for @step1Frontal.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Frontal Profile'**
  String get step1Frontal;

  /// No description provided for @step2Lateral.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Lateral Profile'**
  String get step2Lateral;

  /// No description provided for @step3Arm.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Arm / MUAC Measurement'**
  String get step3Arm;

  /// No description provided for @scanInstruction1.
  ///
  /// In en, this message translates to:
  /// **'Ensure proper lighting and child is standing straight.'**
  String get scanInstruction1;

  /// No description provided for @scanInstruction2.
  ///
  /// In en, this message translates to:
  /// **'Keep camera at waist level and align within frame.'**
  String get scanInstruction2;

  /// No description provided for @scanInstruction3.
  ///
  /// In en, this message translates to:
  /// **'Hold still while capturing image.'**
  String get scanInstruction3;

  /// No description provided for @takePhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhotoButton;

  /// No description provided for @retakeButton.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakeButton;

  /// No description provided for @confirmProceed.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Proceed'**
  String get confirmProceed;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImage;

  /// No description provided for @analyzingImage.
  ///
  /// In en, this message translates to:
  /// **'Analyzing image with AI model...'**
  String get analyzingImage;

  /// No description provided for @detectingLandmarks.
  ///
  /// In en, this message translates to:
  /// **'Detecting body landmarks...'**
  String get detectingLandmarks;

  /// No description provided for @calculatingEstimates.
  ///
  /// In en, this message translates to:
  /// **'Calculating anthropometric estimates...'**
  String get calculatingEstimates;

  /// No description provided for @aiAssessmentSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Assessment Summary'**
  String get aiAssessmentSummary;

  /// No description provided for @estimatedWeight.
  ///
  /// In en, this message translates to:
  /// **'Estimated Weight'**
  String get estimatedWeight;

  /// No description provided for @estimatedHeight.
  ///
  /// In en, this message translates to:
  /// **'Estimated Height'**
  String get estimatedHeight;

  /// No description provided for @estimatedMuac.
  ///
  /// In en, this message translates to:
  /// **'Estimated MUAC'**
  String get estimatedMuac;

  /// No description provided for @estimatedBmi.
  ///
  /// In en, this message translates to:
  /// **'Estimated BMI'**
  String get estimatedBmi;

  /// No description provided for @confidenceScore.
  ///
  /// In en, this message translates to:
  /// **'Confidence Score'**
  String get confidenceScore;

  /// No description provided for @riskLevel.
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get riskLevel;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low Risk / Normal'**
  String get riskLow;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @saveToRecords.
  ///
  /// In en, this message translates to:
  /// **'Save to Child Records'**
  String get saveToRecords;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Re-scan'**
  String get rescan;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get langHindi;

  /// No description provided for @langKannada.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get langKannada;

  /// No description provided for @scanUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload / Take Photo'**
  String get scanUploadImage;

  /// No description provided for @scanCapturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture Photo'**
  String get scanCapturePhoto;

  /// No description provided for @scanProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get scanProcessing;

  /// No description provided for @scanAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analysing with AI...'**
  String get scanAnalyzing;

  /// No description provided for @scanNewScan.
  ///
  /// In en, this message translates to:
  /// **'New Scan'**
  String get scanNewScan;

  /// No description provided for @scanViewResults.
  ///
  /// In en, this message translates to:
  /// **'View Results'**
  String get scanViewResults;

  /// No description provided for @scanPhotoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Photo'**
  String get scanPhotoConfirm;

  /// No description provided for @scanPhotoRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get scanPhotoRetake;

  /// No description provided for @scanStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String scanStep(int step, int total);

  /// No description provided for @soundsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sounds Enabled'**
  String get soundsEnabled;

  /// No description provided for @soundsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sounds Disabled'**
  String get soundsDisabled;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'kn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
