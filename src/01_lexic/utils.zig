pub fn is_decimal_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

pub fn is_hex_digit(c: u8) bool {
    return ('0' <= c and c <= '9') or ('a' <= c and c <= 'f') or ('A' <= c and c <= 'F');
}
