#pragma once
#include <stdint.h>
#include <stddef.h>

void *memset(void *, int, size_t);
void *memcpy(void *, const void *, size_t);
int memcmp(const void *, const void *, size_t);
void *memmove(void *, const void *, size_t);

char *strcpy(char *, const char *);
char *strncpy(char *, const char *, size_t);
size_t strlen(const char *);
size_t wcslen(const wchar_t *);
int strcmp(const char *, const char *);
int strncmp(const char *, const char *, size_t);
