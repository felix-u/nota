#include <stdbool.h>
#include <strings.h>
#include <stdio.h>


#ifndef ARGS_TYPE
#define ARGS_TYPE

typedef struct {
    bool is_present;
    int index;
} BoolFlagReturn;

typedef struct {
    int offset;
    int end;
} MultipleValReturn;

#endif // ARGS_TYPE


BoolFlagReturn args_isPresent(int argc, char** argv, char** flag);
char* args_singleValueOf(int argc, char** argv, char** flag);
MultipleValReturn args_multipleValuesOf(int argc, char** argv, char** flag);


#ifdef ARGS_IMPLEMENTATION

#ifndef ARGS_EQUIVALENT_FLAGS
#define ARGS_EQUIVALENT_FLAGS 3
#endif // ARGS_EQUIVALENT_FLAGS


// Checks if a boolean flag exists
BoolFlagReturn args_isPresent(int argc, char** argv, char** flag) {
    for (int i = 1; i < argc; i++) {
        for (int j = 0; j < ARGS_EQUIVALENT_FLAGS; j++) {
            if (!strcasecmp(argv[i], flag[j])) return (BoolFlagReturn){true, i};
        }
    }
    // Flag missing
    return (BoolFlagReturn){false, 0};
}


// Returns single value of flag
char* args_singleValueOf(int argc, char** argv, char** flag) {

    BoolFlagReturn flag_check = args_isPresent(argc, argv, flag);
    if (flag_check.is_present) {

        // If the arg after the flag doesn't start with '-', we return it as the supplied option.
        if (argc > flag_check.index + 1 && argv[flag_check.index + 1][0] != '-') return argv[flag_check.index + 1];

        // Otherwise, flag is present but no value supplied
        return NULL;
    }

    // Flag not present
    return NULL;
}


// Returns multiple values of flag
MultipleValReturn args_multipleValuesOf(int argc, char** argv, char** flag) {

    BoolFlagReturn flag_check = args_isPresent(argc, argv, flag);
    if (flag_check.is_present) {

        // If the arg after the flag doesn't start with '-', at least one option was supplied and so there are things
        // to return.
        if (argc > flag_check.index + 1 && argv[flag_check.index + 1][0] != '-') {
            int end_index = 0;
            // Stop at first argument which begins with '-'
            for (int i = flag_check.index + 1; i < argc; i++) {
                if (argv[i][0] == '-') end_index = i;
            }

            // If end_index is still 0 by now, the values go to the end of argv.
            if (end_index == 0) end_index = argc;

            return (MultipleValReturn){flag_check.index + 1, end_index};
        }

        // Otherwise, flag is present but no value supplied.
        return (MultipleValReturn){flag_check.index + 1, 0};
    }

    // Flag not present
    return (MultipleValReturn){0, 0};
}

#endif // ARGS_IMPLEMENTATION
