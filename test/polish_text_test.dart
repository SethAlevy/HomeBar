import 'package:flutter_test/flutter_test.dart';

import 'package:homebar/utils/polish_text.dart';

void main() {
  test('strips every Polish diacritic to its plain-ASCII letter', () {
    expect(stripPolishDiacritics('pomarańczowy'), 'pomaranczowy');
    expect(stripPolishDiacritics('wyśmienity'), 'wysmienity');
    expect(stripPolishDiacritics('łagodny'), 'lagodny');
    expect(stripPolishDiacritics('gorączka'), 'goraczka');
    expect(stripPolishDiacritics('źdźbło'), 'zdzblo');
    expect(stripPolishDiacritics('ŻÓŁĆ'), 'ZOLC');
  });

  test('leaves plain ASCII text untouched', () {
    expect(stripPolishDiacritics('bourbon'), 'bourbon');
    expect(stripPolishDiacritics(''), '');
  });
}
