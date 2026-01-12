// Phase 24.1: Unit Tests - Vietnamese Normalization
import 'package:flutter_test/flutter_test.dart';
import 'package:scandocpro/src/utils/vietnamese_normalization.dart';

void main() {
  group('removeDiacritics() - Basic Vietnamese', () {
    test('normalizes "Hoá đơn" to "hoa don"', () {
      expect(removeDiacritics('Hoá đơn'), 'hoa don');
    });

    test('normalizes "Điện thoại" to "dien thoai"', () {
      expect(removeDiacritics('Điện thoại'), 'dien thoai');
    });

    test('normalizes "Hợp đồng" to "hop dong"', () {
      expect(removeDiacritics('Hợp đồng'), 'hop dong');
    });

    test('normalizes "Công ty" to "cong ty"', () {
      expect(removeDiacritics('Công ty'), 'cong ty');
    });

    test('normalizes "Giấy phép" to "giay phep"', () {
      expect(removeDiacritics('Giấy phép'), 'giay phep');
    });
  });

  group('removeDiacritics() - Uppercase', () {
    test('normalizes uppercase "HOÁ ĐƠN" to "hoa don"', () {
      expect(removeDiacritics('HOÁ ĐƠN'), 'hoa don');
    });

    test('normalizes uppercase "ĐIỆN THOẠI" to "dien thoai"', () {
      expect(removeDiacritics('ĐIỆN THOẠI'), 'dien thoai');
    });

    test('normalizes mixed case "HỢP ĐỒNG" to "hop dong"', () {
      expect(removeDiacritics('HỢP ĐỒNG'), 'hop dong');
    });

    test('normalizes title case "Hoá Đơn" to "hoa don"', () {
      expect(removeDiacritics('Hoá Đơn'), 'hoa don');
    });
  });

  group('removeDiacritics() - English Preservation', () {
    test('preserves English "Invoice"', () {
      expect(removeDiacritics('Invoice'), 'invoice');
    });

    test('preserves English "Contract"', () {
      expect(removeDiacritics('Contract'), 'contract');
    });

    test('preserves English uppercase "INVOICE"', () {
      expect(removeDiacritics('INVOICE'), 'invoice');
    });
  });

  group('removeDiacritics() - Mixed Vietnamese + English', () {
    test('normalizes "Invoice Hoá đơn"', () {
      expect(removeDiacritics('Invoice Hoá đơn'), 'invoice hoa don');
    });

    test('normalizes "Contract Hợp đồng"', () {
      expect(removeDiacritics('Contract Hợp đồng'), 'contract hop dong');
    });

    test('normalizes "Công ty ABC"', () {
      expect(removeDiacritics('Công ty ABC'), 'cong ty abc');
    });
  });

  group('removeDiacritics() - Numbers & Symbols', () {
    test('preserves numbers "Hoá đơn 2024"', () {
      expect(removeDiacritics('Hoá đơn 2024'), 'hoa don 2024');
    });

    test('preserves numbers "Hợp đồng #123"', () {
      expect(removeDiacritics('Hợp đồng #123'), 'hop dong #123');
    });

    test('preserves symbols "Invoice-2024"', () {
      expect(removeDiacritics('Invoice-2024'), 'invoice-2024');
    });

    test('preserves dates "Hoá đơn 01/12/2024"', () {
      expect(removeDiacritics('Hoá đơn 01/12/2024'), 'hoa don 01/12/2024');
    });
  });

  group('removeDiacritics() - Edge Cases', () {
    test('handles empty string', () {
      expect(removeDiacritics(''), '');
    });

    test('handles whitespace-only string', () {
      expect(removeDiacritics('   '), '');
    });

    test('trims leading whitespace', () {
      expect(removeDiacritics('  Hoá đơn'), 'hoa don');
    });

    test('trims trailing whitespace', () {
      expect(removeDiacritics('Hoá đơn  '), 'hoa don');
    });

    test('trims both leading and trailing whitespace', () {
      expect(removeDiacritics('  Hoá đơn  '), 'hoa don');
    });

    test('preserves internal whitespace', () {
      expect(removeDiacritics('Hoá  đơn'), 'hoa  don');
    });
  });

  group('removeDiacritics() - All Vietnamese Vowels', () {
    // Test all tones of 'a'
    test('normalizes all a tones', () {
      expect(removeDiacritics('à á ả ã ạ'), 'a a a a a');
    });

    test('normalizes all ă tones', () {
      expect(removeDiacritics('ă ằ ắ ẳ ẵ ặ'), 'a a a a a a');
    });

    test('normalizes all â tones', () {
      expect(removeDiacritics('â ầ ấ ẩ ẫ ậ'), 'a a a a a a');
    });

    // Test all tones of 'e'
    test('normalizes all e tones', () {
      expect(removeDiacritics('è é ẻ ẽ ẹ'), 'e e e e e');
    });

    test('normalizes all ê tones', () {
      expect(removeDiacritics('ê ề ế ể ễ ệ'), 'e e e e e e');
    });

    // Test all tones of 'i'
    test('normalizes all i tones', () {
      expect(removeDiacritics('ì í ỉ ĩ ị'), 'i i i i i');
    });

    // Test all tones of 'o'
    test('normalizes all o tones', () {
      expect(removeDiacritics('ò ó ỏ õ ọ'), 'o o o o o');
    });

    test('normalizes all ô tones', () {
      expect(removeDiacritics('ô ồ ố ổ ỗ ộ'), 'o o o o o o');
    });

    test('normalizes all ơ tones', () {
      expect(removeDiacritics('ơ ờ ớ ở ỡ ợ'), 'o o o o o o');
    });

    // Test all tones of 'u'
    test('normalizes all u tones', () {
      expect(removeDiacritics('ù ú ủ ũ ụ'), 'u u u u u');
    });

    test('normalizes all ư tones', () {
      expect(removeDiacritics('ư ừ ứ ử ữ ự'), 'u u u u u u');
    });

    // Test all tones of 'y'
    test('normalizes all y tones', () {
      expect(removeDiacritics('ỳ ý ỷ ỹ ỵ'), 'y y y y y');
    });

    // Test đ character
    test('normalizes đ to d', () {
      expect(removeDiacritics('đ'), 'd');
    });

    test('normalizes Đ to d', () {
      expect(removeDiacritics('Đ'), 'd');
    });

    test('normalizes multiple đ characters', () {
      expect(removeDiacritics('đồng đạo'), 'dong dao');
    });
  });

  group('removeDiacritics() - Uppercase Vowels', () {
    test('normalizes uppercase A tones', () {
      expect(removeDiacritics('À Á Ả Ã Ạ'), 'a a a a a');
    });

    test('normalizes uppercase Ă tones', () {
      expect(removeDiacritics('Ă Ằ Ắ Ẳ Ẵ Ặ'), 'a a a a a a');
    });

    test('normalizes uppercase Â tones', () {
      expect(removeDiacritics('Â Ầ Ấ Ẩ Ẫ Ậ'), 'a a a a a a');
    });

    test('normalizes uppercase E tones', () {
      expect(removeDiacritics('È É Ẻ Ẽ Ẹ'), 'e e e e e');
    });

    test('normalizes uppercase Ê tones', () {
      expect(removeDiacritics('Ê Ề Ế Ể Ễ Ệ'), 'e e e e e e');
    });

    test('normalizes uppercase I tones', () {
      expect(removeDiacritics('Ì Í Ỉ Ĩ Ị'), 'i i i i i');
    });

    test('normalizes uppercase O tones', () {
      expect(removeDiacritics('Ò Ó Ỏ Õ Ọ'), 'o o o o o');
    });

    test('normalizes uppercase Ô tones', () {
      expect(removeDiacritics('Ô Ồ Ố Ổ Ỗ Ộ'), 'o o o o o o');
    });

    test('normalizes uppercase Ơ tones', () {
      expect(removeDiacritics('Ơ Ờ Ớ Ở Ỡ Ợ'), 'o o o o o o');
    });

    test('normalizes uppercase U tones', () {
      expect(removeDiacritics('Ù Ú Ủ Ũ Ụ'), 'u u u u u');
    });

    test('normalizes uppercase Ư tones', () {
      expect(removeDiacritics('Ư Ừ Ứ Ử Ữ Ự'), 'u u u u u u');
    });

    test('normalizes uppercase Y tones', () {
      expect(removeDiacritics('Ỳ Ý Ỷ Ỹ Ỵ'), 'y y y y y');
    });
  });

  group('removeDiacritics() - Real-world Vietnamese Names', () {
    test('normalizes "Nguyễn Văn A"', () {
      expect(removeDiacritics('Nguyễn Văn A'), 'nguyen van a');
    });

    test('normalizes "Trần Thị B"', () {
      expect(removeDiacritics('Trần Thị B'), 'tran thi b');
    });

    test('normalizes "Lê Hoàng C"', () {
      expect(removeDiacritics('Lê Hoàng C'), 'le hoang c');
    });

    test('normalizes "Phạm Minh Đức"', () {
      expect(removeDiacritics('Phạm Minh Đức'), 'pham minh duc');
    });
  });

  group('removeDiacritics() - Real-world Case Names', () {
    test('normalizes "Hoá đơn mua hàng"', () {
      expect(removeDiacritics('Hoá đơn mua hàng'), 'hoa don mua hang');
    });

    test('normalizes "Hoá đơn bán hàng"', () {
      expect(removeDiacritics('Hoá đơn bán hàng'), 'hoa don ban hang');
    });

    test('normalizes "Giấy phép kinh doanh"', () {
      expect(removeDiacritics('Giấy phép kinh doanh'), 'giay phep kinh doanh');
    });

    test('normalizes "Hợp đồng thuê nhà"', () {
      expect(removeDiacritics('Hợp đồng thuê nhà'), 'hop dong thue nha');
    });

    test('normalizes "Bảo hiểm xe"', () {
      expect(removeDiacritics('Bảo hiểm xe'), 'bao hiem xe');
    });

    test('normalizes "Đăng ký kinh doanh"', () {
      expect(removeDiacritics('Đăng ký kinh doanh'), 'dang ky kinh doanh');
    });
  });
}
