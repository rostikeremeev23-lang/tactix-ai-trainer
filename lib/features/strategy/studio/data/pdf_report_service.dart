import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/engine.dart';
import '../domain/scenario.dart';

/// Offline PDF built only from deterministic local exercise data.
class PdfReportService {
  Future<Uint8List> createExerciseReport(ExerciseEngine engine) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Variable.ttf');
    final font = pw.Font.ttf(fontData);
    final scenario = engine.scenario;
    final frame = engine.current;
    final pdf = pw.Document(title: 'TACTIX — ${scenario.name}', author: 'TACTIX NEO');
    const ink = PdfColor.fromInt(0xFF172331);
    const muted = PdfColor.fromInt(0xFF596B79);
    const cyan = PdfColor.fromInt(0xFF1687B4);
    const gold = PdfColor.fromInt(0xFFA57E39);
    const pale = PdfColor.fromInt(0xFFF1F5F9);

    pw.Widget metric(String label, String value) => pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(color: pale, borderRadius: pw.BorderRadius.circular(7)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 17, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 3),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: muted)),
      ]),
    );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(38, 42, 38, 44),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 9),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cyan, width: 1.5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TACTIX NEO', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: ink, letterSpacing: 1.5)),
          pw.Text('ОБРАЗОВАТЕЛЬНЫЙ ОТЧЁТ', style: pw.TextStyle(font: font, fontSize: 8, color: muted, letterSpacing: 1)),
        ]),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 7),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFD7E0E7)))),
        child: pw.Text('TACTIX · ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: muted)),
      ),
      build: (_) => [
        pw.SizedBox(height: 14),
        pw.Text('РАЗБОР УЧЕБНОГО ЗАНЯТИЯ', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold, color: cyan, letterSpacing: 1.4)),
        pw.SizedBox(height: 8),
        pw.Text(scenario.name, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 7),
        pw.Text(scenario.briefing, style: pw.TextStyle(font: font, fontSize: 10, color: muted, lineSpacing: 3)),
        pw.SizedBox(height: 15),
        pw.Row(children: [
          pw.Expanded(child: metric('Учебный результат', '${engine.score} / 100')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: metric('Такты занятия', '${frame.tick} / ${scenario.duration}')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: metric('Seed сценария', '${scenario.seed}')),
        ]),
        pw.SizedBox(height: 17),
        pw.Text('ПОКАЗАТЕЛИ И ЦЕЛИ', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _bar(font, 'Безопасность · условная', frame.safety, cyan)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _bar(font, 'Согласованность · условная', frame.cohesion, gold)),
        ]),
        pw.SizedBox(height: 9),
        pw.Row(children: [
          pw.Expanded(child: _bar(font, 'Ресурсы', (frame.resources * 100 / scenario.resources).round(), muted)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: metric('Удержание целей', '${frame.holdTicks} / ${scenario.duration}')),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Правило: ${engine.objectiveRule} Условные игровые метрики не оценивают профессиональную пригодность.', style: pw.TextStyle(font: font, fontSize: 8, color: muted, lineSpacing: 2)),
        pw.SizedBox(height: 15),
        pw.Text('ЦЕЛИ СЦЕНАРИЯ', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 6),
        ...scenario.objects.where((o) => o.kind == ObjectKind.objective).map((o) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: frame.reached.contains(o.id) ? const PdfColor.fromInt(0xFF42BFA0) : gold, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text('${frame.reached.contains(o.id) ? 'Достигнута' : 'Не достигнута'} · ${o.name}', style: pw.TextStyle(font: font, fontSize: 9, color: ink))),
          ]),
        )),
        pw.SizedBox(height: 15),
        pw.Text('ХРОНОЛОГИЯ И РЕШЕНИЯ', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 7),
        ...frame.log.map((event) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          margin: const pw.EdgeInsets.only(bottom: 4),
          decoration: pw.BoxDecoration(color: pale, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(event, style: pw.TextStyle(font: font, fontSize: 8, color: ink, lineSpacing: 2)),
        )),
        pw.SizedBox(height: 10),
        pw.Text('ВОПРОСЫ ДЛЯ РЕФЛЕКСИИ', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 6),
        pw.Text(frame.cohesion < 90
          ? 'Какие решения снизили согласованность? Найдите их в журнале и сравните альтернативную попытку.'
          : 'Какие ресурсы помогли сохранить согласованность? Можно ли достичь целей с меньшим расходом?',
          style: pw.TextStyle(font: font, fontSize: 9, color: ink, lineSpacing: 2)),
        pw.SizedBox(height: 6),
        pw.Text('Как изменится результат при другом распределении жетонов? Сохраните тот же seed и проверьте одну гипотезу за попытку.', style: pw.TextStyle(font: font, fontSize: 9, color: ink, lineSpacing: 2)),
        pw.SizedBox(height: 12),
        pw.Text('Отчёт сформирован локальным детерминированным движком TACTIX. Внешний AI и подключение к сети не требуются.', style: pw.TextStyle(font: font, fontSize: 8, color: muted)),
      ],
    ));
    return pdf.save();
  }

  pw.Widget _bar(pw.Font font, String label, int value, PdfColor color) {
    final width = 210.0 * value.clamp(0, 100) / 100;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: const PdfColor.fromInt(0xFF596B79)))),
        pw.Text('$value%', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF172331))),
      ]),
      pw.SizedBox(height: 4),
      pw.Container(height: 6, width: 210, decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFD7E0E7), borderRadius: pw.BorderRadius.circular(3)), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Container(width: width, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3))))),
    ]);
  }
}
