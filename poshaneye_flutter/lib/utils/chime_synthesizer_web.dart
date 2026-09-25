import 'dart:html' as html;
import 'package:flutter/foundation.dart';

void playMascotChime() {
  try {
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..innerHtml = '''
        (function() {
          try {
            const AudioCtxClass = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtxClass) return;
            const ctx = new AudioCtxClass();
            const notes = [523.25, 659.25, 783.99, 1046.50];
            const now = ctx.currentTime;
            notes.forEach((freq, i) => {
              const osc = ctx.createOscillator();
              const gain = ctx.createGain();
              osc.type = 'sine';
              osc.frequency.value = freq;
              const startTime = now + (i * 0.15);
              const stopTime = startTime + 0.6;
              gain.gain.setValueAtTime(0.2, startTime);
              gain.gain.exponentialRampToValueAtTime(0.001, stopTime);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start(startTime);
              osc.stop(stopTime);
            });
          } catch (err) {
            console.error('Audio chime JS error:', err);
          }
        })();
      ''';
    html.document.body?.children.add(script);
    script.remove();
  } catch (e) {
    debugPrint('Web audio chime synth error: $e');
  }
}
