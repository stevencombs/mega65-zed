#include "tree_sitter/parser.h"

#include <stdbool.h>
#include <string.h>

// Keyword tables for the Commodore cruncher.
// BASIC 2.0 tokens are the C64/VIC-20 set (petcat -w2).
// BASIC65-only tokens are the MEGA65 user-guide keyword appendix
// (petcat -w65), minus the BASIC 2.0 words. DIRECTORY is token FE29;
// the printed appendix clips it to "ECTORY".
// REM is special: it comments out the rest of the line.

enum TokenType {
    KEYWORD,
    BASIC65_KEYWORD,
    IDENTIFIER,
    REM_STATEMENT,
    PETSCII_CODE,
    STRING_CONTENT,
};

static const char *const KW2[] = {
    "ABS",
    "AND",
    "ASC",
    "ATN",
    "CHR$",
    "CLOSE",
    "CLR",
    "CMD",
    "CONT",
    "COS",
    "DATA",
    "DEF",
    "DIM",
    "END",
    "EXP",
    "FN",
    "FOR",
    "FRE",
    "GET",
    "GO",
    "GOSUB",
    "GOTO",
    "IF",
    "INPUT",
    "INPUT#",
    "INT",
    "LEFT$",
    "LEN",
    "LET",
    "LIST",
    "LOAD",
    "LOG",
    "MID$",
    "NEW",
    "NEXT",
    "NOT",
    "ON",
    "OPEN",
    "OR",
    "PEEK",
    "POKE",
    "POS",
    "PRINT",
    "PRINT#",
    "READ",
    "RESTORE",
    "RETURN",
    "RIGHT$",
    "RND",
    "RUN",
    "SAVE",
    "SGN",
    "SIN",
    "SPC",
    "SQR",
    "STEP",
    "STOP",
    "STR$",
    "SYS",
    "TAB",
    "TAN",
    "THEN",
    "TO",
    "USR",
    "VAL",
    "VERIFY",
    "WAIT",
    NULL,
};

static const char *const KW65[] = {
    "APPEND",
    "AUTO",
    "BACKGROUND",
    "BACKUP",
    "BANK",
    "BEGIN",
    "BEND",
    "BLOAD",
    "BOOT",
    "BORDER",
    "BOX",
    "BSAVE",
    "BUMP",
    "BVERIFY",
    "CATALOG",
    "CHANGE",
    "CHAR",
    "CHDIR",
    "CIRCLE",
    "COLLECT",
    "COLLISION",
    "COLOR",
    "CONCAT",
    "COPY",
    "CURSOR",
    "CUT",
    "DCLEAR",
    "DCLOSE",
    "DEC",
    "DECBIN",
    "DELETE",
    "DIR",
    "DIRECTORY",
    "DISK",
    "DLOAD",
    "DMA",
    "DMODE",
    "DO",
    "DOPEN",
    "DOT",
    "DPAT",
    "DSAVE",
    "DVERIFY",
    "EDIT",
    "EDMA",
    "ELLIPSE",
    "ELSE",
    "ENVELOPE",
    "ERASE",
    "EXIT",
    "FAST",
    "FGOSUB",
    "FGOTO",
    "FILTER",
    "FIND",
    "FONT",
    "FOREGROUND",
    "FORMAT",
    "FREAD#",
    "FREEZER",
    "FWRITE#",
    "GCOPY",
    "GRAPHIC",
    "HEADER",
    "HELP",
    "HEX$",
    "HIGHLIGHT",
    "IMPORT",
    "INFO",
    "INSTR",
    "JOY",
    "KEY",
    "LINE",
    "LOADIFF",
    "LOCK",
    "LOG10",
    "LOOP",
    "LPEN",
    "MEM",
    "MERGE",
    "MKDIR",
    "MOD",
    "MONITOR",
    "MOUNT",
    "MOUSE",
    "MOVSPR",
    "OFF",
    "PAINT",
    "PALETTE",
    "PASTE",
    "PEN",
    "PIXEL",
    "PLAY",
    "POINTER",
    "POLYGON",
    "POT",
    "RCOLOR",
    "RCURSOR",
    "RECORD",
    "RENAME",
    "RENUMBER",
    "RESUME",
    "RGRAPHIC",
    "RMOUSE",
    "RPALETTE",
    "RPEN",
    "RPLAY",
    "RREG",
    "RSPCOLOR",
    "RSPPOS",
    "RSPEED",
    "RSPRITE",
    "RWINDOW",
    "SAVEIFF",
    "SCNCLR",
    "SCRATCH",
    "SCREEN",
    "SET",
    "SLEEP",
    "SOUND",
    "SPEED",
    "SPRCOLOR",
    "SPRITE",
    "SPRSAV",
    "STRBIN$",
    "TEMPO",
    "TRAP",
    "TROFF",
    "TRON",
    "TYPE",
    "UNLOCK",
    "UNTIL",
    "USING",
    "VIEWPORT",
    "VOL",
    "VSYNC",
    "WHILE",
    "WINDOW",
    "WPEEK",
    "WPOKE",
    "XOR",
    NULL,
};

void *tree_sitter_commodore_basic_external_scanner_create(void) {
    return NULL;
}

void tree_sitter_commodore_basic_external_scanner_destroy(void *payload) {
    (void)payload;
}

unsigned tree_sitter_commodore_basic_external_scanner_serialize(void *payload, char *buffer) {
    (void)payload;
    (void)buffer;
    return 0;
}

void tree_sitter_commodore_basic_external_scanner_deserialize(
    void *payload,
    const char *buffer,
    unsigned length
) {
    (void)payload;
    (void)buffer;
    (void)length;
}

static bool is_letter(int32_t c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

static char to_upper(int32_t c) {
    if (c >= 'a' && c <= 'z') return (char)(c - 'a' + 'A');
    return (char)c;
}

// 0 = none, 1 = BASIC 2.0 keyword, 2 = BASIC65-only keyword, 3 = REM.
static int classify(const char *word) {
    if (strcmp(word, "REM") == 0) return 3;
    for (int i = 0; KW2[i] != NULL; i++) {
        if (strcmp(KW2[i], word) == 0) return 1;
    }
    for (int i = 0; KW65[i] != NULL; i++) {
        if (strcmp(KW65[i], word) == 0) return 2;
    }
    return 0;
}

static bool is_string_char(int32_t c) {
    return c != '"' && c != '{' && c != '\n' && c != '\r' && c != 0;
}

// Inside a string the parser also allows the tokens that follow the
// string. Prefer string pieces whenever they are valid.
static bool scan_string(TSLexer *lexer, const bool *valid_symbols) {
    if (lexer->lookahead == '{') {
        lexer->advance(lexer, false);
        while (!lexer->eof(lexer) && lexer->lookahead != '}' && lexer->lookahead != '"' &&
               lexer->lookahead != '\n' && lexer->lookahead != '\r') {
            lexer->advance(lexer, false);
        }
        if (lexer->lookahead == '}' && valid_symbols[PETSCII_CODE]) {
            lexer->advance(lexer, false);
            lexer->result_symbol = PETSCII_CODE;
            return true;
        }
        if (valid_symbols[STRING_CONTENT]) {
            lexer->result_symbol = STRING_CONTENT;
            return true;
        }
        return false;
    }

    if (!valid_symbols[STRING_CONTENT] || !is_string_char(lexer->lookahead)) return false;
    while (is_string_char(lexer->lookahead) && !lexer->eof(lexer)) {
        lexer->advance(lexer, false);
    }
    lexer->result_symbol = STRING_CONTENT;
    return true;
}

bool tree_sitter_commodore_basic_external_scanner_scan(
    void *payload,
    TSLexer *lexer,
    const bool *valid_symbols
) {
    (void)payload;

    if (valid_symbols[STRING_CONTENT] || valid_symbols[PETSCII_CODE]) {
        return scan_string(lexer, valid_symbols);
    }

    // Extras are not skipped before an external scanner runs.
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
        lexer->advance(lexer, true);
    }

    if (!is_letter(lexer->lookahead)) return false;
    if (!(valid_symbols[KEYWORD] || valid_symbols[BASIC65_KEYWORD] ||
          valid_symbols[IDENTIFIER] || valid_symbols[REM_STATEMENT])) {
        return false;
    }

    char buf[64];
    int n = 0;
    int best_kind = 0;

    while (is_letter(lexer->lookahead) && n < 60) {
        buf[n++] = to_upper(lexer->lookahead);
        buf[n] = '\0';
        lexer->advance(lexer, false);
        int kind = classify(buf);
        if (kind != 0) {
            best_kind = kind;
            // Longest keyword wins. Letters advanced after this mark are
            // not part of the token unless a longer keyword moves the mark.
            lexer->mark_end(lexer);
        }
    }

    if (lexer->lookahead == '$' || lexer->lookahead == '#' || lexer->lookahead == '%') {
        int32_t suf = lexer->lookahead;
        if (n < 60) {
            buf[n] = (char)suf;
            buf[n + 1] = '\0';
            int kind = classify(buf);
            if (kind != 0) {
                lexer->advance(lexer, false);
                n++;
                best_kind = kind;
                lexer->mark_end(lexer);
            } else if (best_kind == 0 && (suf == '$' || suf == '%')) {
                lexer->advance(lexer, false);
                n++;
            }
        }
    }

    if (best_kind == 3 && valid_symbols[REM_STATEMENT]) {
        while (!lexer->eof(lexer) && lexer->lookahead != '\n' && lexer->lookahead != '\r') {
            lexer->advance(lexer, false);
        }
        lexer->mark_end(lexer);
        lexer->result_symbol = REM_STATEMENT;
        return true;
    }

    if (best_kind == 1 && valid_symbols[KEYWORD]) {
        lexer->result_symbol = KEYWORD;
        return true;
    }
    if (best_kind == 2 && valid_symbols[BASIC65_KEYWORD]) {
        lexer->result_symbol = BASIC65_KEYWORD;
        return true;
    }
    if (best_kind == 3 && valid_symbols[KEYWORD]) {
        lexer->result_symbol = KEYWORD;
        return true;
    }
    if (best_kind == 0 && n > 0 && valid_symbols[IDENTIFIER]) {
        lexer->result_symbol = IDENTIFIER;
        return true;
    }
    return false;
}
