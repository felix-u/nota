typedef enum Args_Kind {
    args_kind_bool = 0,
    args_kind_single_pos,
    args_kind_multi_pos,
} Args_Kind;

typedef struct Args_Flag {
    String name;
    Args_Kind kind;

    bool is_present;
    String single_pos;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Flag;
typedef Slice(Args_Flag *) Slice_Args_Flag_ptr;

typedef struct Args_Desc {
    Args_Kind exe_kind;
    Slice_Args_Flag_ptr flags;
    String single_pos;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Desc;

typedef struct Args { char **argv; int argc; } Args;

static int args_err_unexpected_pos(String arg) {
    errf("unexpected positional argument '%.*s'", string_fmt(arg));
    return 1;
}

static int args_err_expected_pos(String arg) {
    errf("expected positional argument after '%.*s'", string_fmt(arg));
    return 1;
}

static int args_err_invalid_flag(String arg) {
    errf("invalid flag '%.*s'", string_fmt(arg));
    return 1;
}

static int args_parse(int argc, char **argv, Args_Desc *a) {
    if (argc == 0) return 1;
    if (argc == 1) return a->exe_kind != args_kind_bool;

    Args_Flag ***flags = &a->flags.ptr;
    usize flags_len = a->flags.len;
    String arg = string_from_cstring(argv[1]);
    for (int i = 1; i < argc; i += 1, arg = string_from_cstring(argv[i])) {
        if (arg.len == 1 || arg.ptr[0] != '-') {
            switch (a->exe_kind) {
                case args_kind_bool: return args_err_unexpected_pos(arg);
                case args_kind_single_pos: {
                    if (a->single_pos.len != 0 || a->single_pos.ptr != 0) {
                        return args_err_unexpected_pos(arg);
                    }
                    a->single_pos = arg;
                } break;
                case args_kind_multi_pos: {
                    if (a->multi_pos.beg_i == 0) {
                        a->multi_pos.beg_i = (int)i;
                        a->multi_pos.end_i = (int)(i + 1);
                        continue;
                    }

                    if (a->multi_pos.end_i < (int)i) {
                        return args_err_unexpected_pos(arg);
                    }

                    a->multi_pos.end_i += 1;
                } break;
            }
            continue;
        }

        Args_Flag *flag = 0;
        for (usize j = 0; j < flags_len; j += 1) {
            bool single_dash = 
                (arg.ptr[0] == '-') && 
                string_eql(string_range(arg, 1, arg.len), (*flags[j])->name);
            bool double_dash = arg.len > 2 &&
                string_eql(string_range(arg, 0, 2), string("--")) &&
                string_eql(string_range(arg, 2, arg.len), (*flags[j])->name);
            if (!single_dash && !double_dash) continue;

            flag = (*flags[j]);
            flag->is_present = true;
            break;
        }
        if (flag == 0) return args_err_invalid_flag(arg);

        switch (flag->kind) {
            case args_kind_bool: break;
            case args_kind_single_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    return args_err_expected_pos(arg);
                }
                if (flag->single_pos.len != 0 || flag->single_pos.ptr != 0) {
                    return args_err_unexpected_pos(arg);
                }
                flag->single_pos = string_from_cstring(argv[++i]);
            } break;
            case args_kind_multi_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    return args_err_expected_pos(arg);
                }

                flag->multi_pos.beg_i = i + 1;
                flag->multi_pos.end_i = i + 2;

                for (
                    arg = string_from_cstring(argv[++i]); 
                    i < argc; 
                    arg = string_from_cstring(argv[++i])
                ) {
                    if (arg.ptr[0] == '-') {
                        i -= 1;
                        break;
                    }
                    flag->multi_pos.end_i = i + 1;
                }
            } break;
        }
    }

    return 0;
}
