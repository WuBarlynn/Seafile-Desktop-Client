import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/format.dart';

void main() {
  test('natural sort orders numbered names correctly', () {
    final names = ['file10.txt', 'file2.txt', 'file1.txt'];
    names.sort(compareNatural);
    expect(names, ['file1.txt', 'file2.txt', 'file10.txt']);
  });

  test('repository paths normalize consistently', () {
    expect(normalizeRepoPath('/a//b/../c/'), '/a/c');
    expect(joinRepoPath('/', 'docs'), '/docs');
    expect(parentRepoPath('/a/b'), '/a');
  });
}
