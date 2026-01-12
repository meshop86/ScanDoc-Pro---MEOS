// Phase 24.1: Vietnamese Normalization Utility
//
// Provides functions to normalize Vietnamese text by removing diacritics.
// Used for diacritic-insensitive search in case names.
//
// Algorithm:
// 1. Unicode NFD (Canonical Decomposition) - separates base chars from diacritics
// 2. Remove combining diacritical marks (U+0300-U+036F)
// 3. Handle special Vietnamese characters (đ, Đ)
// 4. Lowercase and trim

/// Removes Vietnamese diacritics from text for search normalization
///
/// Converts Vietnamese text to ASCII-compatible form by:
/// - Removing all tone marks (á à ả ã ạ → a)
/// - Removing all diacritics (ă â ê ô ơ ư → a e o u)
/// - Converting đ/Đ to d
/// - Lowercasing all characters
/// - Trimming whitespace
///
/// Examples:
/// ```dart
/// removeDiacritics('Hoá đơn')      // → 'hoa don'
/// removeDiacritics('Điện thoại')   // → 'dien thoai'
/// removeDiacritics('Hợp đồng')     // → 'hop dong'
/// removeDiacritics('Invoice 2024') // → 'invoice 2024' (preserves English)
/// ```
///
/// Phase 24.1: Used by searchCases() for Vietnamese search support
String removeDiacritics(String text) {
  if (text.isEmpty) return '';

  // Step 1: Handle special Vietnamese characters BEFORE NFD normalization
  // (đ/Đ don't decompose properly in NFD)
  String normalized = text
      .replaceAll('đ', 'd')
      .replaceAll('Đ', 'd');

  // Step 2: Unicode NFD normalization (Canonical Decomposition)
  // Separates base characters from combining diacritical marks
  // Example: "ó" (U+00F3) → "o" (U+006F) + "́" (U+0301)
  //
  // Note: Dart's String class doesn't have built-in NFD normalization,
  // so we need to use a custom implementation or package.
  // For now, we'll use a comprehensive character mapping approach.

  // Step 3: Replace all Vietnamese characters with their base equivalents
  const Map<String, String> vietnameseChars = {
    // Lowercase a with tones
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    // Lowercase ă with tones
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    // Lowercase â with tones
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    
    // Uppercase A with tones
    'À': 'a', 'Á': 'a', 'Ả': 'a', 'Ã': 'a', 'Ạ': 'a',
    // Uppercase Ă with tones
    'Ă': 'a', 'Ằ': 'a', 'Ắ': 'a', 'Ẳ': 'a', 'Ẵ': 'a', 'Ặ': 'a',
    // Uppercase Â with tones
    'Â': 'a', 'Ầ': 'a', 'Ấ': 'a', 'Ẩ': 'a', 'Ẫ': 'a', 'Ậ': 'a',

    // Lowercase e with tones
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    // Lowercase ê with tones
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    
    // Uppercase E with tones
    'È': 'e', 'É': 'e', 'Ẻ': 'e', 'Ẽ': 'e', 'Ẹ': 'e',
    // Uppercase Ê with tones
    'Ê': 'e', 'Ề': 'e', 'Ế': 'e', 'Ể': 'e', 'Ễ': 'e', 'Ệ': 'e',

    // Lowercase i with tones
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    
    // Uppercase I with tones
    'Ì': 'i', 'Í': 'i', 'Ỉ': 'i', 'Ĩ': 'i', 'Ị': 'i',

    // Lowercase o with tones
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    // Lowercase ô with tones
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    // Lowercase ơ with tones
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    
    // Uppercase O with tones
    'Ò': 'o', 'Ó': 'o', 'Ỏ': 'o', 'Õ': 'o', 'Ọ': 'o',
    // Uppercase Ô with tones
    'Ô': 'o', 'Ồ': 'o', 'Ố': 'o', 'Ổ': 'o', 'Ỗ': 'o', 'Ộ': 'o',
    // Uppercase Ơ with tones
    'Ơ': 'o', 'Ờ': 'o', 'Ớ': 'o', 'Ở': 'o', 'Ỡ': 'o', 'Ợ': 'o',

    // Lowercase u with tones
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    // Lowercase ư with tones
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    
    // Uppercase U with tones
    'Ù': 'u', 'Ú': 'u', 'Ủ': 'u', 'Ũ': 'u', 'Ụ': 'u',
    // Uppercase Ư with tones
    'Ư': 'u', 'Ừ': 'u', 'Ứ': 'u', 'Ử': 'u', 'Ữ': 'u', 'Ự': 'u',

    // Lowercase y with tones
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    
    // Uppercase Y with tones
    'Ỳ': 'y', 'Ý': 'y', 'Ỷ': 'y', 'Ỹ': 'y', 'Ỵ': 'y',
  };

  // Apply character mappings
  for (final entry in vietnameseChars.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }

  // Step 4: Lowercase (handles remaining non-Vietnamese uppercase)
  normalized = normalized.toLowerCase();

  // Step 5: Trim whitespace
  normalized = normalized.trim();

  return normalized;
}
