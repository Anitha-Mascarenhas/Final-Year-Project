import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportHelper {
  static Future<void> generateAndExportReport({
    required String childId,
    required String childName,
    required String age,
    required String gender,
    required String guardianName,
    required String status,
    required String height,
    required String weight,
    required String muac,
    required String bmiOrZScore,
    required String lastScreened,
  }) async {
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F3827'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'POSHANEYE CLINICAL HEALTH PORTAL',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Child Growth & Malnutrition Screening Report',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#2AE196'),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'HEALTH WORKER ID: HW001',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Patient Information Section
                pw.Text(
                  'PATIENT DEMOGRAPHICS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F3827'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#E2ECE2')),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Child ID: $childId',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Full Name: $childName',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Gender: $gender'),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Age: $age'),
                          pw.Text('Guardian: $guardianName'),
                          pw.Text('Assessment Date: $lastScreened'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Clinical Assessment Status
                pw.Text(
                  'CLINICAL MALNUTRITION STATUS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F3827'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EAF1E9'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Evaluated Status:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        status,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F3827'),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Anthropometric Vitals Table
                pw.Text(
                  'ANTHROPOMETRIC MEASUREMENTS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F3827'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: [
                    'Parameter',
                    'Measured Value',
                    'WHO Benchmark Range'
                  ],
                  data: [
                    ['Height', height, '85.0 - 95.0 cm'],
                    ['Weight', weight, '11.0 - 15.0 kg'],
                    ['MUAC', muac, '> 12.5 cm (Normal)'],
                    ['WHO Z-Score / BMI', bmiOrZScore, '-2.0 to +2.0 SD'],
                  ],
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#0F3827')),
                  rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellPadding: const pw.EdgeInsets.all(8),
                ),
                pw.SizedBox(height: 30),

                // Signatures & Stamp Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Attending Clinician:'),
                        pw.SizedBox(height: 4),
                        pw.Text('Dr. Priya Nair',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Senior Pediatric Nutritionist'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Clinical Verification Seal'),
                        pw.SizedBox(height: 4),
                        pw.Text('PoshanEye AI Diagnostics',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('St. Jude Medical Center'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'PoshanEye_Report_${childId}_$childName.pdf',
    );
  }
}
