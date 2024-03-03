row: u32,
row_beg_i: u32,
row_end_i: u32,
col: u32,

pub fn fromByteIndex(bytes: []const u8, index: u32) @This() {
    var pos = @This(){
        .row = 1,
        .row_beg_i = 0,
        .row_end_i = 0,
        .col = 1,
    };

    var i: u32 = 0;
    while (i < index) : ({
        i += 1;
        pos.col += 1;
    }) {
        if (bytes[i] != '\n') continue;
        pos.row += 1;
        pos.row_beg_i = i + 1;
        pos.col = 0;
        continue;
    }

    pos.row_end_i = i;
    while (pos.row_end_i < bytes.len and bytes[pos.row_end_i] != '\n') {
        pos.row_end_i += 1;
    }

    return pos;
}
