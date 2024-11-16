pub fn is_decimal_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

pub fn is_octal_digit(c: u8) bool {
    return '0' <= c and c <= '7';
}

pub fn is_binary_digit(c: u8) bool {
    return c == '0' or c == '1';
}

pub fn is_hex_digit(c: u8) bool {
    return ('0' <= c and c <= '9') or ('a' <= c and c <= 'f') or ('A' <= c and c <= 'F');
}
