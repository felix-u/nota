typedef enum Args_Kind {
    args_kind_bool = 0,
    args_kind_single_pos,
    args_kind_multi_pos,
} Args_Kind;

typedef struct Args_Flag {
    char *name; usize name_len;
    Args_Kind kind;
    
    bool is_present;
    char *single_pos; usize single_pos_len;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Flag;

typedef struct Args_Desc {
    Args_Kind exe_kind;
    Args_Flag **flags; usize flags_len;
    char *single_pos; usize single_pos_len;
    struct { int beg_i; int end_i; } multi_pos;
} Args_Desc;

static int args_parse(int argc, char **argv, Args_Desc *desc) {
    if (argc == 0) return 1;
    if (argc == 1) return desc->exe_kind != args_kind_bool;

    Args_Flag ***flags = &desc->flags;
    usize flags_len = desc->flags_len;
    char *arg = argv[1];
    usize arg_len = strlen(arg);
    for (int i = 1; i < argc; i += 1, arg = argv[i], arg_len = strlen(arg)) {
        if (arg_len == 1 || arg[0] != '-') {
            switch (desc->exe_kind) {
                case args_kind_bool: {
                    errf("unexpected positional argument '%s'", arg);
                    return 1;
                } break;
                case args_kind_single_pos: {
                    if (desc->single_pos != 0) {
                        errf("unexpected positional argument '%s'", arg);
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
                            "unexpected positional argument '%s'; "
                                "positional arguments ended earlier",
                            arg
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
            Args_Flag *f = *flags[j];
            bool single_dash = (arg[0] == '-') && 
                !strncmp(arg + 1, f->name, f->name_len);
            bool double_dash = arg_len > 2 && 
                !strncmp(arg, "--", 2) &&
                !strncmp(arg + 2, f->name, f->name_len);
            if (!single_dash && !double_dash) continue;

            flag = f;
            flag->is_present = true;
            break;
        }
        if (flag == 0) {
            errf("invalid flag '%s'", arg);
            return 1;
        }

        switch (flag->kind) {
            case args_kind_bool: break;
            case args_kind_single_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    errf("expected positional argument after '%s'", arg);
                    return 1;
                }
                if (flag->single_pos != 0) {
                    errf("unexpected positional argument '%.*s'", arg);
                    return 1;
                }
                flag->single_pos = argv[++i];
                flag->single_pos_len = strlen(flag->single_pos);
            } break;
            case args_kind_multi_pos: {
                if (i + 1 == argc || argv[i + 1][0] == '-') {
                    errf("expected positional argument after '%s'", arg);
                    return 1;
                }

                flag->multi_pos.beg_i = i + 1;
                flag->multi_pos.end_i = i + 2;

                for (arg = argv[++i]; i < argc; arg = argv[++i]) {
                    if (arg[0] == '-') {
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
