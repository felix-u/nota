typedef struct File_Position {
    usize row, row_beg_i, row_end_i, col;
} File_Position;

static File_Position file_position_from_byte_index(String bytes, usize index) {
    File_Position pos = { .row = 1, .col = 1 };

    usize i = 0;
    for (; i < index; i += 1, pos.col += 1) {
        if (bytes.ptr[i] != '\n') continue;
        pos.row += 1;
        pos.row_beg_i = i + 1;
        pos.col = 0;
    }

    pos.row_end_i = i;
    while (pos.row_end_i < bytes.len && bytes.ptr[pow.row_end_i] != '\n') {
        pos.row_end_i += 1;
    }

    return pos;
}
