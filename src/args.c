typedef enum Args_Kind {
    args_kind_bool = 0,
    args_kind_single_pos,
    args_kind_multi_pos,
} Args_Kind;

typedef struct Args_Flag {
    Str8 name;
    Args_Kind kind;
    
    bool is_present;
    Str8 single_pos;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Flag;
typedef Slice(Args_Flag *) Slice_Args_Flag_ptr;

typedef struct Args_Desc {
    Args_Kind exe_kind;
    Slice_Args_Flag_ptr flags;
    Str8 single_pos;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Desc;

typedef struct Args { char **argv; int argc; } Args;

static int args_parse(int argc, char **argv, Args_Desc *desc) {
    if (argc == 0) return 1;
    if (argc == 1) return desc->exe_kind != args_kind_bool;

    Args_Flag ***flags = &desc->flags.ptr;
    usize flags_len = desc->flags.len;
    Str8 arg = str8_from_cstr(argv[1]);
    for (int i = 1; i < argc; i += 1, arg = str8_from_cstr(argv[i])) {
        if (arg.len == 1 || arg.ptr[0] != '-') {
            switch (desc->exe_kind) {
                case args_kind_bool: {
                    errf(
                        "unexpected positional argument '%.*s'", 
                        str8_fmt(arg)
                    );
                    return 1;
                } break;
                case args_kind_single_pos: {
                    if (desc->single_pos.len != 0 || 
                        desc->single_pos.ptr != 0
                    ) {
                        errf(
                            "unexpected positional argument '%.*s'", 
                            str8_fmt(arg)
                        );
                        return 1;
                    }
                    desc->single_pos = arg;
                } break;
                case args_kind_multi_pos: {
                    if (desc->multi_pos.beg_i == 0) {
                        desc->multi_pos.beg_i = (int)i;
                        desc->multi_pos.end_i = (int)(i + 1);
                        continue;
                    }

                    if (desc->multi_pos.end_i < (int)i) {
                        errf(
                            "unexpected positional argument '%.*s'; "
                                "positional arguments ended earlier",
                            str8_fmt(arg)
                        );
                        return 1;
                    }
                    
                    desc->multi_pos.end_i += 1;
                } break;
            }
            continue;
        }

        Args_Flag *flag = 0;
        for (usize j = 0; j < flags_len; j += 1) {
            bool single_dash = (arg.ptr[0] == '-') && 
                str8_eql(str8_range(arg, 1, arg.len), (*flags[j])->name);
            bool double_dash = arg.len > 2 && 
                str8_eql(str8_range(arg, 0, 2), str8("--")) &&
                str8_eql(str8_range(arg, 2, arg.len), (*flags[j])->name);
            if (!single_dash && !double_dash) continue;

            flag = (*flags[j]);
            flag->is_present = true;
            break;
        }
        if (flag == 0) {
            errf("invalid flag '%.*s'", str8_fmt(arg));
            return 1;
        }

        switch (flag->kind) {
            case args_kind_bool: break;
            case args_kind_single_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    errf(
                        "expected positional argument after '%.*s'", 
                        str8_fmt(arg)
                    );
                    return 1;
                }
                if (flag->single_pos.len != 0 || flag->single_pos.ptr != 0) {
                    errf(
                        "unexpected positional argument '%.*s'", 
                        str8_fmt(arg)
                    );
                    return 1;
                }
                flag->single_pos = str8_from_cstr(argv[++i]);
            } break;
            case args_kind_multi_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    errf(
                        "expected positional argument after '%.*s'", 
                        str8_fmt(arg)
                    );
                    return 1;
                }

                flag->multi_pos.beg_i = i + 1;
                flag->multi_pos.end_i = i + 2;

                for (
                    arg = str8_from_cstr(argv[++i]); 
                    i < argc; 
                    arg = str8_from_cstr(argv[++i])
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
