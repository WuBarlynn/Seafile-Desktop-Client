import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/format.dart';

void main() {
  test('normalizes repository paths', () {
    expect(normalizeRepoPath('folder/file.sdoc'), '/folder/file.sdoc');
    expect(normalizeRepoPath('//folder//file.sdoc/'), '/folder/file.sdoc');
    expect(normalizeRepoPath('folder/../file.sdoc'), '/file.sdoc');
  });

  test('decodes percent-encoded repository paths only when needed', () {
    expect(decodeRepoPath('/Seafile%20support/%E4%B8%AD%E6%96%87.sdoc'), '/Seafile support/中文.sdoc');
    expect(decodeRepoPath('/plain/file.sdoc'), '/plain/file.sdoc');
    expect(decodeRepoPath('/literal/%2.sdoc'), '/literal/%2.sdoc');
  });
}
