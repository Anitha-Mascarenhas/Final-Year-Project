// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'PoshanEye';

  @override
  String get welcomeTitle => 'स्वागत है';

  @override
  String get welcomeSubtitle =>
      'अपनी भूमिका चुनें और बच्चे के हर पड़ाव पर नज़र रखें।';

  @override
  String get whoAreYou => 'आप कौन हैं?';

  @override
  String get roleParentTitle => 'अभिभावक';

  @override
  String get roleParentDesc => 'अपने बच्चे के विकास और पोषण की देखभाल करें';

  @override
  String get roleHealthcareTitle => 'स्वास्थ्य कार्यकर्ता';

  @override
  String get roleHealthcareDesc =>
      'बच्चे के स्वास्थ्य रिकॉर्ड की निगरानी और प्रबंधन करें';

  @override
  String get backToRoles => 'भूमिका चयन पर लौटें';

  @override
  String get authChoiceSubtitle =>
      'अपने पोषणआई खाते के साथ आगे बढ़ने का तरीका चुनें।';

  @override
  String get signInTitle => 'साइन इन करें';

  @override
  String get signInDesc => 'मौजूदा खाता लॉगिन';

  @override
  String get createAccountTitle => 'खाता बनाएं';

  @override
  String get createAccountDesc => 'नया खाता पंजीकृत करें';

  @override
  String get welcomeBack => 'पुनः स्वागत है';

  @override
  String get clinicalSignIn => 'क्लिनिकल साइन इन';

  @override
  String get parentSignInSubtitle =>
      'विकास की स्थिति और पोषण विवरण देखने के लिए साइन इन करें।';

  @override
  String get healthcareSignInSubtitle =>
      'रोगी और बच्चे के स्वास्थ्य रिकॉर्ड देखने के लिए साइन इन करें।';

  @override
  String get childIdLabel => 'चाइल्ड आईडी';

  @override
  String get hospitalIdLabel => 'अस्पताल आईडी';

  @override
  String get childIdHint => 'जैसे PE-1048';

  @override
  String get hospitalIdHint => 'जैसे HID-2341';

  @override
  String get passwordLabel => 'पासवर्ड';

  @override
  String get passwordHint => 'पासवर्ड दर्ज करें';

  @override
  String get continueButton => 'आगे बढ़ें';

  @override
  String get backButton => 'पीछे जाएं';

  @override
  String get joinClinician => 'क्लिनिशियन से जुड़ें';

  @override
  String get parentSignUpSubtitle =>
      'अपना परिवार खाता बनाएं और बच्चे के विकास को ट्रैक करें।';

  @override
  String get healthcareSignUpSubtitle =>
      'स्वास्थ्य निगरानी के लिए सुरक्षित कार्यक्षेत्र बनाएं।';

  @override
  String get childNameLabel => 'बच्चे का नाम';

  @override
  String get childNameHint => 'आरव';

  @override
  String get dobLabel => 'जन्म तिथि';

  @override
  String get dobHint => 'दिन-महीना-वर्ष';

  @override
  String get emailLabel => 'ईमेल';

  @override
  String get emailHint => 'hello@poshaneye.com';

  @override
  String get nameLabel => 'नाम';

  @override
  String get doctorNameHint => 'डॉ. प्रिया नायर';

  @override
  String get doctorEmailHint => 'doctor@hospital.org';

  @override
  String get confirmPasswordLabel => 'पासवर्ड की पुष्टि करें';

  @override
  String get confirmPasswordHint => 'पासवर्ड दोबारा लिखें';

  @override
  String get passwordMinHint => 'न्यूनतम 8 अक्षर';

  @override
  String get createAccountButton => 'खाता बनाएं';

  @override
  String get errorEnterIdPassword =>
      'आगे बढ़ने के लिए चाइल्ड आईडी और पासवर्ड दर्ज करें।';

  @override
  String get errorIncorrectIdPassword => 'गलत चाइल्ड आईडी या पासवर्ड।';

  @override
  String get navHome => 'मुख्य पृष्ठ';

  @override
  String get navGrowth => 'विकास';

  @override
  String get navScan => 'स्कैन';

  @override
  String get navNutrition => 'पोषण';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get goodMorning => 'शुभ प्रभात';

  @override
  String get goodAfternoon => 'शुभ दोपहर';

  @override
  String get goodEvening => 'शुभ संध्या';

  @override
  String doingWellSubtitle(String childName) {
    return '$childName आज स्वस्थ और ठीक है।';
  }

  @override
  String get currentVitals => 'वर्तमान शारीरिक माप';

  @override
  String get updatedDaysAgo => '2 दिन पहले अपडेट किया गया';

  @override
  String get weightLabel => 'वजन';

  @override
  String get heightLabel => 'ऊंचाई';

  @override
  String get muacLabel => 'MUAC';

  @override
  String get bmiLabel => 'BMI';

  @override
  String get ageLabel => 'आयु';

  @override
  String get genderLabel => 'लिंग';

  @override
  String get statusLabel => 'स्थिति';

  @override
  String get growthStatusHeader => 'विकास की स्थिति';

  @override
  String get normalGrowthTitle => 'सामान्य विकास';

  @override
  String growthStatusDesc(String childName) {
    return '$childName WHO मानकों के अनुसार अपनी आयु वर्ग के स्वस्थ प्रतिशत में है।';
  }

  @override
  String get viewGrowthDetails => 'विकास विवरण देखें →';

  @override
  String get nutritionMilestonesHeader => 'पोषण के पड़ाव';

  @override
  String get optimalNutritionTitle => 'उत्कृष्ट पोषण';

  @override
  String get nutritionMilestonesDesc =>
      'विश्लेषण से पर्याप्त प्रोटीन और संतुलित सूक्ष्म पोषक तत्वों का संकेत मिलता है।';

  @override
  String get viewNutritionPlan => 'पोषण योजना देखें →';

  @override
  String get startNewScan => 'नया स्कैन शुरू करें';

  @override
  String get nutritionPlanBtn => 'पोषण योजना';

  @override
  String get childProfileTitle => 'बच्चे की प्रोफ़ाइल';

  @override
  String get childHistoryTitle => 'बच्चे का इतिहास';

  @override
  String profileHeader(String childName) {
    return '$childName की\nप्रोफ़ाइल';
  }

  @override
  String get secChildProfile => '01 बच्चे की प्रोफ़ाइल';

  @override
  String get secParentAccount => '02 अभिभावक / खाता';

  @override
  String get secPreferences => '03 प्राथमिकताएं';

  @override
  String get secSupport => '04 सहायता';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get noPhoto => 'कोई फोटो नहीं';

  @override
  String get onTrack => 'सही राह पर';

  @override
  String get healthy => 'स्वस्थ';

  @override
  String get premiumAccount => 'प्रीमियम खाता';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get appSettings => 'ऐप सेटिंग';

  @override
  String get manageProfiles => 'प्रोफ़ाइल प्रबंधित करें';

  @override
  String get helpCenter => 'सहायता केंद्र';

  @override
  String get privacySecurity => 'गोपनीयता और सुरक्षा';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get languageLabel => 'भाषा';

  @override
  String get healthStatusPrefix => 'स्वास्थ्य स्थिति : ';

  @override
  String get clearRecordSubtitle =>
      'विकास, स्कैन और क्लिनिकल नोट्स का स्पष्ट रिकॉर्ड।';

  @override
  String get currentDetails => 'वर्तमान विवरण';

  @override
  String get previousScansRecords => 'पिछली जांच और रिकॉर्ड';

  @override
  String get loggedVitals => 'दर्ज शारीरिक माप';

  @override
  String get noVitalsYet => 'अभी तक कोई रिकॉर्ड दर्ज नहीं किया गया है।';

  @override
  String get doctorsPrescription => 'डॉक्टर की सलाह';

  @override
  String get continueCarePlan => 'वर्तमान देखभाल योजना जारी रखें';

  @override
  String get carePlanDesc =>
      'नियमित भोजन, पर्याप्त पानी और शारीरिक गतिविधियों का ध्यान रखें। अगली जांच में यह रिपोर्ट ज़रूर दिखाएं।';

  @override
  String get reviewNextVisit => '📄 अगली विजिट में समीक्षा करें';

  @override
  String get exportPdfReport => 'PDF रिपोर्ट डाउनलोड करें';

  @override
  String get pdfExportSuccess => 'PDF रिपोर्ट सफलतापूर्वक निर्यात की गई';

  @override
  String get editChildProfile => 'बच्चे की प्रोफ़ाइल संपादित करें';

  @override
  String get editParentAccount => 'अभिभावक खाता संपादित करें';

  @override
  String get growthStatusField => 'विकास स्थिति';

  @override
  String get parentNameField => 'अभिभावक का नाम';

  @override
  String get accountTypeField => 'खाते का प्रकार';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get saveChanges => 'बदलाव सहेजें';

  @override
  String get growthTrackingHeader => 'विकास ट्रैकिंग';

  @override
  String get whoGrowthStandards => 'WHO विकास मानक';

  @override
  String get growthTrackingSubtitle =>
      'WHO चार्ट के साथ वजन, ऊंचाई, MUAC और Z-स्कोर ट्रैक करें।';

  @override
  String get tabWhoGrowthCurve => 'WHO विकास वक्र';

  @override
  String get tabVitalsCalculator => 'माप कैलकुलेटर';

  @override
  String get healthStatusOnTrack => 'स्वास्थ्य स्थिति: उत्तम';

  @override
  String get normalAnthropometric => 'सामान्य शारीरिक माप';

  @override
  String get lastUpdatedToday => 'अंतिम अपडेट: आज';

  @override
  String get zScoreWeightHeight => 'Z-स्कोर: ऊंचाई के अनुसार वजन';

  @override
  String get zScoreHeightAge => 'Z-स्कोर: आयु के अनुसार ऊंचाई';

  @override
  String get normalSdRange => '+1 SD से -1 SD के बीच (सामान्य)';

  @override
  String get heightForAge => 'आयु अनुसार ऊंचाई';

  @override
  String get weightForAge => 'आयु अनुसार वजन';

  @override
  String get weightForHeight => 'ऊंचाई अनुसार वजन';

  @override
  String get bmiForAge => 'आयु अनुसार BMI';

  @override
  String get childValueLegend => 'बच्चे का माप';

  @override
  String get medianLegend => 'माध्य (50वां)';

  @override
  String get whoBoundsLegend => 'WHO सीमा (±2 SD)';

  @override
  String get growthCurveNote =>
      'विकास वक्र डेटा माध्य के साथ निरंतर प्रगति दर्शाता है।';

  @override
  String get logNewMeasurement => 'नया माप दर्ज करें';

  @override
  String get logMeasurementDesc =>
      'चार्ट अपडेट करने के लिए ऊंचाई, वजन और MUAC दर्ज करें';

  @override
  String get enterWeight => 'वजन दर्ज करें (किग्रा)';

  @override
  String get enterHeight => 'ऊंचाई दर्ज करें (सेमी)';

  @override
  String get enterMuac => 'MUAC दर्ज करें (सेमी)';

  @override
  String get saveMeasurement => 'माप सहेजें';

  @override
  String get measurementSaved => 'माप सफलतापूर्वक दर्ज किया गया!';

  @override
  String get vitalsCalcTitle => 'बाल शारीरिक माप कैलकुलेटर';

  @override
  String get vitalsCalcSubtitle =>
      'Z-स्कोर, BMI और WHO पोषण वर्गीकरण की गणना के लिए माप दर्ज करें।';

  @override
  String get ageMonthsLabel => 'आयु (महीने)';

  @override
  String get genderBoy => 'लड़का';

  @override
  String get genderGirl => 'लड़की';

  @override
  String get calculateZScores => 'Z-स्कोर की गणना करें';

  @override
  String get resultsClassification => 'परिणाम और वर्गीकरण';

  @override
  String get stuntingStatus => 'स्टंटिंग स्थिति (ऊंचाई की कमी)';

  @override
  String get wastingStatus => 'वेस्टिंग स्थिति (वजन की कमी)';

  @override
  String get underweightStatus => 'कम वजन की स्थिति';

  @override
  String get nutritionPlanTitle => 'पोषण योजना';

  @override
  String get tailoredCarePlans => 'विशेष देखभाल और आहार योजना';

  @override
  String get nutritionPlanSubtitle =>
      'बच्चे के विकास चरण के अनुसार अनुशंसित पोषण आहार।';

  @override
  String get dailyTarget => 'दैनिक पोषण लक्ष्य';

  @override
  String get balancedDietPlan => 'संतुलित आहार योजना';

  @override
  String get calories => 'कैलोरी';

  @override
  String get protein => 'प्रोटीन';

  @override
  String get iron => 'आयरन';

  @override
  String get vitaminA => 'विटामिन A';

  @override
  String get mealSchedule => 'भोजन की समय-सारणी';

  @override
  String get breakfast => 'नाश्ता';

  @override
  String get midMorningSnack => 'सुबह का अल्पाहार';

  @override
  String get lunch => 'दोपहर का खाना';

  @override
  String get afternoonSnack => 'दोपहर बाद का नाश्ता';

  @override
  String get eveningSnack => 'शाम का नाश्ता';

  @override
  String get dinner => 'रात का खाना';

  @override
  String get keyNutrients => 'प्रमुख पोषक तत्व और आहार';

  @override
  String get keyNutrientsDesc =>
      'आयरन, कैल्शियम, जिंक और विटामिन से भरपूर भोजन';

  @override
  String get parentingTips => 'स्वस्थ खान-पान के लिए उपयोगी सुझाव';

  @override
  String childNutritionPlanTitle(String childName) {
    return '$childName की पोषण योजना';
  }

  @override
  String get nourishingMealGuide => 'आज के लिए तैयार पोषक भोजन मार्गदर्शिका।';

  @override
  String get readMore => 'और पढ़ें';

  @override
  String get readLess => 'कम पढ़ें';

  @override
  String get swapOption => 'विकल्प बदलें';

  @override
  String get swapping => 'बदला जा रहा है...';

  @override
  String get aiScannerHeader => 'AI स्कैनर';

  @override
  String get cameraAssessment => '3D कैमरा मूल्यांकन';

  @override
  String get aiScanSubtitle =>
      'AI द्वारा शारीरिक माप के अनुमान के लिए सामने, बगल और हाथ की फोटो लें।';

  @override
  String get step1Frontal => 'चरण 1: सामने की फोटो';

  @override
  String get step2Lateral => 'चरण 2: बगल की फोटो';

  @override
  String get step3Arm => 'चरण 3: हाथ / MUAC माप';

  @override
  String get scanInstruction1 =>
      'सुनिश्चित करें कि पर्याप्त रोशनी हो और बच्चा सीधा खड़ा हो।';

  @override
  String get scanInstruction2 =>
      'कैमरा कमर की ऊंचाई पर रखें और फ्रेम में मिलाएं।';

  @override
  String get scanInstruction3 => 'फोटो खींचते समय स्थिर रहें।';

  @override
  String get takePhotoButton => 'फोटो खींचें';

  @override
  String get retakeButton => 'दोबारा लें';

  @override
  String get confirmProceed => 'पुष्टि करें और आगे बढ़ें';

  @override
  String get uploadImage => 'इमेज अपलोड करें';

  @override
  String get analyzingImage => 'AI मॉडल द्वारा विश्लेषण जारी है...';

  @override
  String get detectingLandmarks => 'शरीर के बिंदुओं की पहचान की जा रही है...';

  @override
  String get calculatingEstimates => 'शारीरिक माप का अनुमान लगाया जा रहा है...';

  @override
  String get aiAssessmentSummary => 'AI मूल्यांकन सारांश';

  @override
  String get estimatedWeight => 'अनुमानित वजन';

  @override
  String get estimatedHeight => 'अनुमानित ऊंचाई';

  @override
  String get estimatedMuac => 'अनुमानित MUAC';

  @override
  String get estimatedBmi => 'अनुमानित BMI';

  @override
  String get confidenceScore => 'सटीकता स्कोर';

  @override
  String get riskLevel => 'जोखिम स्तर';

  @override
  String get riskLow => 'कम जोखिम / सामान्य';

  @override
  String get recommendations => 'सुझाव';

  @override
  String get saveToRecords => 'बच्चे के रिकॉर्ड में सहेजें';

  @override
  String get rescan => 'पुनः स्कैन करें';

  @override
  String get langEnglish => 'English';

  @override
  String get langHindi => 'हिन्दी';

  @override
  String get langKannada => 'ಕನ್ನಡ';

  @override
  String get scanUploadImage => 'अपलोड / फोटो लें';

  @override
  String get scanCapturePhoto => 'फोटो खींचें';

  @override
  String get scanProcessing => 'प्रसंस्करण हो रहा है...';

  @override
  String get scanAnalyzing => 'AI द्वारा विश्लेषण...';

  @override
  String get scanNewScan => 'नया स्कैन';

  @override
  String get scanViewResults => 'परिणाम देखें';

  @override
  String get scanPhotoConfirm => 'फोटो की पुष्टि करें';

  @override
  String get scanPhotoRetake => 'दोबारा लें';

  @override
  String scanStep(int step, int total) {
    return 'चरण $step / $total';
  }

  @override
  String get soundsEnabled => 'ध्वनि चालू';

  @override
  String get soundsDisabled => 'ध्वनि बंद';

  @override
  String get close => 'बंद करें';

  @override
  String get next => 'आगे';

  @override
  String get done => 'हो गया';
}
